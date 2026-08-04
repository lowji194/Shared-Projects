#Requires -Version 5.1
<#
.SYNOPSIS
    Script cai dat AIO (All-In-One) lam dep PowerShell 7 + Windows Terminal
.DESCRIPTION
    Tu dong cai dat va cau hinh:
    - Oh My Posh (theme prompt mac dinh: Dracula, load THEME LOCAL, khong can mang, tu co git segment)
    - Nerd Font (CascadiaCode)
    - PSReadLine (autocomplete + syntax highlight)
    - Terminal-Icons (icon cho file/folder) - LAZY LOAD, chi load khi go ls/dir lan dau
    - zoxide (nhay thu muc thong minh)
    - PSFzf (fuzzy finder cho lich su lenh & file) - LAZY LOAD, chi load khi bam Ctrl+T/Ctrl+R lan dau
    - (Tuy chon) ImportExcel, Pester, PSScriptAnalyzer, SecretManagement, BurntToast
    - File $PROFILE hoan chinh, kem lenh nhanh doi theme (theme / themes) va do thoi gian khoi dong (profiletime)
.NOTES
    Chay script nay bang PowerShell 7 (pwsh.exe), voi quyen Administrator de winget hoat dong on dinh.
    Viet Boi Loi Nguyen - lowji194.github.io.vn

    GHI CHU TOI UU TOC DO (so voi ban goc):
    - Bo Import-Module posh-git mac dinh: cac theme Oh My Posh (bao gom Dracula) da co san
      segment hien trang thai Git tren prompt, nen posh-git thuong la thua va la nguyen nhan
      chinh gay cham 1-2 giay khi mo terminal. Neu ban van muon dung posh-git (vi du can
      tab-completion cho lenh git), sua bien $EnablePoshGit ben duoi thanh $true.
    - Terminal-Icons va PSFzf duoc lazy-load: module That su chi duoc Import-Module khi ban
      goi lenh lien quan lan dau tien (ls/dir hoac Ctrl+T/Ctrl+R), thay vi load ngay khi mo
      terminal moi.
    - Them lenh "profiletime" de tu do thoi gian khoi dong profile bat cu luc nao.
#>

# ============================================================
#  TUY CHINH NHANH (co the sua truoc khi chay)
# ============================================================

# Dat $true neu muon van Import-Module posh-git ngay khi mo terminal (se cham hon).
# Mac dinh $false vi oh-my-posh da co segment git san.
$EnablePoshGit = $false

# ============================================================
#  KIEM TRA MOI TRUONG
# ============================================================

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   CAI DAT AIO - LAM DEP POWERSHELL 7 (Theme: Dracula)" -ForegroundColor Cyan
Write-Host "   (Ban toi uu toc do khoi dong)" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[CANH BAO] Ban dang chay PowerShell $($PSVersionTable.PSVersion). Khuyen nghi dung PowerShell 7+." -ForegroundColor Yellow
    Write-Host "Cai PowerShell 7 bang lenh: winget install Microsoft.PowerShell" -ForegroundColor Yellow
    Write-Host ""
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[CANH BAO] Script chua chay voi quyen Administrator." -ForegroundColor Yellow
    Write-Host "Mot so buoc (winget, cai font) co the yeu cau quyen admin de hoat dong dung." -ForegroundColor Yellow
    Write-Host ""
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[LOI] Khong tim thay winget. Vui long cai dat 'App Installer' tu Microsoft Store truoc." -ForegroundColor Red
    exit 1
}

# ============================================================
#  1. CAI OH MY POSH
# ============================================================

Write-Host "[1/8] Dang cai dat Oh My Posh..." -ForegroundColor Green
try {
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-source-agreements --accept-package-agreements -e
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      -> winget tra ve ma loi $LASTEXITCODE. Co the da cai san hoac can kiem tra thu cong." -ForegroundColor Yellow
    } else {
        Write-Host "      -> Hoan tat." -ForegroundColor DarkGreen
    }
} catch {
    Write-Host "      -> Loi khi cai Oh My Posh: $_" -ForegroundColor Red
}
Write-Host ""

