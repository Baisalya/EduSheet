#include "pdf_renderer_bridge.h"

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Data.Pdf.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>
#include <windows.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <exception>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>
#include <system_error>
#include <utility>

namespace {
constexpr char kPdfRendererChannelName[] = "edusheet/pdf_renderer";
constexpr char kRenderPagesMethod[] = "renderPagesToImages";
constexpr int kDefaultScale = 2;
constexpr int kMinScale = 1;
constexpr int kMaxScale = 4;
constexpr uint32_t kMaxRenderDimension = 16384;
constexpr auto kRenderCacheRetention = std::chrono::hours(24);

using EncodableResult = flutter::MethodResult<flutter::EncodableValue>;
using SharedResult = std::shared_ptr<EncodableResult>;
using PdfDocument = winrt::Windows::Data::Pdf::PdfDocument;
using PdfPageRenderOptions = winrt::Windows::Data::Pdf::PdfPageRenderOptions;
using BitmapEncoder = winrt::Windows::Graphics::Imaging::BitmapEncoder;
using StorageFile = winrt::Windows::Storage::StorageFile;
using StorageFolder = winrt::Windows::Storage::StorageFolder;
using CreationCollisionOption =
    winrt::Windows::Storage::CreationCollisionOption;
using FileAccessMode = winrt::Windows::Storage::FileAccessMode;

std::string HresultMessage(const winrt::hresult_error& error) {
  const std::string message = winrt::to_string(error.message());
  return message.empty() ? "Windows PDF rendering failed." : message;
}

void RemoveDirectoryBestEffort(const std::filesystem::path& directory) {
  if (directory.empty()) {
    return;
  }
  std::error_code error;
  std::filesystem::remove_all(directory, error);
}

void CleanupStaleRenderDirectories() {
  try {
    const auto root = std::filesystem::temp_directory_path() / L"EduSheet";
    std::error_code error;
    if (!std::filesystem::exists(root, error) || error) {
      return;
    }

    const auto now = std::filesystem::file_time_type::clock::now();
    for (const auto& entry : std::filesystem::directory_iterator(root, error)) {
      if (error) {
        return;
      }
      if (!entry.is_directory(error) || error) {
        error.clear();
        continue;
      }
      const auto name = entry.path().filename().wstring();
      if (name.rfind(L"pdf_render_", 0) != 0) {
        continue;
      }
      const auto modified = entry.last_write_time(error);
      if (error) {
        error.clear();
        continue;
      }
      if (now - modified > kRenderCacheRetention) {
        std::filesystem::remove_all(entry.path(), error);
        error.clear();
      }
    }
  } catch (...) {
    // Startup cleanup is best effort and must never block the application.
  }
}

std::optional<std::string> ReadPdfPath(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    return std::nullopt;
  }
  const auto entry = arguments->find(flutter::EncodableValue("pdfPath"));
  if (entry == arguments->end()) {
    return std::nullopt;
  }
  const auto* path = std::get_if<std::string>(&entry->second);
  if (path == nullptr || path->empty()) {
    return std::nullopt;
  }
  return *path;
}

int ReadScale(const flutter::MethodCall<flutter::EncodableValue>& call) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    return kDefaultScale;
  }
  const auto entry = arguments->find(flutter::EncodableValue("scale"));
  if (entry == arguments->end()) {
    return kDefaultScale;
  }

  int scale = kDefaultScale;
  if (const auto* int32_value = std::get_if<int32_t>(&entry->second)) {
    scale = *int32_value;
  } else if (const auto* int64_value = std::get_if<int64_t>(&entry->second)) {
    scale = static_cast<int>(*int64_value);
  }
  return std::clamp(scale, kMinScale, kMaxScale);
}

uint32_t RenderDimension(float points, int scale) {
  const double scaled =
      std::max(1.0, std::round(static_cast<double>(points) * scale));
  return static_cast<uint32_t>(
      std::min(scaled, static_cast<double>(kMaxRenderDimension)));
}

