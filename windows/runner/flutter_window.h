#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that hosts the Flutter view and receives warm document activations
// forwarded by a second EduSheet process.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void DispatchDocumentToDart(const std::string& path);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Native-to-Dart activation channel used when an already-running EduSheet
  // instance receives a document from Windows Explorer/Open With.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      document_channel_;

  // WM_COPYDATA can arrive while the first Flutter frame is still starting.
  // Queue those paths until the platform channel exists instead of dropping
  // the activation.
  std::vector<std::string> pending_document_paths_;
  bool dart_ready_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