# Refresh PATH trong session hien tai de nhan lenh moi cai
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Thiet lap bien moi truong POSH_THEMES_PATH (vinh vien, cho user hien tai) ---
# De oh-my-posh luon load theme TU O CUNG (local), khong can tai qua mang moi lan mo terminal
Write-Host "      Dang thiet lap POSH_THEMES_PATH (theme local)..." -ForegroundColor Green
try {
    $poshThemesPath = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes"

    # Kiem tra xem thu muc theme co ton tai VA co san file .omp.json ben trong khong.
    # Luu y: winget/App Installer chi cai BINARY oh-my-posh, KHONG tu dong tai theme ve,
    # nen thu muc nay co the ton tai nhung rong -> van phai tai theme thu cong.
    $needDownloadThemes = $true
    if (Test-Path $poshThemesPath) {
        $existingThemeCount = (Get-ChildItem -Path $poshThemesPath -Filter '*.omp.json' -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($existingThemeCount -ge 50) {
            $needDownloadThemes = $false
            Write-Host "      -> Da co san $existingThemeCount theme tai $poshThemesPath" -ForegroundColor DarkGreen
        }
    }

    if ($needDownloadThemes) {
    $maxAttempts = 3
    $success = $false

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host "      -> Dang tai bo theme (lan thu $attempt/$maxAttempts)..." -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Force -Path $poshThemesPath | Out-Null
            $themesZip = Join-Path $env:TEMP "oh-my-posh-themes.zip"
            Invoke-WebRequest -Uri "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip" -OutFile $themesZip -UseBasicParsing

            $zipSize = (Get-Item $themesZip).Length
            if ($zipSize -lt 500000) {
                throw "File zip qua nho ($zipSize byte), co the tai bi loi/dut mang."
            }

            Get-ChildItem -Path $poshThemesPath -Filter '*.omp.json' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path $themesZip -DestinationPath $poshThemesPath -Force
            Remove-Item $themesZip -Force -ErrorAction SilentlyContinue

            $downloadedCount = (Get-ChildItem -Path $poshThemesPath -Filter '*.omp.json' -ErrorAction SilentlyContinue | Measure-Object).Count
            if ($downloadedCount -ge 50) {
                Write-Host "      -> Da tai va giai nen thanh cong $downloadedCount theme." -ForegroundColor DarkGreen
                $success = $true
                break
            } else {
                Write-Host "      -> Chi co $downloadedCount theme (ky vong >= 50). Se thu lai..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "      -> Loi lan $attempt : $_" -ForegroundColor Red
        }

        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 2
        }
    }

    if (-not $success) {
        Write-Host "      -> Tai bo theme that bai sau $maxAttempts lan thu." -ForegroundColor Red
        Write-Host "         Ban co the tai thu cong tai: https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip" -ForegroundColor Yellow
    }
    }

    if (Test-Path $poshThemesPath) {
        [Environment]::SetEnvironmentVariable("POSH_THEMES_PATH", $poshThemesPath, "User")
        $env:POSH_THEMES_PATH = $poshThemesPath
        Write-Host "      -> Da set POSH_THEMES_PATH = $poshThemesPath" -ForegroundColor DarkGreen
    } else {
        Write-Host "      -> Van chua tim thay thu muc theme tai $poshThemesPath (se thu lai sau khi mo terminal moi)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "      -> Loi khi set POSH_THEMES_PATH: $_" -ForegroundColor Red
}
Write-Host ""

# ============================================================
#  2. CAI NERD FONT
# ============================================================

