# ssh-handler (Rust)

The Windows `ssh://` protocol handler, in Rust — raw Win32 (via `windows-rs`)
instead of a managed GUI framework. This started as a rewrite of an earlier
.NET/WinForms version (since removed) whose self-contained publish was
~150MB and paid CLR startup cost on every single `ssh://` link click. This
version has no runtime, no GC, no JIT — cold start is just process creation
plus a native dialog box. Release build is ~250KB.

## Building

CI (`.github/workflows/build.yml`) builds natively on `windows-latest` with
the MSVC toolchain:

```sh
cargo build --release --target x86_64-pc-windows-msvc
```

Cross-compiling from Linux also works, e.g. for local iteration:

```sh
rustup target add x86_64-pc-windows-gnu
sudo apt install mingw-w64
cargo build --release --target x86_64-pc-windows-gnu
```

The dialog is a native Win32 resource (`resources/ssh_handler.rc`), compiled
via `embed-resource` in `build.rs` — no GUI toolkit dependency.

## Behavior

- No arguments: setup mode. Checks for admin rights, confirms with the user,
  then registers `ssh_handler_rs` as an `ssh://` handler using the "Default
  Programs" capability model (a dedicated ProgID with
  `Capabilities\UrlAssociations`, plus a
  `HKLM\SOFTWARE\RegisteredApplications` entry) — the same pattern
  `openssh_protocol_handler.bat` uses, and the one Windows 10/11 actually
  honors in Settings > Apps > Default Apps > "Choose default apps by link
  type". A bare `HKCR\ssh\shell\open\command` write (what the old .NET
  version did) gets silently ignored once a `UserChoice` already exists for
  the protocol, which is the common case.
- `ssh://user@host` argument: handler mode. Parses the target (defaulting the
  username to the current Windows user if omitted), shows a small dialog to
  confirm/edit the target and optionally enable "legacy mode" (older
  KEX/HostKey/MAC/cipher algorithms for old SSH servers), then launches
  `ssh.exe -A -C ... user@host` via `ShellExecuteW`.
