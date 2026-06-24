import os
import shutil

def main():
    print("--- Cleaning Workspace Root ---")
    keep_files = [
        "project.godot",
        "export_presets.cfg",
        "VitaSmokeTest.tscn",
        "icon.png",
        "VitaHockey.vpk",
        "VitaHockey.vpk.bak",
        ".gitignore"
    ]
    keep_dirs = [
        "scratch",
        ".git",
        "original_src"
    ]
    
    root_dir = "."
    for item in os.listdir(root_dir):
        item_path = os.path.join(root_dir, item)
        if os.path.isdir(item_path):
            if item in keep_dirs:
                print(f"Keeping directory: {item}")
            else:
                print(f"Deleting directory: {item}")
                shutil.rmtree(item_path, ignore_errors=True)
        else:
            if item in keep_files:
                print(f"Keeping file: {item}")
            else:
                print(f"Deleting file: {item}")
                os.remove(item_path)
                
    print("Workspace cleaned.")

if __name__ == "__main__":
    main()
