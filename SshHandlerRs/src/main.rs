#![windows_subsystem = "windows"]

use windows::core::{w, PCWSTR};
use windows::Win32::Foundation::{HWND, LPARAM, WPARAM};
use windows::Win32::System::Registry::{
    RegCreateKeyExW, RegSetValueExW, HKEY, HKEY_CLASSES_ROOT, HKEY_LOCAL_MACHINE, KEY_WRITE,
    REG_OPTION_NON_VOLATILE, REG_SZ,
};
use windows::Win32::System::LibraryLoader::GetModuleHandleW;
use windows::Win32::UI::Controls::IsDlgButtonChecked;
use windows::Win32::UI::Input::KeyboardAndMouse::SetFocus;
use windows::Win32::UI::Shell::{IsUserAnAdmin, ShellExecuteW};
use windows::Win32::UI::WindowsAndMessaging::{
    DialogBoxParamW, EndDialog, GetDlgItem, GetDlgItemTextW, GetWindowLongPtrW, MessageBoxW,
    SendDlgItemMessageW, SetDlgItemTextW, SetWindowLongPtrW, GWLP_USERDATA, IDCANCEL, IDOK, IDYES,
    MB_ICONERROR, MB_ICONINFORMATION, MB_ICONQUESTION, MB_OK, MB_YESNO, SW_SHOWNORMAL, WM_CLOSE,
    WM_COMMAND, WM_INITDIALOG,
};

const IDD_CONNECT: u16 = 101;
const IDC_EDIT_TARGET: i32 = 1001;
const IDC_CHECK_LEGACY: i32 = 1002;
const BST_CHECKED: usize = 1;
const EM_SETSEL: u32 = 0x00B1;

const LEGACY_ARGS: &str = "-o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
-o HostKeyAlgorithms=+ssh-rsa -o MACs=+hmac-sha1,hmac-sha1-96 -o ciphers=+aes256-cbc";

/// Our ProgID / capability-provider identifier under HKCR and RegisteredApplications.
/// Distinct from the .bat's "ssh_custom_handler" so both can coexist/be told apart.
const PROG_ID: &str = "ssh_handler_rs";
const APP_DISPLAY_NAME: &str = "SSH Handler (Rust)";

fn to_wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

fn message_box(text: &str, caption: &str, flags: windows::Win32::UI::WindowsAndMessaging::MESSAGEBOX_STYLE) -> windows::Win32::UI::WindowsAndMessaging::MESSAGEBOX_RESULT {
    let text = to_wide(text);
    let caption = to_wide(caption);
    unsafe {
        MessageBoxW(
            None,
            PCWSTR(text.as_ptr()),
            PCWSTR(caption.as_ptr()),
            flags,
        )
    }
}

fn current_exe_path() -> String {
    std::env::current_exe()
        .map(|p| p.display().to_string())
        .unwrap_or_default()
}

fn current_username() -> String {
    std::env::var("USERNAME").unwrap_or_else(|_| "user".to_string())
}

/// Data passed into / out of the connect dialog.
struct DialogData {
    initial_target: Vec<u16>,
    result_target: String,
    legacy: bool,
    accepted: bool,
}

