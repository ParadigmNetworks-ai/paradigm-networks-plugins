# Logs this machine in to Paradigm Networks with a browser login (Windows).
# Usage: login.ps1 -BaseUrl https://acme.paradigmnetworks.ai
#
# The login and logout skills, and the plugin's own messages to the agent,
# run this script by this path; the work is done by pn-plugin (bin\).
param(
  [Parameter(Mandatory = $true)][string]$BaseUrl
)
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
& $exe login --host cursor --base-url $BaseUrl
exit $LASTEXITCODE
