:; d="$(cd "$(dirname "$0")" && pwd)"; n="${1-}"; case $# in 0) ;; *) shift ;; esac; exec "$d/../runtime/pn-plugin" hook "$n" "$@"
@echo off
rem Polyglot hook dispatcher: one hooks.json entry per event, on every
rem platform, running the hook in pn-plugin. On macOS/Linux, line 1 runs
rem runtime/pn-plugin (the launcher); on Windows, the batch body below runs
rem this machine's build, from the cache.
rem
rem Line 1 above is a no-op label to cmd.exe (label lines are skipped and
rem never echoed, even with ECHO ON) and a real command to /bin/sh: `exec`
rem replaces the shell process outright, so sh never reads past this line
rem into the batch body below. Cursor spawns hook commands through a shell,
rem so this single command works unmodified on both platforms without
rem Cursor needing any per-platform filtering.
rem
rem Argument contract: the caller passes a bare hook name (e.g.
rem "check-prompt"), never a path -- %~dp0 resolves this dispatcher's own
rem directory, so there is no caller-supplied path to mangle -- optionally
rem followed by extra arguments passed on verbatim. %2..%9 (not %*)
rem preserve each argument's own quoting even when the plugin's install
rem path contains a space; the sh line's "shift; ... "$@"" is the
rem equivalent on macOS/Linux, which shifts only when there is an argument:
rem with none, dash would stop at the shift before any reply.
rem
rem Ships executable in git so /bin/sh can run it as a script on
rem macOS/Linux, where runtime/pn-plugin checks the build.
setlocal
rem Windows: before every run, check the build (release/launcher-verification/
rem README.md), with built-in tools only where it can, so it works under
rem locked-down PowerShell: the plugin's version from plugin.json, its line
rem in runtime\SHA256SUMS (pn-plugin-<version>-windows-<arch>.exe), and the
rem build's SHA-256 from certutil. The plugin ships no builds: the build is
rem kept in %LOCALAPPDATA%\ParadigmNetworks\bin\<version>\. runtime\verify.ps1
rem runs only when it's needed: when there's a release signature to check
rem (runtime\SHA256SUMS.sig.p1363 is there, or PN_REQUIRE_SIGNATURE is 1) that
rem hasn't been checked yet, or the build isn't in the cache, which it then
rem downloads. Every run copies the cached build to a folder of its own in the
rem cache folder, checks the copy and runs the copy, so the cache can't change
rem between the check and the run. Every tool is called by its full path, so a
rem file of the same name in the working folder can't stand in for it.
rem
rem If the check fails, the hook fails closed: tool calls are denied unless
rem PARADIGM_NETWORKS_FAILURE_MODE is allow, and prompts follow
rem PARADIGM_NETWORKS_PROMPT_FAILURE_MODE. No goto labels: cmd can misread
rem labels in a file with LF line endings, which this one needs for line 1.
rem Messages have no parentheses, &, | or paths. Each tool writes to a
rem temporary file that for /f then reads: for /f doesn't reliably capture a
rem command's output when the command's path and arguments are quoted.

rem 1 once releases are signed by the release workflow.
set "PN_REQUIRE_SIGNATURE=1"

set "PN_PLUGIN_ROOT=%~dp0.."
set "PN_ARCH=amd64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "PN_ARCH=arm64"
if /I "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "PN_ARCH=arm64"
rem The tools come from C:\Windows\System32 when it's there, not from the
rem SystemRoot variable, which anything that sets this process's environment
rem could point elsewhere. PowerShell gets only its own modules for the same
rem reason: a module of the same name in a user folder could stand in for
rem Get-FileHash.
set "PN_SYS=C:\Windows\System32"
if not exist "%PN_SYS%\certutil.exe" set "PN_SYS=%SystemRoot%\System32"
set "PSModulePath=%PN_SYS%\WindowsPowerShell\v1.0\Modules"
set "PN_RT=%~dp0..\runtime"
set "PN_SUMS=%PN_RT%\SHA256SUMS"
set "PN_WHY="
set "PN_FIX="