Write-Host "[2/8] Dang cai dat Nerd Font (CascadiaCode)..." -ForegroundColor Green
try {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh font install CascadiaCode
        Write-Host "      -> Hoan tat. Nho vao Windows Terminal > Settings > Font face doi thanh 'CaskaydiaCove Nerd Font'." -ForegroundColor DarkGreen
    } else {
        Write-Host "      -> Bo qua: chua tim thay lenh oh-my-posh. Hay chay lai script sau khi mo lai terminal moi." -ForegroundColor Yellow
    }
} catch {
    Write-Host "      -> Loi khi cai font: $_" -ForegroundColor Red
}
Write-Host ""

# ============================================================
#  3. CAP NHAT PSReadLine
# ============================================================

Write-Host "[3/8] Dang cap nhat PSReadLine..." -ForegroundColor Green
try {
    Install-Module PSReadLine -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
    Write-Host "      -> Hoan tat." -ForegroundColor DarkGreen
} catch {
    Write-Host "      -> Loi khi cai PSReadLine: $_" -ForegroundColor Red
}
Write-Host ""

# ============================================================
#  4. CAI Terminal-Icons
# ============================================================

Write-Host "[4/8] Dang cai dat Terminal-Icons..." -ForegroundColor Green
try {
    Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser -ErrorAction Stop
    Write-Host "      -> Hoan tat. (Se duoc lazy-load, khong lam cham luc mo terminal)" -ForegroundColor DarkGreen
} catch {
    Write-Host "      -> Loi khi cai Terminal-Icons: $_" -ForegroundColor Red
}
Write-Host ""

# ============================================================
#  5. CAI zoxide
# ============================================================

Write-Host "[5/8] Dang cai dat zoxide..." -ForegroundColor Green
try {
    winget install ajeetdsouza.zoxide -s winget --accept-source-agreements --accept-package-agreements -e
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      -> winget tra ve ma loi $LASTEXITCODE. Co the da cai san hoac can kiem tra thu cong." -ForegroundColor Yellow
    } else {
        Write-Host "      -> Hoan tat." -ForegroundColor DarkGreen
    }
} catch {
    Write-Host "      -> Loi khi cai zoxide: $_" -ForegroundColor Red
}
Write-Host ""

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ============================================================
#  6. CAI CAC MODULE KHUYEN NGHI (posh-git tuy chon + PSFzf)
# ============================================================

Write-Host "[6/8] Dang cai dat posh-git (tuy chon) va PSFzf (fuzzy finder)..." -ForegroundColor Green

