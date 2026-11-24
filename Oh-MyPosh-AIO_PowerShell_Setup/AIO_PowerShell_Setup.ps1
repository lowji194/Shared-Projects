#Requires -Version 5.1
<#
.SYNOPSIS
    Script cai dat AIO (All-In-One) lam dep PowerShell 7 + Windows Terminal
    (BAN TOI UU TOC DO V2 - cache oh-my-posh/zoxide, bo Get-Module runtime scan)
.DESCRIPTION
    Giong ban goc, nhung sua phan sinh $PROFILE de:
    - Khong con goi "oh-my-posh init pwsh | Invoke-Expression" moi lan mo terminal
      (spawn process ~100-300ms). Thay vao do, sinh san doan script prompt 1 lan,
      luu vao file cache, va CHI dot-source file cache do (khong con exe call).
    - Tuong tu voi zoxide: cache "zoxide init powershell" ra file, dot-source thay vi
      goi zoxide.exe moi lan mo terminal.
    - Bo 4 lenh Get-Module -ListAvailable (PSReadLine, posh-git, Terminal-Icons, PSFzf)
      vi lenh nay quet toan bo PSModulePath tren dia moi lan goi. Thay vao do, script
      cai dat se ghi thang cac gia tri true/false (da biet luc cai) vao profile.
    - Ham "theme <ten>" se TU DONG re-cache lai oh-my-posh moi khi doi theme, nen ban
      khong can lam gi them - tinh nang doi theme van hoat dong binh thuong.
.NOTES
    Chay bang PowerShell 7 (pwsh.exe) voi quyen Administrator.
    Viet Boi Loi Nguyen - lowji194.github.io.vn
#>

$EnablePoshGit = $false

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   CAI DAT AIO V2 - TOI UU TOC DO KHOI DONG GAN NHU 0ms" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[CANH BAO] Ban dang chay PowerShell $($PSVersionTable.PSVersion). Khuyen nghi PowerShell 7+." -ForegroundColor Yellow
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[CANH BAO] Chua chay voi quyen Administrator." -ForegroundColor Yellow
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[LOI] Khong tim thay winget. Cai 'App Installer' tu Microsoft Store truoc." -ForegroundColor Red
    exit 1
}

# ============================================================
#  1. OH MY POSH + THEMES (giu nguyen logic ban goc)
# ============================================================
Write-Host "[1/8] Dang cai dat Oh My Posh..." -ForegroundColor Green
try {
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-source-agreements --accept-package-agreements -e
} catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$poshThemesPath = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes"
$needDownloadThemes = $true
if (Test-Path $poshThemesPath) {
    $existingThemeCount = (Get-ChildItem -Path $poshThemesPath -Filter '*.omp.json' -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($existingThemeCount -ge 50) { $needDownloadThemes = $false }
}
if ($needDownloadThemes) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            New-Item -ItemType Directory -Force -Path $poshThemesPath | Out-Null
            $themesZip = Join-Path $env:TEMP "oh-my-posh-themes.zip"
            Invoke-WebRequest -Uri "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip" -OutFile $themesZip -UseBasicParsing
            Expand-Archive -Path $themesZip -DestinationPath $poshThemesPath -Force
            Remove-Item $themesZip -Force -ErrorAction SilentlyContinue
            break
        } catch { Start-Sleep -Seconds 2 }
    }
}
if (Test-Path $poshThemesPath) {
    [Environment]::SetEnvironmentVariable("POSH_THEMES_PATH", $poshThemesPath, "User")
    $env:POSH_THEMES_PATH = $poshThemesPath
}
Write-Host ""

# ============================================================
#  2. NERD FONT
# ============================================================
Write-Host "[2/8] Dang cai dat Nerd Font (CascadiaCode)..." -ForegroundColor Green
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try { oh-my-posh font install CascadiaCode } catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }
}
Write-Host ""

