import zipfile
import subprocess
import os
import shutil

def main():
    print("--- Build All VPKs Utility ---")
    godot_path = r"C:\Users\alexh\Downloads\Godot_v3.5-rc5-vita.exe"
    pck_name = "VitaHockey.pck"
    demo_vpk_path = r"C:\Users\alexh\Downloads\maximilien-adventure-godot-demo.vpk"
    template_zip_path = os.path.expandvars(r"%APPDATA%\Godot\templates\3.5.rc5\vita_release.zip")
    
    # 1. Clean old PCK
    if os.path.exists(pck_name):
        os.remove(pck_name)
        
    # 2. Export PCK
    print("Exporting PCK pack using Godot editor...")
    p = subprocess.Popen([
        godot_path, "--path", ".", "--no-window",
        "--export-pack", "PlayStation Vita", pck_name
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, err = p.communicate()
    
    if not os.path.exists(pck_name):
        print("STDOUT:", out)
        print("STDERR:", err)
        raise Exception("Failed to export PCK pack!")
    print(f"PCK successfully exported ({os.path.getsize(pck_name)} bytes).")
    
    # 3. Read param.sfo from the working demo VPK
    print("Reading param.sfo from working demo VPK...")
    demo_param_sfo = None
    with zipfile.ZipFile(demo_vpk_path, "r") as z:
        demo_param_sfo = z.read("sce_sys/param.sfo")
        demo_icon = z.read("sce_sys/icon0.png")
        
    # Create patched SFO for standard build
    print("Creating patched SFO data...")
    patched_param_sfo = demo_param_sfo.replace(b"GDOT00001", b"VTAH00001")
    patched_param_sfo = patched_param_sfo.replace(b"Godot Engine", b"VitaHockey\x00\x00")
    patched_param_sfo = patched_param_sfo.replace(b"00.00", b"01.00")
    
    # Standard custom icon
    with open(r"assets/vita/bubble_icon_128x128.png", "rb") as f:
        custom_icon = f.read()

    # 4. Helper function to package a VPK
    def package_vpk(output_vpk, sfo_data, icon_data):
        print(f"Packaging {output_vpk}...")
        if os.path.exists(output_vpk):
            os.remove(output_vpk)
            
        with zipfile.ZipFile(output_vpk, "w", zipfile.ZIP_DEFLATED) as out_zip:
            # Copy all files from template zip
            with zipfile.ZipFile(template_zip_path, "r") as temp_zip:
                for item in temp_zip.infolist():
                    if item.filename.startswith("sce_sys/livearea"):
                        continue
                    data = temp_zip.read(item.filename)
                    out_zip.writestr(item, data)
            
            # Add game.pck
            with open(pck_name, "rb") as f:
                out_zip.writestr("game_data/game.pck", f.read())
                
            # Add param.sfo
            out_zip.writestr("sce_sys/param.sfo", sfo_data)
            
            # Add icon0.png
            out_zip.writestr("sce_sys/icon0.png", icon_data)
        print(f"Finished building {output_vpk} ({os.path.getsize(output_vpk)} bytes).")

    # 5. Build Standard (VitaHockey, VTAH00001)
    package_vpk("VitaHockey.vpk", patched_param_sfo, custom_icon)
    
    # 6. Build Combo 3 (Godot Engine, GDOT00001)
    package_vpk("VitaHockey_combo3.vpk", demo_param_sfo, demo_icon)
    
    # Clean up PCK
    if os.path.exists(pck_name):
        os.remove(pck_name)
    print("Done! Both VPKs are ready in the root folder.")

if __name__ == "__main__":
    main()
