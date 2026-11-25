# Checks this machine's pn-plugin build on Windows, the same check
# runtime/pn-plugin does on macOS and Linux (release/launcher-verification/
# README.md), and downloads the build when it isn't there yet. The
# scripts/*.ps1 run it with -Copy and run the copy it prints;
# scripts/run-hook.cmd runs it when there's a release signature to check or
# the build has to be downloaded, and does the rest itself.
#
# Usage: verify.ps1 -Arch amd64|arm64 [-SumsFile <path>] [-SignatureFile <path>] [-Copy]
# -SumsFile and -SignatureFile name copies of runtime\SHA256SUMS and
# runtime\SHA256SUMS.sig.p1363 to check instead: run-hook.cmd reads each file
# once and passes its copies, so this checks the same bytes it did.
# -Copy: also copy the build to a file of its own in the cache folder, check
# the copy and print its path; the caller runs it, then removes it.
# Exit 0 when the build checks out. Otherwise the reason is on stderr and the
# exit code says which kind, for run-hook.cmd's message: 2, the release
# signature is missing or doesn't match; 3, PowerShell is locked down
# (Constrained Language Mode, from WDAC or AppLocker) so the signature can't be
# checked; 4, the build couldn't be downloaded; 5, the cache folder isn't
# safe to use; 6, the build doesn't match its line in the list; 1, anything
# else.
#
#   - runtime\SHA256SUMS lists every build as pn-plugin-<version>-<os>-<arch>.
#     The build must match the line for this plugin's version (plugin.json).
#   - runtime\SHA256SUMS.sig.p1363 is the release signature over SHA256SUMS,
#     in the format .NET reads. When it's there, or $RequireSignature is set,
#     it must verify with one of the public keys below. That part needs
#     .NET Framework 4.7 or later and full PowerShell (not Constrained
#     Language Mode); the rest uses cmdlets only.
#   - The build is kept in %LOCALAPPDATA%\ParadigmNetworks\bin\<version>\, a
#     folder only the user (and SYSTEM and Administrators) can change. When
#     it isn't there, it's downloaded from the GitHub Release of this version
#     ($ReleaseUrl, fixed below) with Windows' own curl.exe, and kept only if
#     it matches its line.
param(
  [Parameter(Mandatory = $true)][ValidateSet("amd64", "arm64")][string]$Arch,
  [string]$SumsFile = "",
  [string]$SignatureFile = "",
  [switch]$Copy
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# Load cmdlets only from PowerShell's own modules: a module of the same name in
# a user folder could stand in for Get-FileHash.
$env:PSModulePath = Join-Path $PSHOME "Modules"

# $true once releases are signed by the release workflow. Keep in step with
# PN_REQUIRE_SIGNATURE in scripts/run-hook.cmd and require_signature in
# runtime/pn-plugin; the launcher tests check they match.
$RequireSignature = $true

# Where the builds are downloaded from: <ReleaseUrl>/v<version>/<build>, which
# GitHub redirects to its release file host, one of AssetHosts (https, no
# port, no other host). Fixed, as in runtime/pn-plugin: nothing the user, a
# project or the agent sets can change them. The launcher tests replace these
# lines.
$ReleaseUrl = "https://github.com/ParadigmNetworks-ai/paradigm-networks-plugins/releases/download"
$AssetHosts = @("release-assets.githubusercontent.com", "objects.githubusercontent.com")
# The largest build that's accepted, in bytes (the builds are about 8 MB).
$MaxSize = 67108864

# Release signing public keys (P-256, the X and Y of the uncompressed point):
# the current key and, during a key change, the next one. Keep in step with
# runtime/pn-plugin in both plugins; the launcher tests check they match.
# BEGIN pn-release-signing keys
$ReleaseKeys = @(
  @{ X = "04efa2e5bedb783281e948fc9eb6a3c44bc12a31a10ee406c29ad18bd21625ce"; Y = "788c4931b112333f990b40ef585fa8e958dbcf4212a80d539adef6204aeaa51e" }
)
# END pn-release-signing keys

$Reinstall = "Reinstall the Paradigm Networks plugin, or ask your administrator."
$NoDownload = "Check that this machine can reach github.com, then try again, or ask your administrator."
$Unsafe = "its folder for the program, %LOCALAPPDATA%\ParadigmNetworks, is a link, isn't yours or can be changed by other users"
$UnsafeFix = "Remove the folder (it's downloaded again), or ask your administrator."
$script:Lock = $null
$script:Part = $null
# Anything unexpected fails closed too, and leaves no lock or partial file.
trap {
  if ($script:Part) { Remove-Item -LiteralPath $script:Part -Force -ErrorAction SilentlyContinue }
  if ($script:Lock) { Remove-Item -LiteralPath $script:Lock -Recurse -Force -ErrorAction SilentlyContinue }
  [Console]::Error.WriteLine("error: Paradigm Networks couldn't check its program on this machine: $_. $Reinstall")
  exit 1
}

function Fail([string]$Reason, [int]$Code = 1, [string]$Fix = $Reinstall) {
  if ($script:Part) { Remove-Item -LiteralPath $script:Part -Force -ErrorAction SilentlyContinue }
  if ($script:Lock) { Remove-Item -LiteralPath $script:Lock -Recurse -Force -ErrorAction SilentlyContinue }
  [Console]::Error.WriteLine("error: Paradigm Networks couldn't check its program on this machine: $Reason. $Fix")
  exit $Code
}

function HexBytes([string]$Hex) {
  $b = New-Object byte[] ($Hex.Length / 2)
  for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
  return , $b
}

function Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$root = Split-Path -Parent $PSScriptRoot
$rt = Join-Path $root "runtime"
$sums = Join-Path $rt "SHA256SUMS"
$sig = Join-Path $rt "SHA256SUMS.sig.p1363"
if ($SumsFile) { $sums = $SumsFile }
if ($SignatureFile) { $sig = $SignatureFile }
# PowerShell 7 on macOS or Linux (where the launcher tests also run this) has
# no Windows owners or curl.exe. (Windows PowerShell 5.1 has no $IsWindows.)
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

try {
  $version = (Get-Content -LiteralPath (Join-Path $root ".cursor-plugin\plugin.json") -Raw | ConvertFrom-Json).version
} catch {
  Fail "the plugin's version is missing"
}
if (-not $version) { Fail "the plugin's version is missing" }
# It names the cache folder and the download.
if ("$version" -cnotmatch "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$") { Fail "the plugin's version isn't a release version" }
if (-not (Test-Path -LiteralPath $sums -PathType Leaf)) { Fail "the plugin's list of builds is missing" }
$name = "pn-plugin-$version-windows-$Arch.exe"
$want = $null
foreach ($line in (Get-Content -LiteralPath $sums)) {
  $f = $line.TrimEnd() -split "\s+", 2
  if ($f.Count -eq 2 -and ($f[1] -ceq $name -or $f[1] -ceq "*$name") -and $f[0] -match "^[0-9a-f]{64}$") { $want = $f[0]; break }
}
if (-not $want) { Fail "the plugin's list of builds has no build for this version and machine" }

if ((Test-Path -LiteralPath $sig -PathType Leaf) -or $RequireSignature) {
  if (-not (Test-Path -LiteralPath $sig -PathType Leaf)) { Fail "the plugin's release signature is missing" 2 }
  # Locked-down PowerShell can't use the .NET crypto classes below. Say so
  # plainly (with what works in that mode), so IT knows what to allow.
  if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    # Write-Error, not [Console]: only cmdlets work in this mode.
    Write-Error -ErrorAction Continue "error: Paradigm Networks couldn't check its program on this machine: a Windows security policy blocks the plugin's signature check. Ask your administrator to allow the Paradigm Networks plugin's PowerShell script."
    exit 3
  }
  $signed = $false
  try {
    $data = [IO.File]::ReadAllBytes($sums)
    $signature = [IO.File]::ReadAllBytes($sig)
    foreach ($k in $ReleaseKeys) {
      $p = New-Object Security.Cryptography.ECParameters
      $p.Curve = [Security.Cryptography.ECCurve+NamedCurves]::nistP256
      $point = New-Object Security.Cryptography.ECPoint
      $point.X = HexBytes $k.X
      $point.Y = HexBytes $k.Y
      $p.Q = $point
      $ec = [Security.Cryptography.ECDsa]::Create()
      $ec.ImportParameters($p)
      if ($signature.Length -eq 64 -and $ec.VerifyData($data, $signature, [Security.Cryptography.HashAlgorithmName]::SHA256)) { $signed = $true; break }
    }
  } catch {
    Fail "the release signature can't be checked on this machine (it needs .NET Framework 4.7 or later and full PowerShell)"
  }
  if (-not $signed) { Fail "the release signature doesn't match" 2 }
}