# ============================================================
#  3-6. MODULES (PSReadLine, Terminal-Icons, zoxide, posh-git, PSFzf)
# ============================================================
Write-Host "[3/8] PSReadLine..." -ForegroundColor Green
$hasPSReadLine = $false
try {
    Install-Module PSReadLine -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
    $hasPSReadLine = $true
} catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }

Write-Host "[4/8] Terminal-Icons..." -ForegroundColor Green
$hasTerminalIcons = $false
try {
    Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser -ErrorAction Stop
    $hasTerminalIcons = $true
} catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }

Write-Host "[5/8] zoxide..." -ForegroundColor Green
try { winget install ajeetdsouza.zoxide -s winget --accept-source-agreements --accept-package-agreements -e } catch {}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "[6/8] posh-git (tuy chon) + PSFzf..." -ForegroundColor Green
$hasPoshGit = $false
try {
    Install-Module posh-git -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    $hasPoshGit = $true
} catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }

$hasPSFzf = $false
try {
    winget install junegunn.fzf -s winget --accept-source-agreements --accept-package-agreements -e
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Install-Module PSFzf -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    $hasPSFzf = $true
} catch { Write-Host "      -> Loi: $_" -ForegroundColor Red }
Write-Host ""

# ============================================================
#  7. MODULE BO SUNG (giu nguyen)
# ============================================================
Write-Host "[7/8] Module bo sung (tuy chon): ImportExcel, Pester, PSScriptAnalyzer, SecretManagement, BurntToast" -ForegroundColor Green
$installExtra = Read-Host "Ban co muon cai tat ca cac module bo sung o tren khong? (Y/n)"
if ($installExtra -eq "" -or $installExtra -match "^[Yy]") {
    foreach ($mod in @("ImportExcel","Pester","PSScriptAnalyzer","Microsoft.PowerShell.SecretManagement","Microsoft.PowerShell.SecretStore","BurntToast")) {
        try { Install-Module -Name $mod -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop } catch { Write-Host "      -> Loi $mod : $_" -ForegroundColor Red }
    }
}
Write-Host ""

# ============================================================
#  8. TAO FILE $PROFILE (V2 - CACHE oh-my-posh & zoxide, KHONG con Get-Module runtime)
# ============================================================
Write-Host "[8/8] Dang cau hinh $PROFILE (V2 - cache, gan nhu 0ms overhead)..." -ForegroundColor Green

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (Test-Path $PROFILE) {
    $backupPath = "$PROFILE.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $PROFILE $backupPath -Force
    Write-Host "      -> Da sao luu profile cu vao: $backupPath" -ForegroundColor DarkGray
}

# Thu muc cache rieng, nam canh $PROFILE
$cacheDir = Join-Path $profileDir ".cache"
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
$poshCacheFile   = Join-Path $cacheDir "omp-init.ps1"
$zoxideCacheFile = Join-Path $cacheDir "zoxide-init.ps1"

$enablePoshGitLiteral    = if ($EnablePoshGit)    { '$true' } else { '$false' }
$hasPSReadLineLiteral    = if ($hasPSReadLine)    { '$true' } else { '$false' }
$hasTerminalIconsLiteral = if ($hasTerminalIcons) { '$true' } else { '$false' }
$hasPoshGitLiteral       = if ($hasPoshGit)       { '$true' } else { '$false' }
$hasPSFzfLiteral         = if ($hasPSFzf)         { '$true' } else { '$false' }
$poshCacheFileLiteral    = $poshCacheFile
$zoxideCacheFileLiteral  = $zoxideCacheFile

$profileContent = @"
# ============================================================
#  POWERSHELL PROFILE V2 - AUTO GENERATED (cache oh-my-posh/zoxide, khong scan module luc chay)
# ============================================================

`$__profileStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# --- Co bao module co san, ghi san luc cai dat, KHONG can Get-Module -ListAvailable moi lan mo terminal ---
`$script:HasPSReadLine    = $hasPSReadLineLiteral
`$script:HasTerminalIcons = $hasTerminalIconsLiteral
`$script:HasPoshGit       = $hasPoshGitLiteral
`$script:HasPSFzf         = $hasPSFzfLiteral
`$EnablePoshGit           = $enablePoshGitLiteral