rem Scratch files for the tools' output go in a folder of this run's own,
rem removed before running or replying. %RANDOM% is seeded from the clock, so
rem hooks that start in the same second, as Cursor's can, get the same
rem number. mkdir fails when the folder is already there, so each run takes
rem the first free name and no two runs share or delete each other's files.
set "PN_TMP="
set "PN_BASE=%TEMP%\pn-plugin-%RANDOM%%RANDOM%"
for /l %%i in (1,1,100) do if not defined PN_TMP mkdir "%PN_BASE%-%%i" >nul 2>&1 && set "PN_TMP=%PN_BASE%-%%i"
if not defined PN_TMP set "PN_WHY=there's no temporary folder for its checks"

rem The top-level "version" line of plugin.json: two-space indent.
set "PN_RAW=,"
if not defined PN_WHY "%PN_SYS%\findstr.exe" /B /R /C:"  .version.:" "%PN_PLUGIN_ROOT%\.cursor-plugin\plugin.json" >"%PN_TMP%\v" 2>nul
set "PN_GOT="
if not defined PN_WHY for /f "usebackq tokens=2 delims=:" %%v in ("%PN_TMP%\v") do if not defined PN_GOT set "PN_GOT=1" & set "PN_RAW=%%v"
rem A leading x keeps the variable defined while it's trimmed.
set "PN_VERSION=x%PN_RAW%"
set "PN_VERSION=%PN_VERSION:"=%"
set "PN_VERSION=%PN_VERSION:,=%"
set "PN_VERSION=%PN_VERSION: =%"
set "PN_VERSION=%PN_VERSION:~1%"
if not defined PN_WHY if "%PN_VERSION%"=="" set "PN_WHY=the plugin's version is missing"
rem It names the cache folder and the download, so it must be digits and
rem dots, X.Y.Z. "set" prints it without expanding it, so nothing in it can
rem break a line before it's checked.
if not defined PN_WHY set PN_VERSION >"%PN_TMP%\ver" 2>nul
if not defined PN_WHY "%PN_SYS%\findstr.exe" /R /X /C:"PN_VERSION=[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" "%PN_TMP%\ver" >nul 2>&1 || set "PN_WHY=the plugin's version isn't a release version"

rem The list and its signature are read once, into this run's folder: the
rem build's line, the signature marker and verify.ps1 all use these copies,
rem so neither file can change between those steps.
set "PN_WANT=none"
if not defined PN_WHY if not exist "%PN_SUMS%" set "PN_WHY=the plugin's list of builds is missing"
if not defined PN_WHY copy /b "%PN_SUMS%" "%PN_TMP%\sums" >nul 2>&1 || set "PN_WHY=the plugin's list of builds can't be read"
if not defined PN_WHY if exist "%PN_RT%\SHA256SUMS.sig.p1363" copy /b "%PN_RT%\SHA256SUMS.sig.p1363" "%PN_TMP%\sig" >nul 2>&1
if not defined PN_WHY "%PN_SYS%\findstr.exe" /L /C:"  pn-plugin-%PN_VERSION%-windows-%PN_ARCH%.exe" "%PN_TMP%\sums" >"%PN_TMP%\w" 2>nul
set "PN_GOT="
if not defined PN_WHY for /f "usebackq tokens=1" %%h in ("%PN_TMP%\w") do if not defined PN_GOT set "PN_GOT=1" & set "PN_WANT=%%h"
if not defined PN_WHY if "%PN_WANT%"=="none" set "PN_WHY=the plugin's list of builds has no build for this version and machine"

rem The cache: verify.ps1 makes these folders and checks who may change them.
if not defined PN_WHY if not defined LOCALAPPDATA set "PN_WHY=there's no home folder to keep its program in"
set "PN_HOME=%LOCALAPPDATA%\ParadigmNetworks"
set "PN_CACHE=%PN_HOME%\bin\%PN_VERSION%"
set "PN_EXE=%PN_CACHE%\pn-plugin-%PN_VERSION%-windows-%PN_ARCH%.exe"

