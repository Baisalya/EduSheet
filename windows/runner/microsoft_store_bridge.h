#ifndef RUNNER_MICROSOFT_STORE_BRIDGE_H_
#define RUNNER_MICROSOFT_STORE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

// Exposes Windows.Services.Store durable add-on operations to Dart. Store UI
// is explicitly parented to the Flutter HWND as required for desktop apps.
class MicrosoftStoreBridge {
 public:
  MicrosoftStoreBridge(flutter::BinaryMessenger* messenger, HWND owner_window);
  ~MicrosoftStoreBridge();

  MicrosoftStoreBridge(const MicrosoftStoreBridge&) = delete;
  MicrosoftStoreBridge& operator=(const MicrosoftStoreBridge&) = delete;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_MICROSOFT_STORE_BRIDGE_H_
