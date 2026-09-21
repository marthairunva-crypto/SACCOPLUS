# Convert PNG to ICO for Windows app icon
Add-Type -AssemblyName System.Drawing

$pngPath = "assets\images\logo2.png"
$icoPath = "windows\runner\resources\app_icon.ico"

# Load the PNG image
$image = [System.Drawing.Image]::FromFile((Resolve-Path $pngPath))

# Create icon with multiple sizes (256, 128, 64, 48, 32, 16)
$sizes = @(256, 128, 64, 48, 32, 16)
$icons = @()

foreach ($size in $sizes) {
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($image, 0, 0, $size, $size)
    $graphics.Dispose()
    
    $memoryStream = New-Object System.IO.MemoryStream
    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $icons += ,@($memoryStream.ToArray())
    $memoryStream.Dispose()
    $bitmap.Dispose()
}

$image.Dispose()

# Create ICO file
$icoStream = [System.IO.File]::Create($icoPath)

# ICO header
$icoStream.Write([byte[]]@(0, 0, 1, 0), 0, 4)  # Reserved, Type (1 = ICO)
$icoStream.Write([BitConverter]::GetBytes([uint16]$sizes.Count), 0, 2)  # Number of images

$offset = 6 + ($sizes.Count * 16)  # Header + directory entries

# Write directory entries
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $size = $sizes[$i]
    $iconData = $icons[$i]
    
    $icoStream.WriteByte([byte]($size -eq 256 ? 0 : $size))  # Width (0 = 256)
    $icoStream.WriteByte([byte]($size -eq 256 ? 0 : $size))  # Height (0 = 256)
    $icoStream.WriteByte(0)  # Color palette
    $icoStream.WriteByte(0)  # Reserved
    $icoStream.Write([BitConverter]::GetBytes([uint16]1), 0, 2)  # Color planes
    $icoStream.Write([BitConverter]::GetBytes([uint16]32), 0, 2)  # Bits per pixel
    $icoStream.Write([BitConverter]::GetBytes([uint32]$iconData.Length), 0, 4)  # Size of image data
    $icoStream.Write([BitConverter]::GetBytes([uint32]$offset), 0, 4)  # Offset
    
    $offset += $iconData.Length
}

# Write icon data
foreach ($iconData in $icons) {
    $icoStream.Write($iconData, 0, $iconData.Length)
}

$icoStream.Close()

Write-Host "Icon created successfully at: $icoPath" -ForegroundColor Green
