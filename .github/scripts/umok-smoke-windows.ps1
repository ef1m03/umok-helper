# UMOK Helper: Windows smoke test (CI only).
# Runs the built app in several ways, collects exit codes, process lists, screenshots and
# the app logs into $Out. A control run of the official upstream RustDesk exe is done the
# same way when -ControlExe is given.
param(
  [Parameter(Mandatory = $true)][string]$Unpacked,   # dir with UMOK-Helper.exe + dlls
  [Parameter(Mandatory = $true)][string]$Packed,     # dir with UMOK-Helper.exe / UMOK-Helper-install.exe
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$ControlExe = ""
)
$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$summary = Join-Path $Out "summary.txt"
function Say($m) { $m | Tee-Object -FilePath $summary -Append }
$script:failed = $false
function Check($what, $ok) { if ($ok) { Say "CHECK OK   : $what" } else { Say "CHECK FAIL : $what"; $script:failed = $true } }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
function Shot($name) {
  try {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $Out "$name.png"))
    $g.Dispose(); $bmp.Dispose()
  } catch { Say "screenshot $name failed: $_" }
}
function Procs($tag) {
  $p = Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(UMOK-Helper|rustdesk)' } |
    Select-Object ProcessId, Name, CommandLine | Format-Table -AutoSize -Wrap | Out-String -Width 400
  Say "--- processes after ${tag}:`n$p"
}
function KillAll {
  Get-Process | Where-Object { $_.Name -match '^(UMOK-Helper|rustdesk)' } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}
function RunFor($tag, $exe, $argList, $seconds) {
  Say "=== $tag : $exe $argList"
  $sp = @{ FilePath = $exe; PassThru = $true }
  if ($argList) { $sp.ArgumentList = $argList }
  $p = Start-Process @sp
  Start-Sleep -Seconds $seconds
  if ($p.HasExited) { Say "$tag : launcher exited, code $($p.ExitCode)" } else { Say "$tag : launcher still running after ${seconds}s" }
  $script:lastExited = $p.HasExited
  Procs $tag
  Shot $tag
}
function Version($tag, $exe) {
  $o = Join-Path $Out "$tag-version.txt"
  cmd /c "`"$exe`" --version > `"$o`" 2>&1"
  Say "$tag --version exit=$LASTEXITCODE output=$(Get-Content $o -Raw)"
}

# A. unpacked exe
Version "unpacked" (Join-Path $Unpacked "UMOK-Helper.exe")
RunFor "A-unpacked-gui" (Join-Path $Unpacked "UMOK-Helper.exe") $null 30
Check "A: unpacked GUI still running after 30s" (-not $script:lastExited)
KillAll
# B. packed portable
RunFor "B-packed-portable" (Join-Path $Packed "UMOK-Helper.exe") $null 40
Say ("--- %LOCALAPPDATA%\umok-helper:`n" + (Get-ChildItem "$env:LOCALAPPDATA\umok-helper" -ErrorAction SilentlyContinue | Out-String))
Check "B: app process is running" ((Get-Process -Name "UMOK-Helper" -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
KillAll
# C. packed -install (should show the install page)
RunFor "C-packed-install-page" (Join-Path $Packed "UMOK-Helper-install.exe") $null 40
Check "C: install page process is running" ((Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "UMOK-Helper.exe" -and $_.CommandLine -match "--install" } | Measure-Object).Count -gt 0)
KillAll
# D. silent install + service
RunFor "D-silent-install" (Join-Path $Packed "UMOK-Helper.exe") @("--silent-install") 90
Say ("--- Program Files\UMOK-Helper:`n" + (Get-ChildItem "$env:ProgramFiles\UMOK-Helper" -ErrorAction SilentlyContinue | Out-String))
Check "D: installed exe exists" (Test-Path "$env:ProgramFiles\UMOK-Helper\UMOK-Helper.exe")
$svc = Get-Service -Name "UMOK-Helper" -ErrorAction SilentlyContinue
Say ("--- service:`n" + ($svc | Format-List Name, DisplayName, Status, StartType | Out-String))
Check "D: service UMOK-Helper is running" ($svc -and $svc.Status -eq "Running")
Say ("--- sc qc:`n" + (sc.exe qc "UMOK-Helper" | Out-String))
Procs "D-after-install"
Shot "D-after-install"
# E. control: official upstream RustDesk exe, same scenario
if ($ControlExe -and (Test-Path $ControlExe)) {
  KillAll
  Version "control" $ControlExe
  RunFor "E-control-portable" $ControlExe $null 40
  KillAll
}

# Logs
foreach ($d in @(
    "$env:APPDATA\UMOK-Helper\log",
    "$env:APPDATA\RustDesk\log",
    "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\UMOK-Helper\log",
    "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\log",
    "C:\Windows\System32\config\systemprofile\AppData\Roaming\UMOK-Helper\log")) {
  if (Test-Path $d) {
    $name = ($d -replace '[:\\ ]', '_')
    Copy-Item -Recurse -Force $d (Join-Path $Out "logs$name")
    Say "copied logs from $d"
  } else { Say "no logs at $d" }
}
Say (Get-ChildItem -Recurse "$env:APPDATA\UMOK-Helper" -ErrorAction SilentlyContinue | Select-Object FullName, Length | Out-String -Width 300)
if ($script:failed) { Say "SMOKE TEST FAILED"; exit 1 } else { Say "SMOKE TEST PASSED"; exit 0 }
