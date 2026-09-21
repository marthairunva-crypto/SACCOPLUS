#!/usr/bin/env python3
"""Convert PNG to ICO for Windows app icon"""

try:
    from PIL import Image
    import os
    
    # Paths
    png_path = "assets/images/logo2.png"
    ico_path = "windows/runner/resources/app_icon.ico"
    
    # Load PNG
    img = Image.open(png_path)
    
    # Convert to RGBA if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Create icon with multiple sizes
    sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    
    # Save as ICO
    img.save(ico_path, format='ICO', sizes=sizes)
    
    print(f"✓ Icon created successfully at: {ico_path}")
    print(f"  Sizes: {', '.join([f'{s[0]}x{s[1]}' for s in sizes])}")
    
except ImportError:
    print("ERROR: PIL/Pillow not installed.")
    print("Install with: pip install Pillow")
    exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    exit(1)
