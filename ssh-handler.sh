#!/bin/bash
# ============================================================================
# == Simple SSH Link Protocol Handler for Linux                             ==
# == Uses XDG standards and works with most desktop environments.           ==
# ==                                                                        ==
# == To install, run this script with sudo:                                 ==
# ==   chmod +x ./ssh-handler.sh                                            ==
# ==   sudo ./ssh-handler.sh --install                                      ==
# ==                                                                        ==
# == To uninstall:                                                          ==
# ==   sudo ./ssh-handler.sh --uninstall                                    ==
# ==                                                                        ==
# == To debug configuration:                                                ==
# ==   ./ssh-handler.sh --debug                                             ==
# ==                                                                        ==
# == Public Domain. https://tcpip.wtf                                       ==
# ============================================================================

# --- SCRIPT MODE DETECTION ---
if [ "$1" == "--install" ]; then
    MODE="SETUP"
elif [ "$1" == "--uninstall" ]; then
    MODE="UNINSTALL"
elif [ "$1" == "--debug" ]; then
    MODE="DEBUG"
elif [[ "$1" == ssh://* ]]; then
    MODE="HANDLER"
else
    echo "Usage:"
    echo "  To install:   $0 --install"
    echo "  To uninstall: $0 --uninstall"
    echo "  To debug:     $0 --debug"
    echo "  (This script is usually called by your desktop environment to handle a URL.)"
    exit 1
fi

# A function to display errors both on stderr and via desktop notifications.
show_error() {
    local message="$1"
    # Print to standard error
    echo "ERROR: $message" >&2
    # Send a desktop notification if possible
    if command -v notify-send &> /dev/null; then
        notify-send --icon=dialog-error "SSH Handler Error" "$message"
    fi
}

# A function to display informational messages both on stdout and via notifications.
show_info() {
    local message="$1"
    # Print to standard output
    echo "$message"
    # Send a desktop notification if possible
    if command -v notify-send &> /dev/null; then
        notify-send --icon=info "SSH Handler" "$message"
    fi
}

# ============================================================================
# == DEBUG MODE                                                             ==
# ============================================================================
if [ "$MODE" == "DEBUG" ]; then
    echo
    echo "[ DEBUG MODE ]"
    echo "Checking system configuration for ssh:// URL handling..."
    echo "--------------------------------------------------------"

    # 1. Check what the system thinks is the default handler
    echo "[1] Querying XDG for the default ssh:// handler..."
    DEFAULT_HANDLER=$(xdg-mime query default x-scheme-handler/ssh)
    if [ -n "$DEFAULT_HANDLER" ]; then
        echo "    -> Default handler is: $DEFAULT_HANDLER"
        if [ "$DEFAULT_HANDLER" != "ssh-handler.desktop" ]; then
            echo "    [!] WARNING: The default handler is not our script. Another application has taken precedence."
            echo "        You may need to set the default handler manually in your desktop environment's settings,"
            echo "        or re-run 'sudo ./ssh-handler.sh --install' to try and set it again."
        else
            echo "    [+] CORRECT: The default handler is correctly set to our script."
        fi
    else
        echo "    [!] ERROR: No default handler is configured for ssh:// links on your system."
        echo "        Please run 'sudo ./ssh-handler.sh --install'."
    fi

    # 2. Check if the desktop file exists and is correct
    echo
    echo "[2] Checking the .desktop file..."
    DESKTOP_FILE_PATH="/usr/share/applications/ssh-handler.desktop"
    if [ -f "$DESKTOP_FILE_PATH" ]; then
        echo "    [+] FOUND: $DESKTOP_FILE_PATH"
        EXEC_LINE=$(grep "^Exec=" "$DESKTOP_FILE_PATH")
        echo "    -> Exec line is: $EXEC_LINE"
        if [[ "$EXEC_LINE" != "Exec=/usr/local/bin/ssh-handler %u" ]]; then
            echo "    [!] WARNING: The Exec line seems incorrect. It should be 'Exec=/usr/local/bin/ssh-handler %u'."
        fi
    else
        echo "    [!] ERROR: The desktop file does not exist. The script is not installed correctly."
    fi

    # 3. Check if the script itself is installed
    echo
    echo "[3] Checking if the handler script is installed..."
    INSTALL_PATH="/usr/local/bin/ssh-handler"
    if [ -x "$INSTALL_PATH" ]; then
        echo "    [+] FOUND and executable: $INSTALL_PATH"
    else
        echo "    [!] ERROR: The script is not found or is not executable at $INSTALL_PATH."
    fi
    echo "--------------------------------------------------------"
    echo "Debug finished."
    echo
    exit 0
fi

# ============================================================================
# == SETUP / UNINSTALL MODE                                                 ==
# ============================================================================
if [ "$MODE" == "SETUP" ] || [ "$MODE" == "UNINSTALL" ]; then

    # --- 1. SCRIPT AND DESKTOP FILE CONFIGURATION ---
    INSTALL_PATH="/usr/local/bin/ssh-handler"
    DESKTOP_FILE_NAME="ssh-handler.desktop"
    DESKTOP_FILE_PATH="/usr/share/applications/$DESKTOP_FILE_NAME"

    # --- 2. CHECK FOR ROOT PRIVILEGES ---
    if [ "$(id -u)" -ne 0 ]; then
        show_error "This operation requires root privileges. Please run with 'sudo'."
        exit 1
    fi
    echo "[+] Root privileges confirmed."


    # --- 3. UNINSTALL LOGIC ---
    if [ "$MODE" == "UNINSTALL" ]; then
        echo
        show_info "Uninstalling SSH protocol handler..."

        if [ -f "$INSTALL_PATH" ]; then
            echo "[-] Removing script: $INSTALL_PATH"
            rm -f "$INSTALL_PATH"
        else
            echo "[!] Script not found at $INSTALL_PATH (already removed?)."
        fi

        if [ -f "$DESKTOP_FILE_PATH" ]; then
            echo "[-] Removing .desktop file: $DESKTOP_FILE_PATH"
            rm -f "$DESKTOP_FILE_PATH"
            update-desktop-database /usr/share/applications
        else
            echo "[!] Desktop file not found at $DESKTOP_FILE_PATH (already removed?)."
        fi

        show_info "Uninstallation complete."
        exit 0
    fi

    # --- 4. SETUP LOGIC ---
    echo
    show_info "Installing SSH protocol handler..."

    echo "[+] Installing script to $INSTALL_PATH..."
    cp "$0" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    echo "[+] Creating .desktop file at $DESKTOP_FILE_PATH..."
    cat > "$DESKTOP_FILE_PATH" << EOF
[Desktop Entry]
Name=SSH Protocol Handler
Comment=Handles ssh:// links via the system's default terminal
Exec=$INSTALL_PATH %u
Icon=utilities-terminal
Terminal=false
Type=Application
MimeType=x-scheme-handler/ssh;
Categories=Network;
EOF

    echo "[+] Registering the new handler with the system..."
    xdg-mime default "$DESKTOP_FILE_NAME" x-scheme-handler/ssh
    update-desktop-database /usr/share/applications

    echo
    show_info "SUCCESS: Your system is now configured to open ssh:// links."
    echo
    exit 0
fi

# ============================================================================
# == HANDLER MODE                                                           ==
# ============================================================================
if [ "$MODE" == "HANDLER" ]; then
    # --- 1. PARSE THE URL ---
    FULL_URL="$1"
    TARGET="${FULL_URL#ssh://}"
    if [ "${TARGET: -1}" == "/" ]; then
        TARGET="${TARGET::-1}"
    fi

    if [[ "$TARGET" =~ "@" ]]; then
        SshUser="${TARGET%@*}"
        SshHost="${TARGET#*@}"
    else
        SshUser="$USER"
        SshHost="$TARGET"
    fi

    # Show initial notification that the link was received
    show_info "Received SSH link for ${SshUser}@${SshHost}..."

    # --- 2. DETERMINE DIALOG TOOL ---
    DIALOG_TOOL="read"
    if command -v zenity &> /dev/null; then
        DIALOG_TOOL="zenity"
    fi

    # --- 3. INTERACTIVE PROMPTS ---
    LegacyOpts=""
    USER_CANCELLED=false

    if [ "$DIALOG_TOOL" == "zenity" ]; then
        NewUser=$(zenity --entry --title="SSH Connection" --text="Connecting to Host: $SshHost\nEnter username:" --entry-text="$SshUser" --ok-label="Next")
        if [ $? -ne 0 ]; then
            USER_CANCELLED=true
        else
            if [ -n "$NewUser" ]; then SshUser="$NewUser"; fi
            zenity --question --title="Legacy Mode" --text="Enable legacy mode for old devices?\n(This uses insecure algorithms)" --ok-label="Yes, Enable" --cancel-label="No"
            if [ $? -eq 0 ]; then
                LegacyOpts="-o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o MACs=+hmac-sha1,hmac-sha1-96 -o ciphers=+aes256-cbc"
            fi
        fi
    else
        TUI_SCRIPT=$(printf 'SshUser="%s"; SshHost="%s"; clear; echo; echo "  Host: $SshHost"; echo "  User: $SshUser"; echo; read -p "Change username? (y/N): " choice; choice=${choice,,}; if [[ "$choice" == "y" || "$choice" == "yes" ]]; then read -p "Enter new username: " NewUser; if [ -n "$NewUser" ]; then SshUser="$NewUser"; fi; fi; echo; read -p "Enable legacy mode? (y/N): " legacy_choice; legacy_choice=${legacy_choice,,}; if [[ "$legacy_choice" == "y" || "$legacy_choice" == "yes" ]]; then LegacyOpts="-o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o MACs=+hmac-sha1,hmac-sha1-96"; fi; FINAL_TARGET="$SshUser@$SshHost"; echo; echo "Connecting to: $FINAL_TARGET"; echo "-------------------------------------------"; SSH_ARGS_TUI=(-A -C); if [ -n "$LegacyOpts" ]; then read -ra LEGACY_ARRAY_TUI <<< "$LegacyOpts"; SSH_ARGS_TUI+=("${LEGACY_ARRAY_TUI[@]}"); fi; SSH_ARGS_TUI+=("$FINAL_TARGET"); exec ssh "${SSH_ARGS_TUI[@]}"' "$SshUser" "$SshHost")
        
        # Find and use a terminal emulator
        TERMINAL_CMD=()
        TERMINAL_NAME=""
        if command -v x-terminal-emulator &> /dev/null && [ -x "$(realpath /usr/bin/x-terminal-emulator 2>/dev/null)" ]; then
            TERMINAL_NAME="x-terminal-emulator"
            TERMINAL_CMD=(x-terminal-emulator -T "SSH to $SshHost" -e "bash -c '$TUI_SCRIPT'")
        elif command -v gnome-terminal &> /dev/null; then
            TERMINAL_NAME="gnome-terminal"
            TERMINAL_CMD=(gnome-terminal --title "SSH to $SshHost" -- bash -c "$TUI_SCRIPT")
        elif command -v xfce4-terminal &> /dev/null; then
            TERMINAL_NAME="xfce4-terminal"
            TERMINAL_CMD=(xfce4-terminal -T "SSH to $SshHost" -e "bash -c '$TUI_SCRIPT'")
        fi

        if [ -n "$TERMINAL_NAME" ]; then
            show_info "Launching terminal ($TERMINAL_NAME) for interactive prompt..."
            "${TERMINAL_CMD[@]}" &
        else
            show_error "Could not find a known terminal emulator to run interactive prompts."
            exit 1
        fi
        exit 0
    fi

    if $USER_CANCELLED; then
        show_info "SSH connection cancelled by user."
        exit 0
    fi

    # --- 4. BUILD AND LAUNCH ---
    FINAL_TARGET="$SshUser@$SshHost"
    SSH_ARGS=(-A -C)
    if [ -n "$LegacyOpts" ]; then
        read -ra LEGACY_ARRAY <<< "$LegacyOpts"
        SSH_ARGS+=("${LEGACY_ARRAY[@]}")
    fi
    SSH_ARGS+=("$FINAL_TARGET")

    # Find and use a terminal emulator to launch the final ssh command
    LAUNCH_CMD=()
    TERMINAL_NAME=""
    if command -v x-terminal-emulator &> /dev/null && [ -x "$(realpath /usr/bin/x-terminal-emulator 2>/dev/null)" ]; then
        TERMINAL_NAME="x-terminal-emulator"
        LAUNCH_CMD=(x-terminal-emulator -T "SSH to $FINAL_TARGET" -e "ssh ${SSH_ARGS[*]}")
    elif command -v gnome-terminal &> /dev/null; then
        TERMINAL_NAME="gnome-terminal"
        LAUNCH_CMD=(gnome-terminal --title "SSH to $FINAL_TARGET" -- ssh "${SSH_ARGS[@]}")
    elif command -v xfce4-terminal &> /dev/null; then
        TERMINAL_NAME="xfce4-terminal"
        LAUNCH_CMD=(xfce4-terminal --title "SSH to $FINAL_TARGET" -x ssh "${SSH_ARGS[@]}")
    elif command -v xterm &> /dev/null; then
        TERMINAL_NAME="xterm"
        LAUNCH_CMD=(xterm -T "SSH to $FINAL_TARGET" -e "ssh ${SSH_ARGS[*]}")
    fi

    if [ -n "$TERMINAL_NAME" ]; then
        show_info "Connecting to $SshHost via $TERMINAL_NAME..."
        "${LAUNCH_CMD[@]}" &
    else
        show_error "Could not find a known terminal emulator to launch the SSH session."
        exit 1
    fi

    exit 0
fi

