#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "microsoft_store_bridge.h"
#include "pdf_renderer_bridge.h"

namespace {
constexpr ULONG_PTR kEduSheetDocumentCopyDataId = 0x4553444F;  // "ESDO"
constexpr char kDocumentChannelName[] = "edusheet/document_intents";
constexpr char kPresentationModeChannelName[] = "edusheet/presentation_mode";
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  microsoft_store_bridge_ = std::make_unique<MicrosoftStoreBridge>(
      flutter_controller_->engine()->messenger(), GetHandle());
  pdf_renderer_bridge_ = std::make_unique<PdfRendererBridge>(
      flutter_controller_->engine()->messenger());

  document_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kDocumentChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  presentation_mode_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kPresentationModeChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  presentation_mode_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "enterImmersive") {
          EnterPresentationFullscreen();
          result->Success();
          return;
        }
        if (call.method_name() == "exitImmersive") {
          ExitPresentationFullscreen();
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    dart_ready_ = true;
    for (const auto& path : pending_document_paths_) {
      DispatchDocumentToDart(path);
    }
    pending_document_paths_.clear();
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  ExitPresentationFullscreen();
  presentation_mode_channel_.reset();
  pdf_renderer_bridge_.reset();
  microsoft_store_bridge_.reset();
  document_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::EnterPresentationFullscreen() {
  if (presentation_fullscreen_) {
    return;
  }

  const HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }

  presentation_window_style_ = ::GetWindowLongPtr(window, GWL_STYLE);
  presentation_window_ex_style_ = ::GetWindowLongPtr(window, GWL_EXSTYLE);
  presentation_window_placement_.length = sizeof(WINDOWPLACEMENT);
  if (!::GetWindowPlacement(window, &presentation_window_placement_)) {
    return;
  }

  const HMONITOR monitor =
      ::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (!::GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const LONG_PTR fullscreen_style =
      presentation_window_style_ &
      ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
        WS_SYSMENU);
  const LONG_PTR fullscreen_ex_style =
      presentation_window_ex_style_ &
      ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE);
  ::SetWindowLongPtr(window, GWL_STYLE, fullscreen_style);
  ::SetWindowLongPtr(window, GWL_EXSTYLE, fullscreen_ex_style);

  const RECT& bounds = monitor_info.rcMonitor;
  ::SetWindowPos(window, HWND_TOP, bounds.left, bounds.top,
                 bounds.right - bounds.left, bounds.bottom - bounds.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  presentation_fullscreen_ = true;
}

void FlutterWindow::ExitPresentationFullscreen() {
  if (!presentation_fullscreen_) {
    return;
  }

  const HWND window = GetHandle();
  if (window == nullptr) {
    presentation_fullscreen_ = false;
    return;
  }

  ::SetWindowLongPtr(window, GWL_STYLE, presentation_window_style_);
  ::SetWindowLongPtr(window, GWL_EXSTYLE, presentation_window_ex_style_);
  presentation_window_placement_.length = sizeof(WINDOWPLACEMENT);
  ::SetWindowPlacement(window, &presentation_window_placement_);
  ::SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  presentation_fullscreen_ = false;
}

void FlutterWindow::DispatchDocumentToDart(const std::string& path) {
  if (!document_channel_ || path.empty()) {
    return;
  }

  flutter::EncodableMap document;
  document[flutter::EncodableValue("path")] = flutter::EncodableValue(path);
  document[flutter::EncodableValue("source")] =
      flutter::EncodableValue("windowsCommandLine");
  document[flutter::EncodableValue("activationId")] =
      flutter::EncodableValue(
          "windows:" + std::to_string(::GetTickCount64()) + ":" + path);

  document_channel_->InvokeMethod(
      "openDocument",
      std::make_unique<flutter::EncodableValue>(document));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_COPYDATA) {
    const auto* copy_data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (copy_data != nullptr &&
        copy_data->dwData == kEduSheetDocumentCopyDataId &&
        copy_data->lpData != nullptr && copy_data->cbData > 1) {
      const auto* bytes = static_cast<const char*>(copy_data->lpData);
      std::string path(bytes, bytes + copy_data->cbData);
      if (!path.empty() && path.back() == '\0') {
        path.pop_back();
      }

      if (!path.empty()) {
        if (document_channel_ && dart_ready_) {
          DispatchDocumentToDart(path);
        } else {
          pending_document_paths_.push_back(path);
        }

        if (::IsIconic(hwnd)) {
          ::ShowWindow(hwnd, SW_RESTORE);
        } else {
          ::ShowWindow(hwnd, SW_SHOW);
        }
        ::SetForegroundWindow(hwnd);
        return TRUE;
      }
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
