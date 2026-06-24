import os
import shutil
import subprocess

def main():
    temp_dir = os.path.abspath("scratch/temp_project")
    os.makedirs(temp_dir, exist_ok=True)
    
    # Copy project.binary to the temp project
    src_binary = os.path.abspath("scratch/extracted_demo/project.binary")
    dest_binary = os.path.join(temp_dir, "project.binary")
    shutil.copy2(src_binary, dest_binary)
    print(f"Copied project.binary to {dest_binary}")
    
    # Write the GDScript converter
    gdscript_content = """extends SceneTree

func _init():
\tprint("GDScript starting inside temp project...")
\tvar err = ProjectSettings.save_custom("res://project.godot")
\tprint("Save custom returned: ", err)
\tquit()
"""
    script_path = os.path.join(temp_dir, "convert.gd")
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(gdscript_content)
    print(f"Written GDScript to {script_path}")
    
    # Run Godot headlessly to execute the script
    godot_path = r"C:\Users\alexh\Downloads\Godot_v3.5-rc5-vita.exe"
    print("Running Godot editor headlessly...")
    p = subprocess.Popen([
        godot_path, "--path", temp_dir, "--no-window", "-s", "res://convert.gd"
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, err = p.communicate()
    
    print("STDOUT:")
    print(out)
    print("STDERR:")
    print(err)
    
    output_godot = os.path.join(temp_dir, "project.godot")
    if os.path.exists(output_godot):
        print(f"Success! project.godot created at {output_godot}")
        # Copy back to extracted_demo
        shutil.copy2(output_godot, os.path.abspath("scratch/extracted_demo/project.godot"))
    else:
        print("Failed to generate project.godot.")

if __name__ == "__main__":
    main()
