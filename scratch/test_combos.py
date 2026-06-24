import zipfile
import subprocess
import os
import shutil

def export_pck():
    godot_path = r"C:\Users\alexh\Downloads\Godot_v3.5-rc5-vita.exe"
    pck_name = "VitaHockey.pck"
    if os.path.exists(pck_name):
        os.remove(pck_name)
    print("Exporting PCK pack...")
    p = subprocess.Popen([
        godot_path, "--path", ".", "--no-window",
        "--export-pack", "PlayStation Vita", pck_name
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p.communicate()
    if not os.path.exists(pck_name):
        raise Exception("Failed to export PCK pack!")
    return pck_name

def build_combo_1():
    # Replaces ONLY game.pck in the working demo
    print("\n--- Building Combo 1 (Unmodified Demo Metadata, Our game.pck) ---")
    pck_name = export_pck()
    demo_vpk = r"C:\Users\alexh\Downloads\maximilien-adventure-godot-demo.vpk"
    output_vpk = "VitaHockey.vpk"
    
    if os.path.exists(output_vpk):
        os.remove(output_vpk)
        
    with zipfile.ZipFile(output_vpk, "w", zipfile.ZIP_DEFLATED) as out_zip:
        with zipfile.ZipFile(demo_vpk, "r") as in_zip:
            for item in in_zip.infolist():
                if item.filename == "game_data/game.pck":
                    continue
                data = in_zip.read(item.filename)
                out_zip.writestr(item, data)
        # Write our PCK
        with open(pck_name, "rb") as f:
            out_zip.writestr("game_data/game.pck", f.read())
            
    if os.path.exists(pck_name):
        os.remove(pck_name)
    print("Combo 1 built successfully as VitaHockey.vpk.")

def build_combo_2():
    # Replaces ONLY param.sfo and icon0.png in the working demo (keeps original demo game.pck)
    print("\n--- Building Combo 2 (Our Metadata, Unmodified Demo game.pck) ---")
    demo_vpk = r"C:\Users\alexh\Downloads\maximilien-adventure-godot-demo.vpk"
    output_vpk = "VitaHockey.vpk"
    
    # Read and modify param.sfo
    print("Extracting and modifying param.sfo from demo...")
    param_sfo_data = None
    with zipfile.ZipFile(demo_vpk, "r") as z:
        param_sfo_data = z.read("sce_sys/param.sfo")
    param_sfo_data = param_sfo_data.replace(b"GDOT00001", b"VTAH00001")
    param_sfo_data = param_sfo_data.replace(b"Godot Engine", b"VitaHockey\x00\x00")
    param_sfo_data = param_sfo_data.replace(b"00.00", b"01.00")
    
    if os.path.exists(output_vpk):
        os.remove(output_vpk)
        
    with zipfile.ZipFile(output_vpk, "w", zipfile.ZIP_DEFLATED) as out_zip:
        with zipfile.ZipFile(demo_vpk, "r") as in_zip:
            for item in in_zip.infolist():
                if item.filename in ["sce_sys/param.sfo", "sce_sys/icon0.png"]:
                    continue
                data = in_zip.read(item.filename)
                out_zip.writestr(item, data)
        # Write our SFO
        out_zip.writestr("sce_sys/param.sfo", param_sfo_data)
        # Write our Icon
        with open("assets/vita/bubble_icon_128x128.png", "rb") as f:
            out_zip.writestr("sce_sys/icon0.png", f.read())
            
    print("Combo 2 built successfully as VitaHockey.vpk.")

def build_combo_3():
    # Replaces ONLY game.pck in the 3.5.rc5 template VPK, keeping demo's unmodified param.sfo and icon0.png
    print("\n--- Building Combo 3 (3.5.rc5 templates, Unmodified Demo Metadata, Our game.pck) ---")
    pck_name = export_pck()
    demo_vpk = r"C:\Users\alexh\Downloads\maximilien-adventure-godot-demo.vpk"
    template_zip_path = os.path.expandvars(r"%APPDATA%\Godot\templates\3.5.rc5\vita_release.zip")
    output_vpk = "VitaHockey.vpk"
    
    if os.path.exists(output_vpk):
        os.remove(output_vpk)
        
    with zipfile.ZipFile(output_vpk, "w", zipfile.ZIP_DEFLATED) as out_zip:
        # Copy executable and modules from 3.5.rc5 template
        with zipfile.ZipFile(template_zip_path, "r") as temp_zip:
            for item in temp_zip.infolist():
                if item.filename.startswith("sce_sys/livearea"):
                    continue
                data = temp_zip.read(item.filename)
                out_zip.writestr(item, data)
                
        # Copy param.sfo and icon0.png from working demo VPK (GDOT00001)
        with zipfile.ZipFile(demo_vpk, "r") as in_zip:
            out_zip.writestr("sce_sys/param.sfo", in_zip.read("sce_sys/param.sfo"))
            out_zip.writestr("sce_sys/icon0.png", in_zip.read("sce_sys/icon0.png"))
            
        # Write our PCK
        with open(pck_name, "rb") as f:
            out_zip.writestr("game_data/game.pck", f.read())
            
    if os.path.exists(pck_name):
        os.remove(pck_name)
    print("Combo 3 built successfully as VitaHockey.vpk.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2 or sys.argv[1] not in ["1", "2", "3"]:
        print("Usage: python test_combos.py [1, 2, or 3]")
    elif sys.argv[1] == "1":
        build_combo_1()
    elif sys.argv[1] == "2":
        build_combo_2()
    else:
        build_combo_3()
