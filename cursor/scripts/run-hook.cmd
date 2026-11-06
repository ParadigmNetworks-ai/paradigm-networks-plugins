:; d="$(cd "$(dirname "$0")" && pwd)"; n="$1"; shift; exec "$d/../bin/pn-plugin" hook "$n" "$@"
@echo off
rem Polyglot hook dispatcher: one hooks.json entry per event, on every
rem platform, running the hook in pn-plugin. On macOS/Linux, line 1 runs
rem bin/pn-plugin (the launcher); on Windows, the batch body below runs
rem bin\pn-plugin-windows-<arch>.exe.
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
rem equivalent on macOS/Linux.
rem
rem Ships executable in git so /bin/sh can run it as a script on
rem macOS/Linux.
setlocal
set "PN_PLUGIN_ROOT=%~dp0.."
set "PN_ARCH=amd64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "PN_ARCH=arm64"
if /I "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "PN_ARCH=arm64"
set "PN_EXE=%~dp0..\bin\pn-plugin-windows-%PN_ARCH%.exe"
if not exist "%PN_EXE%" goto missing
"%PN_EXE%" hook %~1 --host cursor %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%

rem No build for this machine: step aside rather than fail the hook.
:missing
if /I "%~1"=="check-prompt" (
  echo {"continue": true}
) else if /I "%~1"=="check-tool-call" (
  echo {"permission": "allow"}
) else (
  echo {}
)
exit /b 0