`$script:PoshCacheFile   = "$poshCacheFileLiteral"
`$script:ZoxideCacheFile = "$zoxideCacheFileLiteral"

if (-not (Test-Path Env:\POSH_CURRENT_THEME)) { `$env:POSH_CURRENT_THEME = "dracula" }
if (-not `$env:POSH_THEMES_PATH) {
    `$fallbackThemesPath = Join-Path `$env:LOCALAPPDATA "Programs\oh-my-posh\themes"
    if (Test-Path `$fallbackThemesPath) { `$env:POSH_THEMES_PATH = `$fallbackThemesPath }
}

# --- Ham sinh lai cache oh-my-posh cho theme hien tai (chi goi khi doi theme / thieu cache) ---
function global:Update-OmpCache {
    param([string]`$ThemeName = `$env:POSH_CURRENT_THEME)
    if (-not `$env:POSH_THEMES_PATH) { return }
    `$themeFile = Join-Path `$env:POSH_THEMES_PATH "`$ThemeName.omp.json"
    if (-not (Test-Path `$themeFile)) { return }
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        `$initScript = oh-my-posh init pwsh --config `$themeFile
        Set-Content -Path `$script:PoshCacheFile -Value `$initScript -Encoding UTF8
    }
}

# --- Oh My Posh: DOT-SOURCE FILE CACHE, KHONG con goi oh-my-posh.exe moi lan mo terminal ---
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    if (-not (Test-Path `$script:PoshCacheFile)) {
        Update-OmpCache
    }
    if (Test-Path `$script:PoshCacheFile) {
        . `$script:PoshCacheFile
    }
}

# --- PSReadLine (co san, khong can Get-Module scan) ---
if (`$script:HasPSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{
        Command = 'Cyan'; Parameter = 'Gray'; String = 'Yellow'
        Operator = 'Magenta'; Variable = 'Green'; Comment = 'DarkGray'
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- posh-git (tuy chon, mac dinh tat) ---
if (`$EnablePoshGit -and `$script:HasPoshGit) { Import-Module posh-git }

# --- Terminal-Icons: lazy load, khong con Get-Module -ListAvailable ---
if (`$script:HasTerminalIcons) {
    function global:Enable-TerminalIconsOnce {
        Remove-Item Function:\ls -ErrorAction SilentlyContinue
        Remove-Item Function:\dir -ErrorAction SilentlyContinue
        Import-Module Terminal-Icons
    }
    function global:ls { Enable-TerminalIconsOnce; Get-ChildItem @args }
    function global:dir { Enable-TerminalIconsOnce; Get-ChildItem @args }
}

# --- PSFzf: lazy load, khong con Get-Module -ListAvailable ---
if (`$script:HasPSFzf) {
    function global:Enable-PSFzfOnce {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
    Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock {
        Enable-PSFzfOnce
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('')
        [Microsoft.PowerShell.PSConsoleReadLine]::Backward('Char')
        Invoke-PsFzfRipgrepFileWidget 2>`$null
    }
    Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock {
        Enable-PSFzfOnce
        Invoke-FuzzyHistory 2>`$null
    }
}

# --- zoxide: DOT-SOURCE FILE CACHE, KHONG con goi zoxide.exe moi lan mo terminal ---
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    if (-not (Test-Path `$script:ZoxideCacheFile)) {
        (zoxide init powershell | Out-String) | Set-Content -Path `$script:ZoxideCacheFile -Encoding UTF8
    }
    if (Test-Path `$script:ZoxideCacheFile) {
        . `$script:ZoxideCacheFile
    }
}

function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# ============================================================
#  LENH NHANH DOI THEME (tu dong re-cache khi doi theme)
# ============================================================
function Get-ThemeList {
    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) { return }
    Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter '*.omp.json' | Sort-Object BaseName |
        ForEach-Object { (`$_.BaseName -replace '\.omp`$', '') }
}

