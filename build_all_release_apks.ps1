$ErrorActionPreference = "Stop"
$destDir = "C:\Users\kalifa\Desktop\Wasel_Android_APKs"
if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

$apps = @(
    @{ Name = "Customer"; Path = "flutter_mobile_app"; OutputName = "Wasel_Customer_App.apk" },
    @{ Name = "Captain";  Path = "flutter_driver_app"; OutputName = "Wasel_Captain_App.apk" },
    @{ Name = "Kitchen";  Path = "flutter_merchant_app"; OutputName = "Wasel_Kitchen_App.apk" },
    @{ Name = "Admin";    Path = "flutter_admin_app"; OutputName = "Wasel_Admin_App.apk" }
)

Write-Host "================================================================"
Write-Host "STARTING WASEL NALUT ALL-4 APKS PRODUCTION RELEASE BUILD"
Write-Host "Destination: $destDir"
Write-Host "================================================================"

foreach ($app in $apps) {
    $appName = $app.Name
    $appPath = $app.Path
    $outputName = $app.OutputName
    Write-Host "`nBuilding $appName App ($appPath)..."
    Push-Location $appPath
    try {
        flutter build apk --release
        $builtApk = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $builtApk) {
            $targetPath = Join-Path $destDir $outputName
            Copy-Item -Path $builtApk -Destination $targetPath -Force
            $fileItem = Get-Item $targetPath
            $sizeMb = [math]::Round($fileItem.Length / 1MB, 2)
            Write-Host "SUCCESS: Copied $outputName ($sizeMb MB) to Desktop"
        } else {
            Write-Error "Could not find built APK at $builtApk"
        }
    } finally {
        Pop-Location
    }
}

Write-Host "`n================================================================"
Write-Host "ALL 4 WASEL NALUT RELEASE APKS BUILT AND DEPLOYED SUCCESSFULLY!"
Write-Host "================================================================"
Get-ChildItem -Path $destDir -Filter "*.apk" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
