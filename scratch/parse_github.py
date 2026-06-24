import json
import os
import re

def main():
    path = r"C:\Users\alexh\.gemini\antigravity\brain\8bc0ecc3-34d6-4165-b3e1-3a54bbe5f08c\.system_generated\steps\1355\content.md"
    if not os.path.exists(path):
        print("File not found:", path)
        return
        
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()
        
    # Find the react-app.embeddedData script content
    marker = 'data-target="react-app.embeddedData">'
    idx = html.find(marker)
    if idx == -1:
        print("Could not find script marker!")
        return
        
    start = idx + len(marker)
    end = html.find("</script>", start)
    json_str = html[start:end].strip()
    
    data = json.loads(json_str)
    payload = data.get("payload", {})
    
    out_lines = []
    
    def search_recursive(obj, path=""):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k in ["title", "body", "markdown", "bodyText"] and isinstance(v, str) and len(v.strip()) > 0:
                    out_lines.append(f"{path}.{k} = {v}\n" + "-"*40)
                else:
                    search_recursive(v, f"{path}.{k}" if path else k)
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                search_recursive(item, f"{path}[{i}]")
                
    search_recursive(payload)
    
    out_path = r"c:\Users\alexh\Documents\VitaHockey\scratch\extracted_issue.txt"
    with open(out_path, "w", encoding="utf-8") as out_f:
        out_f.write("\n".join(out_lines))
        
    print("Extraction completed. Written to", out_path)

if __name__ == "__main__":
    main()