try {
    Install-Module posh-git -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    if ($EnablePoshGit) {
        Write-Host "      -> posh-git: Hoan tat (se duoc Import-Module ngay khi mo terminal)." -ForegroundColor DarkGreen
    } else {
        Write-Host "      -> posh-git: Da cai san nhung se KHONG tu dong load (dung git segment cua oh-my-posh thay the)." -ForegroundColor DarkGreen
        Write-Host "         Neu muon bat lai, sua `$EnablePoshGit = `$true trong script nay va chay lai." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "      -> Loi khi cai posh-git: $_" -ForegroundColor Red
}

try {
    # PSFzf can binary fzf, cai qua winget truoc
    winget install junegunn.fzf -s winget --accept-source-agreements --accept-package-agreements -e
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      -> fzf: winget tra ve ma loi $LASTEXITCODE." -ForegroundColor Yellow
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Install-Module PSFzf -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    Write-Host "      -> PSFzf: Hoan tat. (Se duoc lazy-load, khong lam cham luc mo terminal)" -ForegroundColor DarkGreen
} catch {
    Write-Host "      -> Loi khi cai PSFzf: $_" -ForegroundColor Red
}
Write-Host ""

# ============================================================
#  7. MODULE BO SUNG (TUY CHON)
# ============================================================

Write-Host "[7/8] Module bo sung (tuy chon):" -ForegroundColor Green
Write-Host "      - ImportExcel        : doc/ghi file Excel bang PowerShell" -ForegroundColor White
Write-Host "      - Pester             : framework viet unit test cho script" -ForegroundColor White
Write-Host "      - PSScriptAnalyzer   : linter kiem tra chat luong code" -ForegroundColor White
Write-Host "      - SecretManagement   : luu password/API key an toan" -ForegroundColor White
Write-Host "      - BurntToast         : hien thong bao Windows (toast) tu script" -ForegroundColor White
Write-Host ""

$installExtra = Read-Host "Ban co muon cai tat ca cac module bo sung o tren khong? (Y/n)"

if ($installExtra -eq "" -or $installExtra -match "^[Yy]") {
    $extraModules = @(
        "ImportExcel",
        "Pester",
        "PSScriptAnalyzer",
        "Microsoft.PowerShell.SecretManagement",
        "Microsoft.PowerShell.SecretStore",
        "BurntToast"
    )

    foreach ($mod in $extraModules) {
        Write-Host "      Dang cai $mod..." -ForegroundColor Green
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
            Write-Host "      -> $mod : Hoan tat." -ForegroundColor DarkGreen
        } catch {
            Write-Host "      -> Loi khi cai $mod : $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "      -> Bo qua cac module bo sung. Ban co the tu cai sau bang Install-Module." -ForegroundColor Yellow
}
Write-Host ""

# ============================================================
#  8. TAO FILE $PROFILE (BAN TOI UU TOC DO)
# ============================================================

Write-Host "[8/8] Dang cau hinh file profile PowerShell (theme: Dracula, toi uu toc do)..." -ForegroundColor Green

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path $PROFILE) {
    $backupPath = "$PROFILE.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $PROFILE $backupPath -Force
    Write-Host "      -> Da sao luu profile cu vao: $backupPath" -ForegroundColor DarkGray
}

$enablePoshGitLiteral = if ($EnablePoshGit) { '$true' } else { '$false' }

$profileContent = @"
# ============================================================
#  POWERSHELL PROFILE - AUTO GENERATED (Ban toi uu toc do khoi dong)
# ============================================================

# Do thoi gian khoi dong toan bo profile - go "profiletime" bat cu luc nao de xem lai
`$__profileStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# --- Bien luu ten theme dang dung (mac dinh: dracula) ---
if (-not (Test-Path Env:\POSH_CURRENT_THEME)) {
    `$env:POSH_CURRENT_THEME = "dracula"
}

# --- Oh My Posh (theme prompt, uu tien load LOCAL, da co san git segment) ---
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {

    # Neu POSH_THEMES_PATH chua duoc set trong session nay, thu tu suy ra tu duong dan cai dat mac dinh
    if (-not `$env:POSH_THEMES_PATH) {
        `$fallbackThemesPath = Join-Path `$env:LOCALAPPDATA "Programs\oh-my-posh\themes"
        if (Test-Path `$fallbackThemesPath) {
            `$env:POSH_THEMES_PATH = `$fallbackThemesPath
        }
    }

    `$currentThemeFile = `$null
    if (`$env:POSH_THEMES_PATH) {
        `$currentThemeFile = Join-Path `$env:POSH_THEMES_PATH "`$(`$env:POSH_CURRENT_THEME).omp.json"
    }

    if (`$currentThemeFile -and (Test-Path `$currentThemeFile)) {
        # Load theme LOCAL - khong can mang, nhanh hon
        oh-my-posh init pwsh --config `$currentThemeFile | Invoke-Expression
    } else {
        # Fallback: chi tai qua mang neu khong tim thay theme local
        oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/dracula.omp.json" | Invoke-Expression
    }
}

# --- PSReadLine (autocomplete + syntax highlight) ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{
        Command   = 'Cyan'
        Parameter = 'Gray'
        String    = 'Yellow'
        Operator  = 'Magenta'
        Variable  = 'Green'
        Comment   = 'DarkGray'
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- posh-git (TUY CHON - mac dinh TAT vi oh-my-posh da co git segment san) ---
`$EnablePoshGit = $enablePoshGitLiteral
if (`$EnablePoshGit -and (Get-Module -ListAvailable -Name posh-git)) {
    Import-Module posh-git
}

