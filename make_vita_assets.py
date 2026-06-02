import os
import sys
import subprocess

# Ensure Pillow is installed
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image, ImageDraw, ImageFont

# Define background color: Dark Blue Ice (#0f172a)
BG_COLOR = (15, 23, 42) 
TEXT_COLOR = (255, 255, 255) # White

os.makedirs("assets/vita", exist_ok=True)

def create_indexed_image(width, height, text, filename, draw_hockey_lines=True):
    # Create image in RGB mode
    img = Image.new("RGB", (width, height), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Try to load a default font
    try:
        font = ImageFont.load_default()
    except IOError:
        font = None
        
    if draw_hockey_lines:
        # Draw red line in center
        draw.line([(width // 2, 0), (width // 2, height)], fill=(239, 68, 68), width=max(1, width // 150))
        # Draw blue lines on sides
        draw.line([(width // 4, 0), (width // 4, height)], fill=(59, 130, 246), width=max(1, width // 150))
        draw.line([(3 * width // 4, 0), (3 * width // 4, height)], fill=(59, 130, 246), width=max(1, width // 150))
        
        # Draw central faceoff circle
        circle_rad = min(width, height) // 5
        draw.ellipse([
            (width // 2 - circle_rad, height // 2 - circle_rad),
            (width // 2 + circle_rad, height // 2 + circle_rad)
        ], outline=(59, 130, 246), width=max(1, width // 150))

    # Center text "VitaHockey"
    try:
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_w = text_bbox[2] - text_bbox[0]
        text_h = text_bbox[3] - text_bbox[1]
    except AttributeError:
        # Fallback for older Pillow versions
        text_w, text_h = draw.textsize(text, font=font)
        
    text_x = (width - text_w) // 2
    text_y = (height - text_h) // 2
    draw.text((text_x, text_y), text, fill=TEXT_COLOR, font=font)
    
    # Convert to 8-bit indexed image (Palette 'P')
    indexed_img = img.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
    indexed_img.save(filename, "PNG")
    print(f"Created 8-bit indexed PNG: {filename} ({width}x{height})")

# Generate the 4 required LiveArea assets with exact sizes
create_indexed_image(128, 128, "VH", "assets/vita/bubble_icon_128x128.png", draw_hockey_lines=False)
create_indexed_image(960, 544, "VitaHockey", "assets/vita/app_splash_960x544.png")
create_indexed_image(840, 500, "VitaHockey", "assets/vita/livearea_bg_840x500.png")
create_indexed_image(280, 158, "Start", "assets/vita/livearea_startup_button_280x158.png", draw_hockey_lines=False)
