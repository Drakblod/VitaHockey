import zipfile
import subprocess
import os

def main():
    print("--- VPK Packager ---")
    godot_path = r"C:\Users\alexh\Downloads\Godot_v3.5-rc5-vita.exe"
    pck_name = "VitaHockey.pck"
    
    # 1. Clean old PCK
    if os.path.exists(pck_name):
        os.remove(pck_name)
        
    # 2. Export PCK
    print("Exporting PCK pack using Godot...")
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
    
    # 3. Read and modify param.sfo from the working demo VPK
    demo_vpk_path = r"C:\Users\alexh\Downloads\maximilien-adventure-godot-demo.vpk"
    old_vpk_path = "VitaHockey.vpk"
    backup_vpk_path = "VitaHockey.vpk.bak"
    
    print("Reading param.sfo from working demo VPK...")
    param_sfo_data = None
    with zipfile.ZipFile(demo_vpk_path, "r") as z:
        param_sfo_data = z.read("sce_sys/param.sfo")
        
    print("Modifying param.sfo metadata...")
    param_sfo_data = param_sfo_data.replace(b"GDOT00001", b"VTAH00001")
    param_sfo_data = param_sfo_data.replace(b"Godot Engine", b"VitaHockey\x00\x00")
    param_sfo_data = param_sfo_data.replace(b"00.00", b"01.00")
        
    # 4. Rename old VPK to backup
    print("Creating backup of old VPK...")
    if os.path.exists(old_vpk_path):
        if os.path.exists(backup_vpk_path):
            os.remove(backup_vpk_path)
        os.rename(old_vpk_path, backup_vpk_path)
    
    try:
        # 5. Package new VPK using 3.5.rc5 templates
        print("Packaging new VPK using 3.5.rc5 templates...")
        template_zip_path = os.path.expandvars(r"%APPDATA%\Godot\templates\3.5.rc5\vita_release.zip")
        
        with zipfile.ZipFile(old_vpk_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
            # Copy all files from the template zip except livearea folder
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
            out_zip.writestr("sce_sys/param.sfo", param_sfo_data)
            
            # Add icon0.png
            with open(r"assets/vita/bubble_icon_128x128.png", "rb") as f:
                out_zip.writestr("sce_sys/icon0.png", f.read())
                
        print("Success! New VitaHockey.vpk packaged successfully.")
        
    except Exception as e:
        print("Error encountered packaging VPK:", str(e))
        if os.path.exists(old_vpk_path):
            os.remove(old_vpk_path)
        os.rename(backup_vpk_path, old_vpk_path)
        raise e
        
    # Clean up PCK
    if os.path.exists(pck_name):
        os.remove(pck_name)

if __name__ == "__main__":
    main()