# --- Terminal-Icons: LAZY LOAD, chi Import-Module khi go ls/dir lan dau ---
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    function global:Enable-TerminalIconsOnce {
        Remove-Item Function:\ls -ErrorAction SilentlyContinue
        Remove-Item Function:\dir -ErrorAction SilentlyContinue
        Import-Module Terminal-Icons
    }
    function global:ls { Enable-TerminalIconsOnce; Get-ChildItem @args }
    function global:dir { Enable-TerminalIconsOnce; Get-ChildItem @args }
}

# --- PSFzf: LAZY LOAD, chi Import-Module khi bam Ctrl+T hoac Ctrl+R lan dau ---
if (Get-Module -ListAvailable -Name PSFzf) {
    function global:Enable-PSFzfOnce {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
    Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock {
        Enable-PSFzfOnce
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('')
        [Microsoft.PowerShell.PSConsoleReadLine]::Backward('Char')
        # Sau lan dau, phim Ctrl+T da duoc PSFzf tiep quan lai tu day
        Invoke-PsFzfRipgrepFileWidget 2>`$null
    }
    Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock {
        Enable-PSFzfOnce
        Invoke-FuzzyHistory 2>`$null
    }
}

# --- zoxide (nhay thu muc thong minh: dung "z ten-thu-muc") ---
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# --- Alias tien ich ---
function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# ============================================================
#  LENH NHANH DOI THEME OH MY POSH
# ============================================================

# Liet ke danh sach ten theme dang co (khong preview, chi liet ke nhanh)
function Get-ThemeList {
    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) {
        Write-Host "Khong tim thay thu muc theme. Kiem tra bien POSH_THEMES_PATH." -ForegroundColor Red
        return
    }
    Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter '*.omp.json' |
        Sort-Object BaseName |
        ForEach-Object { (`$_.BaseName -replace '\.omp`$', '') }
}

# Xem truoc TAT CA theme ngay trong terminal (in mau thuc te tung theme)
function Show-Themes {
    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) {
        Write-Host "Khong tim thay thu muc theme. Kiem tra bien POSH_THEMES_PATH." -ForegroundColor Red
        return
    }
    Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter '*.omp.json' | Sort-Object BaseName | ForEach-Object {
        Write-Host "``n`$(`$_.BaseName -replace '\.omp`$','')" -ForegroundColor Cyan
        oh-my-posh print primary --config `$_.FullName
    }
    Write-Host "``nDung lenh: theme <ten-theme>  de doi theme (vi du: theme jandedobbeleer)" -ForegroundColor DarkGray
}

# Doi theme ngay lap tuc + luu lai vinh vien cho lan mo terminal sau
function Set-PoshThemeQuick {
    param(
        [Parameter(Mandatory = `$true, Position = 0)]
        [string]`$Name
    )

    if (-not `$env:POSH_THEMES_PATH -or -not (Test-Path `$env:POSH_THEMES_PATH)) {
        Write-Host "Khong tim thay thu muc theme. Kiem tra bien POSH_THEMES_PATH." -ForegroundColor Red
        return
    }

    `$themeFile = Join-Path `$env:POSH_THEMES_PATH "`$Name.omp.json"
    if (-not (Test-Path `$themeFile)) {
        Write-Host "Khong tim thay theme '`$Name'." -ForegroundColor Red
        Write-Host "Go 'themes' de xem danh sach va preview cac theme dang co." -ForegroundColor Yellow
        return
    }

    # Ap dung ngay cho session hien tai
    oh-my-posh init pwsh --config `$themeFile | Invoke-Expression
    `$env:POSH_CURRENT_THEME = `$Name

    # Luu lai vinh vien (bien User) de lan sau mo terminal tu dong dung theme nay
    [Environment]::SetEnvironmentVariable("POSH_CURRENT_THEME", `$Name, "User")

    Write-Host "Da doi sang theme: `$Name (da luu, lan sau mo terminal se tu dong dung theme nay)" -ForegroundColor Green
}

# Alias ngan gon
Set-Alias theme Set-PoshThemeQuick
Set-Alias themes Show-Themes

# Tab-completion cho lenh "theme": go "theme " roi nhan Tab de goi y ten theme
Register-ArgumentCompleter -CommandName Set-PoshThemeQuick -ParameterName Name -ScriptBlock {
    param(`$commandName, `$parameterName, `$wordToComplete, `$commandAst, `$fakeBoundParameters)
    if (`$env:POSH_THEMES_PATH -and (Test-Path `$env:POSH_THEMES_PATH)) {
        Get-ChildItem -Path `$env:POSH_THEMES_PATH -Filter "`$wordToComplete*.omp.json" |
            ForEach-Object { (`$_.BaseName -replace '\.omp`$', '') } |
            Sort-Object |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_) }
    }
}

# ============================================================
#  LENH DO THOI GIAN KHOI DONG PROFILE
# ============================================================
function Show-ProfileLoadTime {
    Write-Host "Lan khoi dong profile gan nhat mat: `$(`$__profileStopwatch.ElapsedMilliseconds) ms" -ForegroundColor Magenta
    Write-Host "Neu muon do lai tu dau, chay: Measure-Command { . `$PROFILE }" -ForegroundColor DarkGray
}
Set-Alias profiletime Show-ProfileLoadTime

`$__profileStopwatch.Stop()

Write-Host "Viet Boi Loi Nguyen - lowji194.github.io.vn (profile: `$(`$__profileStopwatch.ElapsedMilliseconds) ms)" -ForegroundColor DarkGray
"@

Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8

Write-Host "      -> Hoan tat. File profile: $PROFILE" -ForegroundColor DarkGreen
Write-Host ""

# ============================================================
#  KET THUC
# ============================================================

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  CAI DAT HOAN TAT! (Theme mac dinh: Dracula)" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CAC BUOC TIEP THEO (BAT BUOC):" -ForegroundColor Yellow
Write-Host "  1. Dong terminal nay va mo lai PowerShell 7 (pwsh)." -ForegroundColor White
Write-Host "  2. Mo Windows Terminal > Settings > Profile PowerShell > Appearance" -ForegroundColor White
Write-Host "     -> Doi Font face thanh: CaskaydiaCove Nerd Font" -ForegroundColor White
Write-Host ""
Write-Host "GOI Y SU DUNG NHANH:" -ForegroundColor Yellow
Write-Host "  - Ctrl+R          : tim lich su lenh bang fuzzy search (PSFzf, lazy-load lan dau)" -ForegroundColor White
Write-Host "  - Ctrl+T          : tim file bang fuzzy search (PSFzf, lazy-load lan dau)" -ForegroundColor White
Write-Host "  - z ten-thu-muc   : nhay nhanh toi thu muc da tung vao (zoxide)" -ForegroundColor White
Write-Host "  - themes          : xem truoc TAT CA theme ngay trong terminal" -ForegroundColor White
Write-Host "  - theme <ten>     : doi theme ngay lap tuc + tu luu lai (vi du: theme jandedobbeleer)" -ForegroundColor White
Write-Host "                      Go 'theme ' roi nhan Tab de tab-completion goi y ten theme" -ForegroundColor White
Write-Host "  - profiletime     : xem profile lan nay mat bao nhieu ms de khoi dong" -ForegroundColor White
Write-Host ""
Write-Host "GHI CHU TOC DO:" -ForegroundColor Yellow
Write-Host "  - posh-git mac dinh KHONG tu load (dung git segment cua oh-my-posh)." -ForegroundColor White
Write-Host "  - Terminal-Icons va PSFzf duoc lazy-load, chi Import-Module khi thuc su dung." -ForegroundColor White
Write-Host "  - Neu van con cham, chay: Measure-Command { . `$PROFILE }  de xem con dong nao nang." -ForegroundColor White
Write-Host ""