set "PN_SIGNED="
if defined PN_TMP if exist "%PN_TMP%\sig" set "PN_SIGNED=1"
if "%PN_REQUIRE_SIGNATURE%"=="1" set "PN_SIGNED=1"
rem The signature is checked once for each exact list, signature and checker,
rem not on every hook: a marker in %LOCALAPPDATA%\ParadigmNetworks\verified
rem says they passed. It's named after the SHA-256 of the three files one
rem after the other, then the list's and the signature's sizes, so no other
rem three files can share the name by moving bytes from one to the next.
rem Changing any of them changes the name, so they're checked again. The
rem build's own hash is still checked on every run, below.
set "PN_MARKS=%PN_HOME%\verified"
set "PN_MARK="
set "PN_CACHED="
set "PN_LEN1="
set "PN_LEN2="
if not defined PN_WHY if defined PN_SIGNED if exist "%PN_TMP%\sig" copy /b "%PN_TMP%\sums"+"%PN_TMP%\sig"+"%PN_RT%\verify.ps1" "%PN_TMP%\s" >nul 2>&1 && "%PN_SYS%\certutil.exe" -hashfile "%PN_TMP%\s" SHA256 >"%PN_TMP%\m" 2>nul
set "PN_GOT="
if defined PN_TMP if exist "%PN_TMP%\m" for /f "usebackq skip=1 delims=" %%h in ("%PN_TMP%\m") do if not defined PN_GOT set "PN_GOT=1" & set "PN_MARK=x%%h"
if defined PN_MARK for %%f in ("%PN_TMP%\sums") do set "PN_LEN1=%%~zf"
if defined PN_MARK for %%f in ("%PN_TMP%\sig") do set "PN_LEN2=%%~zf"
if defined PN_MARK set "PN_MARK=%PN_MARK: =%"
if defined PN_MARK set "PN_MARK=%PN_MARK:~1%-%PN_LEN1%-%PN_LEN2%"
if not defined PN_LEN1 set "PN_MARK="
if not defined PN_LEN2 set "PN_MARK="
if defined PN_MARK if exist "%PN_MARKS%\%PN_MARK%" set "PN_CACHED=1"

rem verify.ps1 runs for a signature not checked yet, or a build to download.
set "PN_PS="
if defined PN_SIGNED if not defined PN_CACHED set "PN_PS=1"
if not exist "%PN_EXE%" set "PN_PS=1"
rem stdin stays for pn-plugin: it carries the hook's payload. verify.ps1
rem checks this run's copies of the list and signature, downloads the build
rem when it isn't there, and exits 2 for a bad or missing signature, 3 when
rem PowerShell is locked down, 4 when the build couldn't be downloaded, 5
rem when the cache folder isn't safe to use and 6 when the build doesn't
rem match the list.
set "PN_RC=0"
if not defined PN_WHY if defined PN_PS "%PN_SYS%\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PN_RT%\verify.ps1" -Arch %PN_ARCH% -SumsFile "%PN_TMP%\sums" -SignatureFile "%PN_TMP%\sig" <nul >nul 2>&1
if not defined PN_WHY if defined PN_PS set "PN_RC=%ERRORLEVEL%"
if "%PN_RC%"=="2" set "PN_WHY=the release signature is missing or doesn't match"
if "%PN_RC%"=="3" set "PN_WHY=a Windows security policy blocks the plugin's signature check. Ask your administrator to allow the Paradigm Networks plugin's PowerShell script"
if "%PN_RC%"=="4" set "PN_WHY=its program couldn't be downloaded" & set "PN_FIX=Check that this machine can reach github.com, then try again, or ask your administrator."
if "%PN_RC%"=="5" set "PN_WHY=its folder for the program, ParadigmNetworks in your local app data, is a link, isn't yours or can be changed by other users" & set "PN_FIX=Remove that folder, it's downloaded again, or ask your administrator."
if "%PN_RC%"=="6" set "PN_WHY=the downloaded program doesn't match the plugin's list of builds"
if not "%PN_RC%"=="0" if not defined PN_WHY set "PN_WHY=the plugin's signature check failed or couldn't run, which can happen when PowerShell is blocked"
if "%PN_RC%"=="0" if not defined PN_WHY if defined PN_SIGNED if not defined PN_CACHED if defined PN_MARK mkdir "%PN_MARKS%" >nul 2>&1 & type nul >"%PN_MARKS%\%PN_MARK%" 2>nul

