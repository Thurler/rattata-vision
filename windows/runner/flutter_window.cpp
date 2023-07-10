#include "flutter_window.h"

#include <optional>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <iostream>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

HWND sub_window;
bool sub_showing = true;
int sub_position[4] = {0, 0, 0, 0};

void update_position() {
  RECT rect;
  GetWindowRect(sub_window, &rect);
  sub_position[0] = rect.left;
  sub_position[1] = rect.top;
  sub_position[2] = rect.right - rect.left;
  sub_position[3] = rect.bottom - rect.top;
}

void handleMethods(
  const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result
) {
  if (call.method_name() == "showSubwindow") {
    ShowWindow(sub_window, SW_SHOWNORMAL);
    SetWindowPos(sub_window, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    sub_showing = true;
    result->Success();
  } else if (call.method_name() == "hideSubwindow") {
    ShowWindow(sub_window, SW_HIDE);
    sub_showing = false;
    result->Success();
  } else if (call.method_name() == "closeSubwindow") {
    // Because everything was instantiated inside this class, no need to call
    // close function - it gets destroyed alongside everything
    result->Success();
  } else if (call.method_name() == "getSubwindowBox") {
    if (sub_showing) {
      update_position();
    }
    std::vector resp = std::vector(sub_position, sub_position + 4);
    result->Success(resp);
  } else if (call.method_name() == "makeScreenshot") {
    update_position();
    HDC hScreen = GetDC(NULL);
    HDC htarget = CreateCompatibleDC(hScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hScreen, sub_position[2], sub_position[3]);
    SelectObject(htarget, hBitmap);
    BitBlt(
      htarget,
      0, 0, sub_position[2], sub_position[3],
      hScreen,
      sub_position[0], sub_position[1],
      SRCCOPY
    );
    BITMAP bitmap;
    GetObject(hBitmap, sizeof(BITMAP), &bitmap);
    BITMAPFILEHEADER bmfHeader;
    BITMAPINFOHEADER bi;
    bi.biSize = sizeof(BITMAPINFOHEADER);
    bi.biWidth = bitmap.bmWidth;
    bi.biHeight = bitmap.bmHeight;
    bi.biPlanes = 1;
    bi.biBitCount = 32;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = 0;
    bi.biXPelsPerMeter = 0;
    bi.biYPelsPerMeter = 0;
    bi.biClrUsed = 0;
    bi.biClrImportant = 0;
    DWORD dwBmpSize = ((bitmap.bmWidth * bi.biBitCount + 31) / 32) * 4 * bitmap.bmHeight;
    HANDLE hDIB = GlobalAlloc(GHND, dwBmpSize);
    char* lpbitmap = (char*)GlobalLock(hDIB);
    GetDIBits(htarget, hBitmap, 0, (UINT)bitmap.bmHeight, lpbitmap, (BITMAPINFO*)&bi, DIB_RGB_COLORS);
    HANDLE hFile = CreateFile(L"./rattata.bmp", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD dwSizeofDIB = dwBmpSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
    bmfHeader.bfOffBits = (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER);
    bmfHeader.bfSize = dwSizeofDIB;
    bmfHeader.bfType = 0x4D42;
    DWORD dwBytesWritten = 0;
    WriteFile(hFile, (LPSTR)&bmfHeader, sizeof(BITMAPFILEHEADER), &dwBytesWritten, NULL);
    WriteFile(hFile, (LPSTR)&bi, sizeof(BITMAPINFOHEADER), &dwBytesWritten, NULL);
    WriteFile(hFile, (LPSTR)lpbitmap, dwBmpSize, &dwBytesWritten, NULL);
    GlobalUnlock(hDIB);
    GlobalFree(hDIB);
    CloseHandle(hFile);
    DeleteObject(hBitmap);
    DeleteObject(htarget);
    ReleaseDC(NULL, hScreen);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

LRESULT CALLBACK wndProcSubWindow(
  HWND const window, UINT const message, WPARAM const wparam, LPARAM const lparam
) noexcept {
  switch (message) {
    case WM_GETMINMAXINFO: {
      MINMAXINFO* mmi = (MINMAXINFO*)lparam;
      mmi->ptMinTrackSize.x = 50;
      mmi->ptMinTrackSize.y = 50;
      return 0;
    }
    case WM_NCHITTEST: {
      update_position();
      int x = (short)LOWORD(lparam) - sub_position[0];
      int y = (short)HIWORD(lparam) - sub_position[1];
      int width = sub_position[2];
      int height = sub_position[3];
      bool north = false;
      bool west = false;
      bool east = false;
      bool south = false;
      if (x < 16) west = true;
      if (x > (width - 16)) east = true;
      if (y < 16) north = true;
      if (y > (height - 16)) south = true;
      LRESULT hit = DefWindowProc(window, message, wparam, lparam);
      if (hit == HTCLIENT) {
        if (north && west) return HTTOPLEFT;
        else if (north && east) return HTTOPRIGHT;
        else if (south && west) return HTBOTTOMLEFT;
        else if (south && east) return HTBOTTOMRIGHT;
        else if (north) return HTTOP;
        else if (south) return HTBOTTOM;
        else if (west) return HTLEFT;
        else if (east) return HTRIGHT;
        else return HTCAPTION;
      }
      return hit;
    }
  }
  return DefWindowProc(window, message, wparam, lparam);
}

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

  flutter::MethodChannel<> channel(
    flutter_controller_->engine()->messenger(),
    "subwindow_channel",
    &flutter::StandardMethodCodec::GetInstance()
  );
  channel.SetMethodCallHandler(handleMethods);

  // Create the secondary window to scan screen
  const wchar_t CLASS_NAME[]  = L"Test Class";
  WNDCLASS wc = {};
  wc.lpfnWndProc = wndProcSubWindow;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = CLASS_NAME;
  wc.hbrBackground = CreateSolidBrush(0x000000ff);
  RegisterClass(&wc);
  sub_window = CreateWindowEx(
    WS_EX_LAYERED,
    CLASS_NAME,
    NULL,
    WS_POPUP,
    CW_USEDEFAULT, CW_USEDEFAULT, 320, 180,
    NULL,
    NULL,
    GetModuleHandle(nullptr),
    NULL
  );
  ShowWindow(sub_window, SW_SHOWNORMAL);
  SetLayeredWindowAttributes(sub_window, 0, 51, LWA_ALPHA);
  SetWindowPos(sub_window, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
  update_position();

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