# ─── the cache ────────────────────────────────────────────────────────────────
if (-not $env:LOCALAPPDATA) { Fail "there's no home folder to keep its program in" 1 "Start Cursor with LOCALAPPDATA set, or ask your administrator." }
$base = Join-Path $env:LOCALAPPDATA "ParadigmNetworks"
$binDir = Join-Path $base "bin"
$cache = Join-Path $binDir $version
$exe = Join-Path $cache $name

# Who may change the cache folder besides the user: SYSTEM and Administrators
# (the folders under LOCALAPPDATA allow them by default).
$trusted = @("S-1-5-18", "S-1-5-32-544")

# OwnDir: makes the folder when it isn't there, and checks it's a real folder
# (no link or junction), owned by the user, SYSTEM or Administrators, that
# nobody else may change.
function OwnDir([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) {
    try { New-Item -ItemType Directory -Path $Dir -ErrorAction Stop | Out-Null } catch { if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { Fail "its folder for the program can't be made" 5 $UnsafeFix } }
  }
  $item = Get-Item -LiteralPath $Dir -Force
  if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Fail $Unsafe 5 $UnsafeFix }
  if (-not $onWindows) { return }
  $bad = $false
  try {
    $writeRights = [Security.AccessControl.FileSystemRights]"Write, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership"
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $acl = Get-Acl -LiteralPath $Dir
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -ne $me -and $trusted -notcontains $owner) { $bad = $true }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      if ($rule.AccessControlType -ne "Allow" -or -not ($rule.FileSystemRights -band $writeRights)) { continue }
      $who = $rule.IdentityReference.Value
      # CREATOR OWNER applies only to what the owner creates.
      if ($who -ne $me -and $who -ne "S-1-3-0" -and $trusted -notcontains $who) { $bad = $true }
    }
  } catch {
    Fail "its folder for the program can't be checked" 5 $UnsafeFix
  }
  if ($bad) { Fail $Unsafe 5 $UnsafeFix }
}
OwnDir $base
OwnDir $binDir
OwnDir $cache

