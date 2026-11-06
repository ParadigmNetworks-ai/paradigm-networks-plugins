# Prints CONFIGURED or NOT_CONFIGURED: whether this machine has a Paradigm
# Networks login (Windows).
# Usage: check-configured.ps1
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin\).
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$arch = "amd64"
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { $arch = "arm64" }
$exe = Join-Path $root "bin\pn-plugin-windows-$arch.exe"
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
  [Console]::Error.WriteLine("error: Paradigm Networks has no build for this machine ($exe is missing).")
  exit 1
}
$env:PN_PLUGIN_ROOT = $root
& $exe check-configured --host cursor
exit $LASTEXITCODE
