@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM ============================================================================
REM == Simple SSH Link Protocol Handler for Windows                           ==
REM == Uses the built-in Windows OpenSSH client.                            ==
REM == Includes self-installing registry setup.                             ==
REM == To install, right-click and "Run as administrator".                    ==
REM ==                                                                        ==
REM == Public Domain. https://tcpip.wtf (Modified from original)              ==
REM ============================================================================


REM --- SCRIPT MODE DETECTION ---
REM If no arguments are passed, switch to setup mode.
IF "%~1"=="" GOTO :SETUP_MODE

REM If arguments are passed, switch to connection/handler mode.
GOTO :HANDLER_MODE


REM ============================================================================
REM == SETUP MODE                                                             ==
REM ============================================================================
:SETUP_MODE
    echo.
    echo [ SETUP MODE ]
    echo This script will register itself as a system-wide handler for ssh:// URLs.
    echo It will use the Windows built-in OpenSSH client (ssh.exe).
    echo.

    REM --- 1. ADMINISTRATOR CHECK ---
    net session >nul 2>&1
    IF %errorlevel% NEQ 0 (
        echo ERROR: Administrator privileges are required for setup.
        echo Please right-click this script and select 'Run as administrator'.
        echo.
        pause
        GOTO :EOF
    )
    echo [+] Administrator privileges confirmed.

    REM --- 2. FIND ssh.exe ---
    SET "SshExePath=%SystemRoot%\System32\OpenSSH\ssh.exe"
    IF NOT EXIST "!SshExePath!" (
        echo.
        echo ERROR: Windows OpenSSH client could not be found at:
        echo !SshExePath!
        echo Please ensure the "OpenSSH Client" optional feature is installed.
        echo.
        pause
        GOTO :EOF
    )
    echo [+] Found ssh.exe at: !SshExePath!

    REM --- 3. GET SCRIPT'S OWN PATH ---
    SET "ScriptPath=%~f0"
    echo [+] This script's path is: !ScriptPath!
    echo.

    REM --- 4. USER CONFIRMATION ---
    echo This will add the following registry entries:
    echo   - Associate ssh:// protocol with a custom handler.
    echo   - Set this script (!ScriptPath!) as the command to run.
    echo   - Set the application icon to the Windows ssh.exe icon.
    echo.
    SET /P "CHOICE=Do you want to apply these registry changes? (Y/N): "
    IF /I NOT "%CHOICE%"=="Y" (
        echo Setup cancelled by user.
        GOTO :EOF
    )

    REM --- 5. APPLY REGISTRY CHANGES ---
    echo.
    echo Applying registry changes...

    REG ADD "HKCR\ssh" /ve /t REG_SZ /d "URL: ssh Protocol" /f >nul
    REG ADD "HKCR\ssh" /v "URL Protocol" /t REG_SZ /d "" /f >nul
    REG ADD "HKCR\ssh_custom_handler\shell\open\command" /ve /t REG_SZ /d "\"!ScriptPath!\" \"%%1\"" /f >nul
    REG ADD "HKLM\SOFTWARE\RegisteredApplications" /v "OpenSSH URL Handler" /t REG_SZ /d "Software\Classes\ssh_custom_handler\Capabilities" /f >nul
    REG ADD "HKCR\ssh_custom_handler\Capabilities\UrlAssociations" /v "ssh" /t REG_SZ /d "ssh_custom_handler" /f >nul
    REG ADD "HKCR\ssh_custom_handler\Application" /v "ApplicationIcon" /t REG_SZ /d "\"!SshExePath!\"" /f >nul
    REG ADD "HKCR\ssh_custom_handler\Application" /v "ApplicationName" /t REG_SZ /d "OpenSSH URL Handler" /f >nul
    REG ADD "HKCR\ssh_custom_handler\Application" /v "ApplicationDescription" /d "Handles ssh:// links via Windows OpenSSH" /f >nul
    REG ADD "HKCR\ssh_custom_handler\Application" /v "ApplicationCompany" /t REG_SZ /d "Microsoft" /f >nul

    echo.
    echo [+] SUCCESS: Registry values have been added.
    echo Your system is now configured to open ssh:// links with this script.
    echo.
    pause
    GOTO :EOF


REM ============================================================================
REM == HANDLER MODE                                                           ==
REM ============================================================================
:HANDLER_MODE
    rem // Clear previous variables to be safe
    SET "SshUser="
    SET "SshHost="
    SET "FinalTarget="
    SET "LegacyOpts="

    rem // removing ssh:// from the input argument (%1)
    SET "TARGETHOST=%~1"
    SET "T2=!TARGETHOST:~6!"
    
    rem // If the hostname ends with a slash, remove it.
    IF "!T2:~-1!"=="/" SET "T2=!T2:~0,-1!"
    
    rem // Parse the target string into user and host
    echo !T2! | find "@" >nul
    IF !errorlevel! EQU 0 (
        rem // Found '@', so URL is in user@host format
        for /f "tokens=1,2 delims=@" %%a in ("!T2!") do (
            SET "SshUser=%%a"
            SET "SshHost=%%b"
        )
    ) ELSE (
        rem // No '@' found, so use the current Windows username as the default
        SET "SshUser=%USERNAME%"
        SET "SshHost=!T2!"
    )

    rem // Prompt user to modify the username
    cls
    echo.
    echo  Host: !SshHost!
    echo  User: !SshUser!
    echo.
    SET /P "CHOICE=Change username? (y/N): "

    IF /I "%CHOICE%"=="Y" (
        echo.
        SET /P "NewUser=Enter new username: "
        rem // Only change the username if the user actually entered something
        IF DEFINED NewUser SET "SshUser=!NewUser!"
    )
    
    REM --- ADDED SECTION FOR LEGACY MODE ---
    echo.
    SET /P "LEGACY_CHOICE=Enable legacy mode for old devices? (y/N): "
    IF /I "!LEGACY_CHOICE!"=="Y" (
        SET "LegacyOpts=-o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o MACs=+hmac-sha1,hmac-sha1-96 -o ciphers=+aes256-cbc"
        echo.
        echo [!] Legacy mode enabled. Insecure algorithms will be offered.
    )
    REM --- END ADDED SECTION ---

    rem // Reconstruct the final connection string
    SET "FinalTarget=!SshUser!@!SshHost!"
    
    rem // Execute the connection
    echo.
    echo Connecting to: !FinalTarget!
    
    rem --- EXECUTION LINE ---
    start "SSH to !FinalTarget!" ssh.exe -A -C !LegacyOpts! !FinalTarget!
    
    GOTO :EOF
