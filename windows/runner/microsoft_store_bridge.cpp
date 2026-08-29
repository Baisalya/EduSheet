#include "microsoft_store_bridge.h"

#include <Shobjidl.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>
#include <winrt/base.h>

#include <memory>
#include <optional>
#include <string>
#include <utility>

namespace {
constexpr char kMicrosoftStoreChannelName[] = "edusheet/microsoft_store";

using EncodableResult = flutter::MethodResult<flutter::EncodableValue>;
using SharedResult = std::shared_ptr<EncodableResult>;
using StoreContext = winrt::Windows::Services::Store::StoreContext;
using StoreProduct = winrt::Windows::Services::Store::StoreProduct;

flutter::EncodableValue StoreResponse(const std::string& status,
                                      const std::string& message = "") {
  flutter::EncodableMap response;
  response[flutter::EncodableValue("status")] =
      flutter::EncodableValue(status);
  if (!message.empty()) {
    response[flutter::EncodableValue("message")] =
        flutter::EncodableValue(message);
  }
  return flutter::EncodableValue(response);
}

std::optional<std::string> ReadProductId(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    return std::nullopt;
  }
  const auto entry = arguments->find(flutter::EncodableValue("productId"));
  if (entry == arguments->end()) {
    return std::nullopt;
  }
  const auto* product_id = std::get_if<std::string>(&entry->second);
  if (product_id == nullptr || product_id->empty()) {
    return std::nullopt;
  }
  return *product_id;
}

StoreProduct FindDurableProduct(
    const winrt::Windows::Services::Store::StoreProductQueryResult& query,
    const winrt::hstring& product_id) {
  for (const auto& product_entry : query.Products()) {
    const StoreProduct product = product_entry.Value();
    if (product.InAppOfferToken() == product_id) {
      return product;
    }
  }
  return nullptr;
}

std::string HresultMessage(const winrt::hresult_error& error) {
  const std::string message = winrt::to_string(error.message());
  return message.empty() ? "Microsoft Store operation failed." : message;
}
}  // namespace

