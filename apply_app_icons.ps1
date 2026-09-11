Add-Type -AssemblyName System.Drawing

function Generate-AppIcons {
    param (
        [string]$AppName,
        [string]$AppPath,
        [string]$SourceIconPath
    )

    Write-Host "=================================================="
    Write-Host "Processing Icons for: $AppName"
    Write-Host "Source: $SourceIconPath"

    if (-not (Test-Path $SourceIconPath)) {
        Write-Error "Source icon not found: $SourceIconPath"
        return
    }

    # 1. Create assets/icon directory and save master 1024x1024 png
    $assetsIconDir = Join-Path $AppPath "assets\icon"
    if (-not (Test-Path $assetsIconDir)) {
        New-Item -ItemType Directory -Force -Path $assetsIconDir | Out-Null
    }
    $masterPngPath = Join-Path $assetsIconDir "app_icon.png"

    $sourceImg = [System.Drawing.Image]::FromFile($SourceIconPath)
    
    # Save master copy as PNG
    $masterBmp = New-Object System.Drawing.Bitmap($sourceImg, 1024, 1024)
    $masterBmp.Save($masterPngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $masterBmp.Dispose()
    Write-Host "  -> Master icon saved to: $masterPngPath"

    # 2. Resizing mapping for Android mipmap folders
    $sizes = @{
        "mipmap-mdpi"    = 48
        "mipmap-hdpi"    = 72
        "mipmap-xhdpi"   = 96
        "mipmap-xxhdpi"  = 144
        "mipmap-xxxhdpi" = 192
    }

    $resDir = Join-Path $AppPath "android\app\src\main\res"

    foreach ($entry in $sizes.GetEnumerator()) {
        $folderName = $entry.Key
        $dimension = $entry.Value

        $targetFolder = Join-Path $resDir $folderName
        if (-not (Test-Path $targetFolder)) {
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        }

        $targetFile = Join-Path $targetFolder "ic_launcher.png"

        $destBmp = New-Object System.Drawing.Bitmap($dimension, $dimension, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($destBmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $g.DrawImage($sourceImg, 0, 0, $dimension, $dimension)
        $g.Dispose()

        $destBmp.Save($targetFile, [System.Drawing.Imaging.ImageFormat]::Png)
        $destBmp.Dispose()

        Write-Host "  -> Generated $folderName/ic_launcher.png ($($dimension)x$($dimension))"
    }

    $sourceImg.Dispose()
    Write-Host "Done $AppName icons!"
}

$brainDir = "C:\Users\kalifa\.gemini\antigravity\brain\9ef8cf4f-1720-401b-836c-9e2bfe79c1ed"

# 1. Wasel Customer
Generate-AppIcons -AppName "Wasel Customer" `
                  -AppPath "C:\Users\kalifa\super_app_delivery\flutter_mobile_app" `
                  -SourceIconPath "$brainDir\wasel_customer_icon_1788776377367.jpg"

# 2. Wasel Captain
Generate-AppIcons -AppName "Wasel Captain" `
                  -AppPath "C:\Users\kalifa\super_app_delivery\flutter_driver_app" `
                  -SourceIconPath "$brainDir\wasel_captain_icon_1788776398004.jpg"

# 3. Wasel Merchant
Generate-AppIcons -AppName "Wasel Merchant" `
                  -AppPath "C:\Users\kalifa\super_app_delivery\flutter_merchant_app" `
                  -SourceIconPath "$brainDir\wasel_merchant_icon_1788776421827.jpg"

# 4. Wasel Admin
Generate-AppIcons -AppName "Wasel Admin" `
                  -AppPath "C:\Users\kalifa\super_app_delivery\flutter_admin_app" `
                  -SourceIconPath "$brainDir\wasel_admin_icon.png"

Write-Host "=================================================="
Write-Host "All 4 application launcher icons successfully updated!"
