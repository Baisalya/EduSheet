#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kEduSheetInstanceMutex[] =
    L"Local\\EduSheet.DocumentReader.Instance";
constexpr wchar_t kEduSheetWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kEduSheetWindowTitle[] = L"EduSheet";
constexpr ULONG_PTR kEduSheetDocumentCopyDataId = 0x4553444F;  // "ESDO"

HWND FindRunningEduSheetWindow() {
  // The first instance may still be creating its window when the second process
  // starts. Wait briefly rather than launching a second heavy Flutter engine.
  for (int attempt = 0; attempt < 40; ++attempt) {
    HWND window = ::FindWindow(kEduSheetWindowClass, kEduSheetWindowTitle);
    if (window != nullptr) {
      return window;
    }
    ::Sleep(50);
  }
  return nullptr;
}

bool ForwardDocumentToExistingInstance(
    const std::vector<std::string>& command_line_arguments) {
  HWND window = FindRunningEduSheetWindow();
  if (window == nullptr) {
    return false;
  }

  if (!command_line_arguments.empty()) {
    const std::string& path = command_line_arguments.front();
    COPYDATASTRUCT copy_data{};
    copy_data.dwData = kEduSheetDocumentCopyDataId;
    copy_data.cbData = static_cast<DWORD>(path.size() + 1);
    copy_data.lpData = const_cast<char*>(path.c_str());

    DWORD_PTR result = 0;
    if (::SendMessageTimeout(
            window, WM_COPYDATA, 0,
            reinterpret_cast<LPARAM>(&copy_data),
            SMTO_ABORTIFHUNG | SMTO_BLOCK, 2500, &result) == 0) {
      return false;
    }
  }

  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  } else {
    ::ShowWindow(window, SW_SHOW);
  }
  ::SetForegroundWindow(window);
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  HANDLE instance_mutex =
      ::CreateMutex(nullptr, TRUE, kEduSheetInstanceMutex);
  const bool already_running =
      instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS;

  if (already_running &&
      ForwardDocumentToExistingInstance(command_line_arguments)) {
    if (instance_mutex != nullptr) {
      ::CloseHandle(instance_mutex);
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kEduSheetWindowTitle, origin, size)) {
    if (instance_mutex != nullptr) {
      ::ReleaseMutex(instance_mutex);
      ::CloseHandle(instance_mutex);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (instance_mutex != nullptr) {
    ::ReleaseMutex(instance_mutex);
    ::CloseHandle(instance_mutex);
  }
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