unsafe extern "system" fn dialog_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> isize {
    match msg {
        WM_INITDIALOG => {
            // lparam carries the raw pointer to our DialogData (see DialogBoxParamW call).
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, lparam.0);
            let data = &*(lparam.0 as *const DialogData);
            let _ = SetDlgItemTextW(hwnd, IDC_EDIT_TARGET, PCWSTR(data.initial_target.as_ptr()));
            // Select all text in the edit box and give it focus.
            let _ = SendDlgItemMessageW(hwnd, IDC_EDIT_TARGET, EM_SETSEL, WPARAM(0), LPARAM(-1));
            let edit_hwnd = GetDlgItem(hwnd, IDC_EDIT_TARGET).unwrap_or_default();
            let _ = SetFocus(edit_hwnd);
            1 // we set focus ourselves
        }
        WM_COMMAND => {
            let control_id = (wparam.0 & 0xFFFF) as i32;
            if control_id == IDOK.0 {
                let ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut DialogData;
                if !ptr.is_null() {
                    let data = &mut *ptr;
                    let mut buf = [0u16; 512];
                    let len = GetDlgItemTextW(hwnd, IDC_EDIT_TARGET, &mut buf);
                    data.result_target = String::from_utf16_lossy(&buf[..len as usize]);
                    data.legacy =
                        IsDlgButtonChecked(hwnd, IDC_CHECK_LEGACY) as usize == BST_CHECKED;
                    data.accepted = true;
                }
                let _ = EndDialog(hwnd, IDOK.0 as isize);
                return 1;
            } else if control_id == IDCANCEL.0 {
                let ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut DialogData;
                if !ptr.is_null() {
                    (&mut *ptr).accepted = false;
                }
                let _ = EndDialog(hwnd, IDCANCEL.0 as isize);
                return 1;
            }
            0
        }
        WM_CLOSE => {
            let ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut DialogData;
            if !ptr.is_null() {
                (&mut *ptr).accepted = false;
            }
            let _ = EndDialog(hwnd, IDCANCEL.0 as isize);
            1
        }
        _ => 0,
    }
}

fn show_connect_dialog(initial_target: &str) -> Option<(String, bool)> {
    let mut data = Box::new(DialogData {
        initial_target: to_wide(initial_target),
        result_target: String::new(),
        legacy: false,
        accepted: false,
    });
    let data_ptr = data.as_mut() as *mut DialogData;

    unsafe {
        let hinstance: windows::Win32::Foundation::HINSTANCE =
            GetModuleHandleW(None).unwrap_or_default().into();
        DialogBoxParamW(
            hinstance,
            windows::core::PCWSTR(IDD_CONNECT as *const u16),
            None,
            Some(dialog_proc),
            LPARAM(data_ptr as isize),
        );
    }

    if data.accepted {
        Some((data.result_target.clone(), data.legacy))
    } else {
        None
    }
}

fn is_admin() -> bool {
    unsafe { IsUserAnAdmin().as_bool() }
}

fn setup_handler() {
    if !is_admin() {
        message_box(
            "Please run this application as an administrator to register the URL handler.",
            "Admin Privileges Required",
            MB_OK | MB_ICONERROR,
        );
        return;
    }

    let exe_path = current_exe_path();
    let command_str = format!("\"{exe_path}\" \"%1\"");

    let prompt = format!(
        "This will register this application ({APP_DISPLAY_NAME}) as a candidate handler for ssh:// links.\n\n\
        Command:\n{command_str}\n\n\
        After this, you may need to open Settings > Apps > Default Apps > \"Choose default apps by link type\", \
        find \"ssh\", and select {APP_DISPLAY_NAME} explicitly — Windows does not let an installer silently \
        override an existing default protocol handler.\n\n\
        Do you want to proceed?"
    );
    let result = message_box(&prompt, "Registry Setup", MB_YESNO | MB_ICONQUESTION);
    if result != IDYES {
        return;
    }

    match register_protocol(&exe_path, &command_str) {
        Ok(()) => {
            message_box(
                &format!(
                    "Registered {APP_DISPLAY_NAME} as an ssh:// handler.\n\n\
                    If ssh:// links don't launch it, open Settings > Apps > Default Apps > \
                    \"Choose default apps by link type\", find \"ssh\", and pick it there."
                ),
                "Success",
                MB_OK | MB_ICONINFORMATION,
            );
        }
        Err(e) => {
            message_box(
                &format!("Failed to write to registry:\n{e:?}"),
                "Error",
                MB_OK | MB_ICONERROR,
            );
        }
    }
}

