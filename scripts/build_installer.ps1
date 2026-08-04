# QuickFix Installer Builder Script
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Building QuickFix Windows Installer Wizard " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoCompiler)) {
    $InnoCompiler = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

if (-not (Test-Path $InnoCompiler)) {
    Write-Host "[ERROR] Inno Setup 6 Compiler (ISCC.exe) was not found." -ForegroundColor Red
    exit 1
}

# 1. Build Flutter Windows Release
Write-Host "`n[1/2] Compiling Flutter Windows release executable..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2. Compile Inno Setup Script
Write-Host "`n[2/2] Compiling Windows Installer Wizard .exe..." -ForegroundColor Yellow
& "$InnoCompiler" "installer\quickfix_installer.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host " SUCCESS! Installer wizard built at:" -ForegroundColor Green
    Write-Host " build\installer\QuickFix_Setup_v1.0.0.exe" -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Installer compilation failed." -ForegroundColor Red
}
