# Prints CONFIGURED or NOT_CONFIGURED: whether this machine has a Paradigm
# Networks login (Windows).
# Usage: check-configured.ps1
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (runtime\).
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$arch = "amd64"
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { $arch = "arm64" }
# Check the build first (runtime\verify.ps1, which downloads it when it isn't
# there yet) and get a checked copy of its own to run. Anything but an
# explicit exit 0 and a copy from it, including it being missing or blocked,
# stops here.
$global:LASTEXITCODE = 1
$run = $null
try { $run = & (Join-Path $root "runtime\verify.ps1") -Arch $arch -Copy } catch { [Console]::Error.WriteLine("error: Paradigm Networks couldn't check its program on this machine. Reinstall the Paradigm Networks plugin, or ask your administrator.") }
if ($LASTEXITCODE -ne 0 -or -not ($run -is [string]) -or -not (Test-Path -LiteralPath $run -PathType Leaf)) { exit 1 }
$env:PN_PLUGIN_ROOT = $root
$code = 1
try {
  & $run check-configured --host cursor
  $code = $LASTEXITCODE
} finally {
  # A background login is still running from it: removed later instead.
  Remove-Item -LiteralPath $run -Force -ErrorAction SilentlyContinue
}
exit $code