rem The cache folders must be real folders, not links or junctions (an "l"
rem in their attributes), on every run; verify.ps1 checks who may change
rem them when it makes them.
set "PN_A=x"
if not defined PN_WHY for %%a in ("%PN_HOME%") do set "PN_A=%PN_A%%%~aa"
if not defined PN_WHY for %%a in ("%PN_HOME%\bin") do set "PN_A=%PN_A%%%~aa"
if not defined PN_WHY for %%a in ("%PN_CACHE%") do set "PN_A=%PN_A%%%~aa"
if not defined PN_WHY if not "%PN_A:l=%"=="%PN_A%" set "PN_WHY=its folder for the program, ParadigmNetworks in your local app data, is a link" & set "PN_FIX=Remove that folder, it's downloaded again, or ask your administrator."

rem Remove earlier runs' folders, on every run: a run's folder is removed
rem when it ends, but not while pn-plugin's background runs (the login
rem waiting for the browser) still use its copy, since Windows can't remove a
rem program that's running. forfiles only knows dates: /d -2 picks folders
rem last changed two days ago or before, so at least a day old, and one still
rem in use stays. verify.ps1 and runtime/pn-plugin remove the rest of what
rem runs leave behind.
if not defined PN_WHY "%PN_SYS%\forfiles.exe" /p "%PN_CACHE%" /m run-* /d -2 /c "%PN_SYS%\cmd.exe /d /c if @isdir==TRUE rd /s /q @path" >nul 2>&1

rem Run a copy of its own, checked: the cached build could change after any
rem check of it, the copy can't. Its folder is this run's own, like PN_TMP.
set "PN_RUN="
set "PN_RUNBASE=%PN_CACHE%\run-%RANDOM%%RANDOM%"
if not defined PN_WHY if not exist "%PN_EXE%" set "PN_WHY=the program for this machine is missing"
if not defined PN_WHY for /l %%i in (1,1,100) do if not defined PN_RUN mkdir "%PN_RUNBASE%-%%i" >nul 2>&1 && set "PN_RUN=%PN_RUNBASE%-%%i"
if not defined PN_WHY if not defined PN_RUN set "PN_WHY=its program can't be copied to run"
if not defined PN_WHY copy /b "%PN_EXE%" "%PN_RUN%\pn-plugin.exe" >nul 2>&1 || set "PN_WHY=its program can't be copied to run"

rem certutil prints a heading, the hash, then a status line. "if not
rem defined" is checked on each pass, so only the first line counts.
set "PN_HAVE=none"
if not defined PN_WHY "%PN_SYS%\certutil.exe" -hashfile "%PN_RUN%\pn-plugin.exe" SHA256 >"%PN_TMP%\h" 2>nul
set "PN_GOT="
if not defined PN_WHY for /f "usebackq skip=1 delims=" %%h in ("%PN_TMP%\h") do if not defined PN_GOT set "PN_GOT=1" & set "PN_HAVE=%%h"
set "PN_HAVE=x%PN_HAVE: =%"
set "PN_HAVE=%PN_HAVE:~1%"
rem A changed build is downloaded again next time.
if not defined PN_WHY if /I not "%PN_HAVE%"=="%PN_WANT%" del /f /q "%PN_EXE%" >nul 2>&1 & set "PN_WHY=the program doesn't match the plugin's list of builds"
if defined PN_TMP rd /s /q "%PN_TMP%" >nul 2>&1