std::filesystem::path CreateRenderDirectory() {
  const auto directory = std::filesystem::temp_directory_path() /
                         L"EduSheet" /
                         (L"pdf_render_" +
                          std::to_wstring(::GetCurrentProcessId()) + L"_" +
                          std::to_wstring(::GetTickCount64()));
  std::filesystem::create_directories(directory);
  return directory;
}

winrt::fire_and_forget RenderPagesAsync(std::string pdf_path, int scale,
                                        SharedResult result) {
  std::filesystem::path render_directory;
  try {
    std::replace(pdf_path.begin(), pdf_path.end(), '/', '\\');
    const auto source_file = co_await StorageFile::GetFileFromPathAsync(
        winrt::to_hstring(pdf_path));
    const auto pdf_document =
        co_await PdfDocument::LoadFromFileAsync(source_file);

    render_directory = CreateRenderDirectory();
    const auto output_folder = co_await StorageFolder::GetFolderFromPathAsync(
        winrt::hstring(render_directory.wstring()));

    flutter::EncodableList page_paths;
    const uint32_t page_count = pdf_document.PageCount();
    page_paths.reserve(page_count);

    for (uint32_t index = 0; index < page_count; ++index) {
      auto page = pdf_document.GetPage(index);
      const auto page_size = page.Size();
      const auto file_name =
          L"page_" + std::to_wstring(index + 1) + L".png";
      const auto output_file = co_await output_folder.CreateFileAsync(
          winrt::hstring(file_name), CreationCollisionOption::ReplaceExisting);
      auto output_stream =
          co_await output_file.OpenAsync(FileAccessMode::ReadWrite);

      PdfPageRenderOptions options;
      options.DestinationWidth(RenderDimension(page_size.Width, scale));
      options.DestinationHeight(RenderDimension(page_size.Height, scale));
      options.BitmapEncoderId(BitmapEncoder::PngEncoderId());
      options.IsIgnoringHighContrast(true);

      co_await page.RenderToStreamAsync(output_stream, options);
      co_await output_stream.FlushAsync();
      output_stream.Close();
      page.Close();

      page_paths.emplace_back(winrt::to_string(output_file.Path()));
    }

    if (page_paths.empty()) {
      RemoveDirectoryBestEffort(render_directory);
    }
    result->Success(flutter::EncodableValue(page_paths));
  } catch (const winrt::hresult_error& error) {
    RemoveDirectoryBestEffort(render_directory);
    result->Error("RENDER_FAILED", HresultMessage(error));
  } catch (const std::filesystem::filesystem_error& error) {
    RemoveDirectoryBestEffort(render_directory);
    result->Error("RENDER_FAILED", error.what());
  } catch (const std::exception& error) {
    RemoveDirectoryBestEffort(render_directory);
    result->Error("RENDER_FAILED", error.what());
  } catch (...) {
    RemoveDirectoryBestEffort(render_directory);
    result->Error("RENDER_FAILED", "Windows PDF rendering failed.");
  }
}
}  // namespace

class PdfRendererBridge::Impl {
 public:
  explicit Impl(flutter::BinaryMessenger* messenger)
      : channel_(std::make_unique<
                 flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, kPdfRendererChannelName,
            &flutter::StandardMethodCodec::GetInstance())) {
    CleanupStaleRenderDirectories();
    channel_->SetMethodCallHandler(
        [](const auto& call, auto result) {
          if (call.method_name() != kRenderPagesMethod) {
            result->NotImplemented();
            return;
          }

          const auto pdf_path = ReadPdfPath(call);
          if (!pdf_path.has_value()) {
            result->Error("INVALID_PATH", "PDF path is empty.");
            return;
          }

          SharedResult shared_result(std::move(result));
          RenderPagesAsync(*pdf_path, ReadScale(call),
                           std::move(shared_result));
        });
  }

  ~Impl() { channel_->SetMethodCallHandler(nullptr); }

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

PdfRendererBridge::PdfRendererBridge(flutter::BinaryMessenger* messenger)
    : impl_(std::make_unique<Impl>(messenger)) {}

PdfRendererBridge::~PdfRendererBridge() = default;