class MicrosoftStoreBridge::Impl {
 public:
  Impl(flutter::BinaryMessenger* messenger, HWND owner_window)
      : channel_(std::make_unique<
                 flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, kMicrosoftStoreChannelName,
            &flutter::StandardMethodCodec::GetInstance())) {
    try {
      store_context_ = StoreContext::GetDefault();
      const auto initialize_with_window =
          store_context_.as<IInitializeWithWindow>();
      winrt::check_hresult(initialize_with_window->Initialize(owner_window));
    } catch (const winrt::hresult_error& error) {
      initialization_error_ = HresultMessage(error);
      store_context_ = nullptr;
    }

    channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          HandleMethodCall(call, std::move(result));
        });
  }

  ~Impl() { channel_->SetMethodCallHandler(nullptr); }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<EncodableResult> result) {
    const auto product_id = ReadProductId(call);
    if (!product_id.has_value()) {
      result->Error("invalid_argument", "A premium productId is required.");
      return;
    }
    if (!store_context_) {
      result->Success(StoreResponse(
          "unavailable",
          initialization_error_.empty()
              ? "Microsoft Store requires an installed MSIX package."
              : initialization_error_));
      return;
    }

    SharedResult shared_result(std::move(result));
    if (call.method_name() == "getProduct") {
      GetProduct(*product_id, std::move(shared_result));
    } else if (call.method_name() == "purchase") {
      Purchase(*product_id, std::move(shared_result));
    } else if (call.method_name() == "restore") {
      Restore(*product_id, std::move(shared_result));
    } else {
      shared_result->NotImplemented();
    }
  }

  void GetProduct(const std::string& product_id, SharedResult result) {
    try {
      auto kinds = winrt::single_threaded_vector<winrt::hstring>();
      kinds.Append(L"Durable");
      const auto operation =
          store_context_.GetAssociatedStoreProductsAsync(kinds);
      operation.Completed(
          [product_id = winrt::to_hstring(product_id), result](
              const auto& async_operation,
              winrt::Windows::Foundation::AsyncStatus status) {
            if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
              result->Success(StoreResponse(
                  "unavailable", "Microsoft Store product lookup failed."));
              return;
            }
            try {
              const auto query = async_operation.GetResults();
              const StoreProduct product =
                  FindDurableProduct(query, product_id);
              if (!product) {
                result->Success(StoreResponse("notConfigured"));
                return;
              }

              flutter::EncodableMap response;
              response[flutter::EncodableValue("status")] =
                  flutter::EncodableValue("ready");
              response[flutter::EncodableValue("productId")] =
                  flutter::EncodableValue(
                      winrt::to_string(product.InAppOfferToken()));
              response[flutter::EncodableValue("title")] =
                  flutter::EncodableValue(winrt::to_string(product.Title()));
              response[flutter::EncodableValue("description")] =
                  flutter::EncodableValue(
                      winrt::to_string(product.Description()));
              response[flutter::EncodableValue("price")] =
                  flutter::EncodableValue(
                      winrt::to_string(product.Price().FormattedPrice()));
              response[flutter::EncodableValue("isPurchased")] =
                  flutter::EncodableValue(product.IsInUserCollection());
              result->Success(flutter::EncodableValue(response));
            } catch (const winrt::hresult_error& error) {
              result->Success(
                  StoreResponse("unavailable", HresultMessage(error)));
            }
          });
    } catch (const winrt::hresult_error& error) {
      result->Success(StoreResponse("unavailable", HresultMessage(error)));
    }
  }

  void Purchase(const std::string& product_id, SharedResult result) {
    try {
      auto kinds = winrt::single_threaded_vector<winrt::hstring>();
      kinds.Append(L"Durable");
      const auto query_operation =
          store_context_.GetAssociatedStoreProductsAsync(kinds);
      query_operation.Completed(
          [product_id = winrt::to_hstring(product_id), result](
              const auto& async_operation,
              winrt::Windows::Foundation::AsyncStatus status) {
            if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
              result->Success(StoreResponse(
                  "unavailable", "Microsoft Store product lookup failed."));
              return;
            }
            try {
              const StoreProduct product =
                  FindDurableProduct(async_operation.GetResults(), product_id);
              if (!product) {
                result->Success(StoreResponse(
                    "notConfigured",
                    "Premium is not configured in Microsoft Store yet."));
                return;
              }

              const auto purchase_operation = product.RequestPurchaseAsync();
              purchase_operation.Completed(
                  [result](const auto& purchase_async,
                           winrt::Windows::Foundation::AsyncStatus
                               purchase_status) {
                    if (purchase_status !=
                        winrt::Windows::Foundation::AsyncStatus::Completed) {
                      result->Success(StoreResponse(
                          "unavailable",
                          "Microsoft Store purchase did not complete."));
                      return;
                    }
                    try {
                      const auto purchase = purchase_async.GetResults();
                      using winrt::Windows::Services::Store::
                          StorePurchaseStatus;
                      switch (purchase.Status()) {
                        case StorePurchaseStatus::Succeeded:
                          result->Success(StoreResponse("succeeded"));
                          return;
                        case StorePurchaseStatus::AlreadyPurchased:
                          result->Success(
                              StoreResponse("alreadyPurchased"));
                          return;
                        case StorePurchaseStatus::NotPurchased:
                          result->Success(StoreResponse("notPurchased"));
                          return;
                        case StorePurchaseStatus::NetworkError:
                          result->Success(StoreResponse(
                              "networkError",
                              "Microsoft Store could not reach the network."));
                          return;
                        case StorePurchaseStatus::ServerError:
                          result->Success(StoreResponse(
                              "serverError",
                              "Microsoft Store returned a server error."));
                          return;
                      }
                    } catch (const winrt::hresult_error& error) {
                      result->Success(StoreResponse(
                          "unavailable", HresultMessage(error)));
                    }
                  });
            } catch (const winrt::hresult_error& error) {
              result->Success(
                  StoreResponse("unavailable", HresultMessage(error)));
            }
          });
    } catch (const winrt::hresult_error& error) {
      result->Success(StoreResponse("unavailable", HresultMessage(error)));
    }
  }

  void Restore(const std::string& product_id, SharedResult result) {
    try {
      const auto operation = store_context_.GetAppLicenseAsync();
      operation.Completed(
          [product_id = winrt::to_hstring(product_id), result](
              const auto& async_operation,
              winrt::Windows::Foundation::AsyncStatus status) {
            if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
              result->Success(StoreResponse(
                  "unavailable", "Microsoft Store licence lookup failed."));
              return;
            }
            try {
              const auto license = async_operation.GetResults();
              for (const auto& license_entry : license.AddOnLicenses()) {
                if (license_entry.Value().InAppOfferToken() == product_id) {
                  result->Success(StoreResponse("restored"));
                  return;
                }
              }
              result->Success(StoreResponse("notFound"));
            } catch (const winrt::hresult_error& error) {
              result->Success(
                  StoreResponse("unavailable", HresultMessage(error)));
            }
          });
    } catch (const winrt::hresult_error& error) {
      result->Success(StoreResponse("unavailable", HresultMessage(error)));
    }
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  StoreContext store_context_{nullptr};
  std::string initialization_error_;
};

MicrosoftStoreBridge::MicrosoftStoreBridge(
    flutter::BinaryMessenger* messenger, HWND owner_window)
    : impl_(std::make_unique<Impl>(messenger, owner_window)) {}

MicrosoftStoreBridge::~MicrosoftStoreBridge() = default;
