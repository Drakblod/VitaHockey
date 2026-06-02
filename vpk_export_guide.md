# PlayStation Vita Export & Installation Guide

This guide describes how to export the **VitaHockey** game as a VPK package using the Godot 3.5 Vita export templates, and how to install it on a homebrew-enabled PlayStation Vita.

---

## Prerequisites

1. **Godot Engine 3.5 (Vita-compatible build)**:
   - Ensure you are using the SonicMastr port of Godot Engine 3.5.
2. **Export Templates**:
   - Make sure you have installed the Vita export templates. These are typically packaged as a `.tpz` or zip file and installed via Godot's export template manager.
3. **Pillow/Python**:
   - Run the included `make_vita_assets.py` script once to ensure all mandatory LiveArea assets are generated as 8-bit indexed PNGs under `assets/vita/`.

---

## Step 1: Generate Assets

Ensure that the assets are correctly generated in the `assets/vita/` folder. They must be 8-bit indexed PNGs to prevent VPK parser crashes or installation failures in VitaShell.

You can generate/regenerate them by running:
```bash
python make_vita_assets.py
```

---

## Step 2: Export VPK from Godot

### Method A: Via Godot Editor UI
1. Open the project in the Godot 3.5 Vita-compatible editor.
2. Go to **Project** -> **Export...**
3. Select the **PlayStation Vita** preset.
4. Click **Export Project** at the bottom.
5. Choose the output destination and set the filename (e.g., `VitaHockey.vpk`).
6. Click **Save** to compile and pack the VPK.

### Method B: Via Command Line
If Godot is available in your PATH, you can export directly from the terminal:
```powershell
godot --no-window --export "PlayStation Vita" VitaHockey.vpk
```

---

## Step 3: Install VPK on the PS Vita

### Method A: Transfer via USB (VitaShell)
1. Launch **VitaShell** on your PS Vita.
2. Connect the Vita to your PC using a USB cable.
3. Press the **Select** button in VitaShell to activate the USB connection (make sure USB connection mode is set to USB in VitaShell settings, accessible by pressing **Start**).
4. On your PC, the Vita's memory card will appear as a USB drive.
5. Copy the exported `VitaHockey.vpk` file to any directory on the Vita (e.g., `ux0:data/` or root).
6. Press the **Circle** button on the Vita to disable the USB connection and unplug the cable.
7. In VitaShell, navigate to the folder where you copied `VitaHockey.vpk`.
8. Highlight `VitaHockey.vpk` and press **Cross**.
9. Confirm the installation prompts. VitaShell will extract and install the bubble.
10. Once installation is complete, press **Home (PlayStation button)** to return to the LiveArea, locate the **VitaHockey** bubble, and launch it!

### Method B: Transfer via FTP (VitaShell)
1. Launch **VitaShell** on your PS Vita.
2. Make sure your Vita and PC are connected to the same Wi-Fi network.
3. Press **Select** (ensure connection mode is set to FTP in VitaShell settings).
4. VitaShell will display an IP address and port (e.g., `ftp://192.168.1.100:1337`).
5. Open an FTP client on your PC (such as FileZilla) or use Windows File Explorer, and connect to the displayed address.
6. Transfer `VitaHockey.vpk` to the Vita (typically to `ux0:data/`).
7. Once transfer is complete, press **Circle** on the Vita to close the FTP connection.
8. In VitaShell, navigate to the location of the `.vpk` file, highlight it, and press **Cross** to install it.
9. Launch from the Vita LiveArea.
