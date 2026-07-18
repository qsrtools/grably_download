# ============================================================
#  Grably - One-Click Installer
#  Run as Administrator in PowerShell:
#  iwr -useb https://raw.githubusercontent.com/Ahsaan-Ullah/Installgrably/refs/heads/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── Config ──
$AppName       = "Grably"
$InstallDir    = "C:\Grably"
$DesktopLink   = "$env:USERPROFILE\Desktop\Grably.lnk"
$StartMenuDir  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$StartMenuLink = "$StartMenuDir\Grably.lnk"

$DownloadURL   = "http://qsrtools.shop/grably_beta.zip"
$ZipFile       = "$env:TEMP\grably_install.zip"

# ── UI Helpers ──
function Write-Step  { param($msg) Write-Host "`n  [$script:step] $msg" -ForegroundColor Cyan; $script:step++ }
function Write-OK    { param($msg) Write-Host "      [OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "      [SKIP] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "      [FAIL] $msg" -ForegroundColor Red }
$script:step = 1

# ── WebView2 detection helper ──
function Test-WebView2Installed {
    # Present iff EdgeUpdate has a real 'pv' version for the WebView2 runtime GUID
    # (checks HKLM 64-bit / 32-bit and per-user HKCU).
    $guid  = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    $paths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$guid",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid",
        "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid"
    )
    foreach ($p in $paths) {
        try {
            $pv = (Get-ItemProperty -Path $p -Name pv -ErrorAction Stop).pv
            if ($pv -and $pv -ne '0.0.0.0') { return $true }
        } catch { }
    }
    return $false
}

# ── Admin Check ──
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n  [ERROR] Please run PowerShell as Administrator!" -ForegroundColor Red
    Write-Host "  Right-click PowerShell -> Run as Administrator`n" -ForegroundColor Yellow
    pause
    exit 1
}

# ── Banner ──
Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "       Grably - Video Downloader Installer" -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host ""

# ── Step 1: Create install directory ──
Write-Step "Creating install directory..."
if (Test-Path $InstallDir) {
    Write-Skip "$InstallDir already exists (upgrading)"
} else {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-OK "Created $InstallDir"
}

# ── Step 2: Download Grably with progress ──
Write-Step "Downloading Grably..."
try {
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $DownloadURL -OutFile $ZipFile -UseBasicParsing -Verbose
    Write-OK "Downloaded successfully"
} catch {
    # Fallback: curl with progress
    try {
        curl.exe -L --fail --progress-bar -o $ZipFile $DownloadURL 2>$null
        Write-OK "Downloaded via curl"
    } catch {
        Write-Err "Download failed: $_"
        pause; exit 1
    }
}

# ── Step 3: Extract ──
Write-Step "Extracting files..."
try {
    Expand-Archive -Path $ZipFile -DestinationPath $InstallDir -Force
    Remove-Item $ZipFile -Force -ErrorAction SilentlyContinue
    Write-OK "Extracted to $InstallDir"
} catch {
    Write-Err "Extraction failed: $_"
    pause; exit 1
}

# ── Step 4: Create Desktop & Start Menu Shortcut ──
Write-Step "Creating shortcuts..."
$exePath = "$InstallDir\Grably.exe"
if (Test-Path $exePath) {
    try {
        $WshShell = New-Object -ComObject WScript.Shell

        # Desktop shortcut
        $Shortcut = $WshShell.CreateShortcut($DesktopLink)
        $Shortcut.TargetPath = $exePath
        $Shortcut.WorkingDirectory = $InstallDir
        $Shortcut.IconLocation = "$InstallDir\icons\icon.ico"
        $Shortcut.Description = "Grably - Advanced Video Downloader"
        $Shortcut.Save()
        Write-OK "Desktop shortcut created"

        # Start Menu shortcut
        $Shortcut2 = $WshShell.CreateShortcut($StartMenuLink)
        $Shortcut2.TargetPath = $exePath
        $Shortcut2.WorkingDirectory = $InstallDir
        $Shortcut2.IconLocation = "$InstallDir\icons\icon.ico"
        $Shortcut2.Description = "Grably - Advanced Video Downloader"
        $Shortcut2.Save()
        Write-OK "Start Menu shortcut created"
    } catch {
        Write-Err "Shortcut creation failed: $_"
    }
} else {
    Write-Err "Grably.exe not found at $exePath"
}

# ── Step 5: Add to PATH (optional) ──
Write-Step "Adding to system PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$InstallDir*") {
    try {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
        Write-OK "Added $InstallDir to PATH"
    } catch {
        Write-Skip "Could not add to PATH (non-critical)"
    }
} else {
    Write-Skip "Already in PATH"
}

# ── Step 6: Microsoft Edge WebView2 Runtime (required to render Grably's UI) ──
Write-Step "Checking Microsoft Edge WebView2 Runtime..."
if (Test-WebView2Installed) {
    Write-OK "WebView2 Runtime already installed"
} else {
    Write-Host "      Grably needs the Microsoft Edge WebView2 Runtime to display its window." -ForegroundColor Yellow
    $wv2ans = Read-Host "      Install it now? (recommended) [Y/N]"
    if ($wv2ans -eq "Y" -or $wv2ans -eq "y") {
        try {
            $wv2    = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
            # Official Evergreen Bootstrapper (~2 MB, always pulls the latest runtime).
            $wv2url = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
            Write-Host "      Downloading WebView2 Runtime..." -ForegroundColor Cyan
            try {
                Invoke-WebRequest -Uri $wv2url -OutFile $wv2 -UseBasicParsing
            } catch {
                curl.exe -L -o "$wv2" "$wv2url" 2>$null
            }
            Write-Host "      Installing WebView2 Runtime (silent)..." -ForegroundColor Cyan
            $proc = Start-Process -FilePath $wv2 -ArgumentList "/silent","/install" -Wait -PassThru
            Start-Sleep -Seconds 2
            Remove-Item $wv2 -Force -ErrorAction SilentlyContinue
            if (Test-WebView2Installed) {
                Write-OK "WebView2 Runtime installed"
            } else {
                Write-Skip "WebView2 setup finished (exit $($proc.ExitCode)) - if Grably shows a blank window, install it manually"
            }
        } catch {
            Write-Err "WebView2 install failed: $_"
            Write-Host "      Install later from: https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor Yellow
        }
    } else {
        Write-Skip "WebView2 skipped - Grably may show a blank window until it is installed"
    }
}

# ── Done ──
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "       Grably installed successfully!" -ForegroundColor White
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Install location : $InstallDir" -ForegroundColor Gray
Write-Host "  Desktop shortcut : Grably" -ForegroundColor Gray
Write-Host ""
Write-Host "  You can now close this window and" -ForegroundColor Yellow
Write-Host "  launch Grably from your Desktop!" -ForegroundColor Yellow
Write-Host ""

# Ask to launch
$launch = Read-Host "  Launch Grably now? (Y/N)"
if ($launch -eq "Y" -or $launch -eq "y") {
    Start-Process $exePath -WorkingDirectory $InstallDir
}
