#include "kiosk_shell.h"

#include <windows.h>

namespace {

bool g_enabled = false;
HHOOK g_keyboard_hook = nullptr;

void SetTaskbarVisible(bool visible) {
  HWND taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
  if (taskbar) {
    ShowWindow(taskbar, visible ? SW_SHOW : SW_HIDE);
  }
  HWND secondary = FindWindowW(L"Shell_SecondaryTrayWnd", nullptr);
  if (secondary) {
    ShowWindow(secondary, visible ? SW_SHOW : SW_HIDE);
  }
}

bool IsBlockedKey(DWORD vkCode, DWORD flags) {
  const bool alt_down = (flags & LLKHF_ALTDOWN) != 0;
  const bool ctrl_down = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;

  if (vkCode == VK_LWIN || vkCode == VK_RWIN) {
    return true;
  }
  if (alt_down && (vkCode == VK_TAB || vkCode == VK_ESCAPE || vkCode == VK_F4)) {
    return true;
  }
  if (ctrl_down && vkCode == VK_ESCAPE) {
    return true;
  }
  if (vkCode == VK_APPS) {
    return true;
  }
  return false;
}

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wparam, LPARAM lparam) {
  if (nCode == HC_ACTION && g_enabled) {
    const auto* kb = reinterpret_cast<KBDLLHOOKSTRUCT*>(lparam);
    if (kb != nullptr && IsBlockedKey(kb->vkCode, kb->flags)) {
      return 1;
    }
  }
  return CallNextHookEx(g_keyboard_hook, nCode, wparam, lparam);
}

void InstallHook() {
  if (g_keyboard_hook != nullptr) {
    return;
  }
  g_keyboard_hook =
      SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandleW(nullptr), 0);
}

void RemoveHook() {
  if (g_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_keyboard_hook);
    g_keyboard_hook = nullptr;
  }
}

}  // namespace

void EnableKioskShell(bool enable) {
  if (enable == g_enabled) {
    return;
  }
  g_enabled = enable;
  if (enable) {
    SetTaskbarVisible(false);
    InstallHook();
  } else {
    RemoveHook();
    SetTaskbarVisible(true);
  }
}