/// Sets a REG_SZ value. `value_name = None` targets the key's default (unnamed) value.
fn reg_set_sz(hkey: HKEY, value_name: Option<&str>, data: &str) -> windows::core::Result<()> {
    let name_wide = value_name.map(to_wide);
    let name_ptr = match &name_wide {
        Some(w) => PCWSTR(w.as_ptr()),
        None => PCWSTR::null(),
    };
    let data_wide = to_wide(data);
    let bytes = unsafe {
        std::slice::from_raw_parts(data_wide.as_ptr() as *const u8, data_wide.len() * 2)
    };
    unsafe { RegSetValueExW(hkey, name_ptr, 0, REG_SZ, Some(bytes)) }.ok()
}

fn reg_create_key(root: HKEY, subkey: &str) -> windows::core::Result<HKEY> {
    let subkey_wide = to_wide(subkey);
    let mut key = HKEY::default();
    unsafe {
        RegCreateKeyExW(
            root,
            PCWSTR(subkey_wide.as_ptr()),
            0,
            None,
            REG_OPTION_NON_VOLATILE,
            KEY_WRITE,
            None,
            &mut key,
            None,
        )
    }
    .ok()?;
    Ok(key)
}

/// Registers via the "Default Programs" capability model (RegisteredApplications +
/// a distinct ProgID with Capabilities\UrlAssociations), the same pattern
/// `openssh_protocol_handler.bat` uses — this is what actually shows up in and gets
/// honored by Windows' "Choose default apps by link type" UI. A bare
/// HKCR\ssh\shell\open\command write is ignored once a UserChoice already exists for
/// the protocol, which is the common case on Windows 10/11.
fn register_protocol(exe_path: &str, command_str: &str) -> windows::core::Result<()> {
    // Declare "ssh" as a URL protocol scheme (legacy marker some apps still check for).
    let ssh_key = reg_create_key(HKEY_CLASSES_ROOT, "ssh")?;
    reg_set_sz(ssh_key, None, "URL:ssh Protocol")?;
    reg_set_sz(ssh_key, Some("URL Protocol"), "")?;

    // Our ProgID: the actual open command plus Default-Apps display metadata.
    let cmd_key = reg_create_key(HKEY_CLASSES_ROOT, &format!("{PROG_ID}\\shell\\open\\command"))?;
    reg_set_sz(cmd_key, None, command_str)?;

    let app_key = reg_create_key(HKEY_CLASSES_ROOT, &format!("{PROG_ID}\\Application"))?;
    reg_set_sz(app_key, Some("ApplicationIcon"), &format!("\"{exe_path}\",0"))?;
    reg_set_sz(app_key, Some("ApplicationName"), APP_DISPLAY_NAME)?;
    reg_set_sz(
        app_key,
        Some("ApplicationDescription"),
        "Handles ssh:// links via Windows OpenSSH",
    )?;

    let caps_key = reg_create_key(
        HKEY_CLASSES_ROOT,
        &format!("{PROG_ID}\\Capabilities\\UrlAssociations"),
    )?;
    reg_set_sz(caps_key, Some("ssh"), PROG_ID)?;

    // Tell Windows' Default Apps UI this app exists as a capability provider.
    let registered_key = reg_create_key(HKEY_LOCAL_MACHINE, "SOFTWARE\\RegisteredApplications")?;
    reg_set_sz(
        registered_key,
        Some(APP_DISPLAY_NAME),
        &format!("Software\\Classes\\{PROG_ID}\\Capabilities"),
    )?;

    Ok(())
}

fn handle_connection(url: &str) {
    let mut target = url.trim_start_matches("ssh://").trim_end_matches('/').to_string();
    if !target.contains('@') {
        target = format!("{}@{}", current_username(), target);
    }

    let Some((final_target, legacy)) = show_connect_dialog(&target) else {
        return;
    };

    let legacy_args = if legacy { LEGACY_ARGS } else { "" };
    let arguments = format!("-A -C {legacy_args} {final_target}");

    let ssh_exe = w!("ssh.exe");
    let args_wide = to_wide(&arguments);
    let verb = w!("open");

    unsafe {
        ShellExecuteW(
            None,
            verb,
            ssh_exe,
            PCWSTR(args_wide.as_ptr()),
            None,
            SW_SHOWNORMAL,
        );
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        setup_handler();
    } else {
        handle_connection(&args[0]);
    }
}