# Tidy: removes what earlier runs left behind, on every run (these
# scripts', run-hook.cmd's and runtime/pn-plugin's, Claude Code on Windows,
# which share the folder): partial downloads and run copies an hour old. A
# copy that pn-plugin's background runs (the login waiting for the browser)
# still use can't be removed, and a later run tries again.
function Tidy {
  $old = (Get-Date).AddMinutes(-60)
  foreach ($f in (Get-ChildItem -LiteralPath $cache -Force -ErrorAction SilentlyContinue)) {
    if (($f.Name -like "download-*" -or $f.Name -like "run-*" -or $f.Name -like ".download.*" -or $f.Name -like ".run.*") -and $f.LastWriteTime -lt $old) {
      Remove-Item -LiteralPath $f.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

# Prune: removes older versions' builds once nothing has run them for 30
# days, under the download lock. Another plugin or an open session may still
# be on an older version (and a machine without network may only have what
# was put in its cache): every run copies its build into its version's
# folder, which changes the folder's time, so a version in use is never
# removed. A newer version's folder is always kept.
function Prune {
  $unused = (Get-Date).AddDays(-30)
  foreach ($d in (Get-ChildItem -LiteralPath $binDir -Force -ErrorAction SilentlyContinue)) {
    if ($d.FullName -eq $cache) { continue }
    if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue; continue }
    if ($d.PSIsContainer -and $d.Name -match "^[0-9]+\.[0-9]+\.[0-9]+$" -and [version]$d.Name -lt [version]"$version" -and $d.LastWriteTime -lt $unused) {
      Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

# Download: fetches this machine's build into the cache, once: one run
# downloads at a time (the lock), and the others wait for it.
function Download {
  $lock = Join-Path $cache ".lock"
  $waited = 0
  while ($true) {
    $made = $false
    try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null; $made = $true } catch {}
    if ($made) { break }
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return }
    # A lock left by a run that was killed: no download holds it this long.
    $l = Get-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
    if ($l -and $l.LastWriteTime -lt (Get-Date).AddMinutes(-4)) { Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue; continue }
    # As long as a download may take (30s + 180s, below), within the 250s
    # Cursor gives the hooks that block.
    if ($waited -ge 215) { Fail "another download of its program hasn't finished" 4 "Try again in a minute, or ask your administrator." }
    Start-Sleep -Seconds 1
    $waited++
  }
  $script:Lock = $lock
  if (Test-Path -LiteralPath $exe -PathType Leaf) { Remove-Item -LiteralPath $lock -Recurse -Force; $script:Lock = $null; return }

  # Windows' own curl, not one from PATH (Windows PowerShell 5.1's web
  # cmdlets have TLS and locked-down mode problems). -q: no .curlrc;
  # HTTPS_PROXY and the like still apply. Revocation is checked where it can
  # be: a proxy that inspects TLS often has no revocation list, and the
  # signed list decides what runs anyway.
  $curl = "curl"
  $null_out = "/dev/null"
  if ($onWindows) {
    $null_out = "NUL"
    $curl = "C:\Windows\System32\curl.exe"
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { $curl = Join-Path ([Environment]::SystemDirectory) "curl.exe" }
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { Fail "Windows' curl.exe isn't installed, and it's needed to download its program" 4 "Update Windows, or ask your administrator." }
  }
  # -s and no -S: curl writes nothing to stderr, which Windows PowerShell 5.1
  # would turn into an error; its exit code says what went wrong.
  $ErrorActionPreference = "Continue"
  $opts = @("-q", "-s", "--proto", "=https", "--tlsv1.2", "--ssl-revoke-best-effort", "--connect-timeout", "15", "--max-redirs", "0")
  # GitHub answers with a redirect to its file host, which is checked before
  # anything is fetched from it.
  $answer = & $curl @opts --max-time 30 -o $null_out -w "%{http_code} %{redirect_url}" "$ReleaseUrl/v$version/$name" 2>$null
  $code, $to = "$answer" -split " ", 2
  if ($code -eq "404") { Fail "this version's program isn't on GitHub" 4 "Update the Paradigm Networks plugin, or ask your administrator." }
  if (@("301", "302", "303", "307", "308") -notcontains $code -or -not $to) { Fail "its program couldn't be downloaded" 4 $NoDownload }
  $ok = $false
  foreach ($h in $AssetHosts) { if ($to.StartsWith("https://$h/", [StringComparison]::Ordinal)) { $ok = $true } }
  if (-not $ok) { Fail "its download was sent to an address that isn't GitHub's" 4 }
  # No leading dot in these names: PowerShell 7 on macOS and Linux, where the
  # launcher tests run this, treats such a file as hidden.
  $script:Part = Join-Path $cache "download-$PID"
  & $curl @opts -f --max-time 180 --max-filesize $MaxSize -o $script:Part $to 2>$null
  # 63: larger than --max-filesize (curl stops as soon as it knows).
  if ($LASTEXITCODE -eq 63) { Fail "its download is larger than any build" 4 }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $script:Part -PathType Leaf)) { Fail "its program couldn't be downloaded" 4 $NoDownload }
  if ((Get-Item -LiteralPath $script:Part -Force).Length -gt $MaxSize) { Fail "its download is larger than any build" 4 }
  if ((Sha256 $script:Part) -ne $want) { Fail "the downloaded program doesn't match the plugin's list of builds" 6 }
  try { Move-Item -LiteralPath $script:Part -Destination $exe -Force } catch { Fail "its program couldn't be saved" 5 $UnsafeFix }
  $script:Part = $null
  Prune
  Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue
  $script:Lock = $null
}

Tidy
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { Download }
if (-not $Copy) {
  if ((Sha256 $exe) -ne $want) {
    # Downloaded again next time.
    Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
    Fail "the program doesn't match the plugin's list of builds" 6
  }
  exit 0
}
# A copy of its own, checked: the cached build could change after any check
# of it, the copy can't (only this run knows its name).
$run = Join-Path $cache ("run-" + [Guid]::NewGuid().ToString("N") + ".exe")
try { Copy-Item -LiteralPath $exe -Destination $run } catch { Fail "its program can't be copied to run" 5 $UnsafeFix }
if ((Sha256 $run) -ne $want) {
  Remove-Item -LiteralPath $run, $exe -Force -ErrorAction SilentlyContinue
  Fail "the program doesn't match the plugin's list of builds" 6
}
Write-Output $run
exit 0
