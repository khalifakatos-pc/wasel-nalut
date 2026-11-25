$ErrorActionPreference = "Stop"
$destDir = "C:\Users\kalifa\Desktop\Wasel_Android_APKs"
if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

Write-Host "================================================================"
Write-Host "BUILDING WASEL ADMIN APP RELEASE APK"
Write-Host "================================================================"
Push-Location flutter_admin_app
try {
    flutter build apk --release
    $adminApk = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $adminApk) {
        $destAdmin = Join-Path $destDir "Wasel_Admin_App.apk"
        Copy-Item -Path $adminApk -Destination $destAdmin -Force
        $item = Get-Item $destAdmin
        $mb = [math]::Round($item.Length / 1MB, 2)
        Write-Host "SUCCESS: Wasel_Admin_App.apk ($mb MB) copied to Desktop!"
    } else {
        throw "Admin APK not found at $adminApk"
    }
} finally {
    Pop-Location
}

Write-Host "`n================================================================"
Write-Host "BUILDING WASEL CAPTAIN APP RELEASE APK"
Write-Host "================================================================"
Push-Location flutter_driver_app
try {
    flutter build apk --release
    $captainApk = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $captainApk) {
        $destCaptain = Join-Path $destDir "Wasel_Captain_App.apk"
        Copy-Item -Path $captainApk -Destination $destCaptain -Force
        $item = Get-Item $destCaptain
        $mb = [math]::Round($item.Length / 1MB, 2)
        Write-Host "SUCCESS: Wasel_Captain_App.apk ($mb MB) copied to Desktop!"
    } else {
        throw "Captain APK not found at $captainApk"
    }
} finally {
    Pop-Location
}

Write-Host "`n================================================================"
Write-Host "ALL REQUESTED APKS BUILT AND DEPLOYED SUCCESSFULLY!"
Write-Host "================================================================"
Get-ChildItem -Path $destDir -Filter "Wasel_*.apk" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
