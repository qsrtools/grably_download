# ============================================================================
#  PASTE THIS BLOCK INTO install.ps1
#  Location: AFTER Grably is extracted + shortcuts created, and BEFORE the final
#  "Launch Grably now? [Y/N]" prompt.
#
#  What it does: checks whether the Microsoft Edge WebView2 Runtime (which Grably
#  needs to render its UI) is present. If NOT, it ASKS the user (optional) and,
#  on agreement, downloads + silently installs the official Evergreen runtime.
#  Fully guarded — a failure here never breaks the Grably install.
# ============================================================================

function Test-WebView2Installed {
    # Present iff the EdgeUpdate 'pv' version key for the WebView2 runtime GUID
    # exists (HKLM 64-bit / 32-bit, or per-user HKCU) and is a real version.
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

Write-Host ""
if (Test-WebView2Installed) {
    Write-Host "  [WebView2] Microsoft Edge WebView2 Runtime is already installed." -ForegroundColor Green
} else {
    Write-Host "  Grably needs the Microsoft Edge WebView2 Runtime to display its window." -ForegroundColor Yellow
    $ans = Read-Host "  Install it now? (recommended) [Y/N]"
    if ($ans -match '^(y|yes)$') {
        try {
            $wv2 = Join-Path $env:TEMP "MicrosoftEdgeWebview2Setup.exe"
            # Official Evergreen Bootstrapper (small ~2 MB, always pulls the latest runtime).
            $url = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"

            Write-Host "  Downloading WebView2 Runtime installer..." -ForegroundColor Cyan
            try {
                Invoke-WebRequest -Uri $url -OutFile $wv2 -UseBasicParsing
            } catch {
                # Fallback to curl (ships with Windows 10 1803+) if IWR fails.
                curl.exe -L -o "$wv2" "$url"
            }

            Write-Host "  Installing WebView2 Runtime (silent)..." -ForegroundColor Cyan
            $proc = Start-Process -FilePath $wv2 -ArgumentList "/silent","/install" -Wait -PassThru
            Start-Sleep -Seconds 2

            if (Test-WebView2Installed) {
                Write-Host "  [WebView2] Installed successfully." -ForegroundColor Green
            } else {
                Write-Host "  [WebView2] Setup finished (exit $($proc.ExitCode))." -ForegroundColor Yellow
                Write-Host "  If Grably shows a blank window, install manually from:" -ForegroundColor Yellow
                Write-Host "  https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor Yellow
            }
            Remove-Item $wv2 -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  [WebView2] Install failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  You can install it later from:" -ForegroundColor Yellow
            Write-Host "  https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Skipped WebView2. NOTE: Grably may show a blank window until it is installed." -ForegroundColor Yellow
    }
}
