# ssh-handler (Rust)

A from-scratch rewrite of `SshHandler` (the .NET/WinForms `ssh://` protocol
handler) in Rust, targeting raw Win32 (via `windows-rs`) instead of a managed
GUI framework. Same behavior, same registry keys, same dialog layout — just
without the .NET runtime.

Why: the WinForms build's self-contained publish is ~150MB and pays CLR
startup cost on every single `ssh://` link click. This version has no
runtime, no GC, no JIT — cold start is just process creation plus a native
dialog box. Release build is ~250KB.

## Building

Cross-compiling from Linux (what CI does):

```sh
rustup target add x86_64-pc-windows-gnu
sudo apt install mingw-w64
cargo build --release --target x86_64-pc-windows-gnu
```

Or natively on Windows with the MSVC toolchain:

```sh
cargo build --release
```

The dialog is a native Win32 resource (`resources/ssh_handler.rc`), compiled
via `embed-resource` in `build.rs` — no GUI toolkit dependency.

## Behavior

- No arguments: setup mode. Checks for admin rights, confirms with the user,
  then writes the `ssh://` protocol registration under `HKEY_CLASSES_ROOT`.
- `ssh://user@host` argument: handler mode. Parses the target (defaulting the
  username to the current Windows user if omitted), shows a small dialog to
  confirm/edit the target and optionally enable "legacy mode" (older
  KEX/HostKey/MAC/cipher algorithms for old SSH servers), then launches
  `ssh.exe -A -C ... user@host` via `ShellExecuteW`.