rem Not "& exit /b": the copy is removed once it's done. pn-plugin's
rem background runs have started from it by then, and a copy that's still
rem running can't be removed: a later run removes it (above).
if not defined PN_WHY "%PN_RUN%\pn-plugin.exe" hook "%~1" --host cursor %2 %3 %4 %5 %6 %7 %8 %9
if not defined PN_WHY set "PN_RC=%ERRORLEVEL%"
if defined PN_RUN rd /s /q "%PN_RUN%" >nul 2>&1
if not defined PN_WHY exit /b %PN_RC%

rem The check failed. Read the payload so the agent isn't left writing to a
rem closed pipe, then reply in Cursor's format.
"%PN_SYS%\findstr.exe" "^" >nul 2>&1
set "PN_WHAT=Paradigm Networks couldn't check its program on this machine: %PN_WHY%"
if not defined PN_FIX set "PN_FIX=Reinstall the Paradigm Networks plugin, or ask your administrator."
set "PN_TOOLS=deny"
if /I "%PARADIGM_NETWORKS_FAILURE_MODE%"=="allow" set "PN_TOOLS=allow"
if /I "%PARADIGM_NETWORKS_FAILURE_MODE%"=="open" set "PN_TOOLS=allow"
set "PN_PROMPTS=allow"
if /I "%PARADIGM_NETWORKS_PROMPT_FAILURE_MODE%"=="block" set "PN_PROMPTS=deny"
if /I "%PARADIGM_NETWORKS_PROMPT_FAILURE_MODE%"=="closed" set "PN_PROMPTS=deny"
set "PN_HOOK=other"
if /I "%~1"=="check-tool-call" set "PN_HOOK=tool"
if /I "%~1"=="tool-call" set "PN_HOOK=tool"
if /I "%~1"=="check-prompt" set "PN_HOOK=prompt"
if /I "%~1"=="prompt" set "PN_HOOK=prompt"
if /I "%~1"=="check-session" set "PN_HOOK=session"
if /I "%~1"=="session-start" set "PN_HOOK=session"
if "%PN_HOOK%-%PN_TOOLS%"=="tool-deny" echo {"permission": "deny", "user_message": "%PN_WHAT%. Tool calls are blocked until this is fixed. %PN_FIX%", "agent_message": "%PN_WHAT%. Tool calls are blocked until this is fixed. Tell the user: %PN_FIX%"}& exit /b 0
if "%PN_HOOK%-%PN_TOOLS%"=="tool-allow" echo {"permission": "allow", "user_message": "%PN_WHAT%. This tool call was allowed without a policy check."}& exit /b 0
if "%PN_HOOK%-%PN_PROMPTS%"=="prompt-deny" echo {"continue": false, "user_message": "%PN_WHAT%. %PN_FIX%"}& exit /b 0
if "%PN_HOOK%-%PN_PROMPTS%"=="prompt-allow" echo {"continue": true, "user_message": "%PN_WHAT%, so this prompt was not checked. %PN_FIX%"}& exit /b 0
rem Cursor's session start takes only context, which always ends with the
rem scripts directory: the login and logout skills read it. Backslashes are
rem escaped for JSON; delayed expansion puts the path in after the line is
rem read, so an ampersand or parenthesis in it can't break the line.
set "PN_SCRIPTS=%~dp0"
set "PN_SCRIPTS=%PN_SCRIPTS:~0,-1%"
set "PN_SCRIPTS=%PN_SCRIPTS:\=\\%"
setlocal EnableDelayedExpansion
if "%PN_HOOK%-%PN_TOOLS%"=="session-deny" echo {"additional_context": "!PN_WHAT!. Tool calls are blocked until this is fixed. !PN_FIX!\n\nParadigm Networks plugin scripts directory: !PN_SCRIPTS!"}& exit /b 0
if "%PN_HOOK%-%PN_TOOLS%"=="session-allow" echo {"additional_context": "!PN_WHAT!, so tool calls are NOT checked against your organization's policy. !PN_FIX!\n\nParadigm Networks plugin scripts directory: !PN_SCRIPTS!"}& exit /b 0
echo {}
exit /b 0