function Show-Themes {
    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) { return }
    Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter '*.omp.json' | Sort-Object BaseName | ForEach-Object {
        Write-Host "``n`$(`$_.BaseName -replace '\.omp`$','')" -ForegroundColor Cyan
        oh-my-posh print primary --config `$_.FullName
    }
    Write-Host "``nDung lenh: theme <ten-theme>" -ForegroundColor DarkGray
}

function Set-PoshThemeQuick {
    param([Parameter(Mandatory = `$true, Position = 0)][string]`$Name)
    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) { return }
    `$themeFile = Join-Path `$env:POSH_THEMES_PATH "`$Name.omp.json"
    if (-not (Test-Path `$themeFile)) {
        Write-Host "Khong tim thay theme '`$Name'. Go 'themes' de xem danh sach." -ForegroundColor Red
        return
    }
    `$env:POSH_CURRENT_THEME = `$Name
    [Environment]::SetEnvironmentVariable("POSH_CURRENT_THEME", `$Name, "User")
    # Re-cache va ap dung ngay cho session hien tai
    Update-OmpCache -ThemeName `$Name
    . `$script:PoshCacheFile
    Write-Host "Da doi sang theme: `$Name (da re-cache, tu dong dung lan sau)" -ForegroundColor Green
}

Set-Alias theme Set-PoshThemeQuick
Set-Alias themes Show-Themes

Register-ArgumentCompleter -CommandName Set-PoshThemeQuick -ParameterName Name -ScriptBlock {
    param(`$commandName, `$parameterName, `$wordToComplete, `$commandAst, `$fakeBoundParameters)
    if (`$env:POSH_THEMES_PATH -and (Test-Path `$env:POSH_THEMES_PATH)) {
        Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter "`$wordToComplete*.omp.json" |
            ForEach-Object { (`$_.BaseName -replace '\.omp`$', '') } | Sort-Object |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_) }
    }
}

# Xoa cache thu cong neu can debug / cai lai module
function Clear-AioCache {
    Remove-Item `$script:PoshCacheFile, `$script:ZoxideCacheFile -Force -ErrorAction SilentlyContinue
    Write-Host "Da xoa cache. Mo terminal moi de tao lai." -ForegroundColor Yellow
}

function Show-ProfileLoadTime {
    Write-Host "Lan khoi dong profile gan nhat mat: `$(`$__profileStopwatch.ElapsedMilliseconds) ms" -ForegroundColor Magenta
}
Set-Alias profiletime Show-ProfileLoadTime

`$__profileStopwatch.Stop()
Write-Host "Viet Boi Loi Nguyen - lowji194.github.io.vn (profile: `$(`$__profileStopwatch.ElapsedMilliseconds) ms)" -ForegroundColor DarkGray
"@

Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
Write-Host "      -> Hoan tat. File profile: $PROFILE" -ForegroundColor DarkGreen
Write-Host ""

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  CAI DAT V2 HOAN TAT!" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Lan mo terminal DAU TIEN sau khi cai se hoi cham hon binh thuong mot chut" -ForegroundColor Yellow
Write-Host "(vi phai sinh cache lan dau). Tu lan thu 2 tro di se gan nhu 0ms overhead" -ForegroundColor Yellow
Write-Host "cho phan oh-my-posh + zoxide, vi chi con dot-source file cache tinh, khong" -ForegroundColor Yellow
Write-Host "con spawn process nao ca." -ForegroundColor Yellow
Write-Host ""
Write-Host "Lenh moi: Clear-AioCache  -> xoa cache neu can debug hoac vua cap nhat oh-my-posh/zoxide" -ForegroundColor White
Write-Host "So sanh: chay 'Measure-Command { . `$PROFILE }' truoc va sau de thay chenh lech." -ForegroundColor White
Write-Host ""
