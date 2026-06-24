import json
import os

def main():
    log_path = r"C:\Users\alexh\.gemini\antigravity\brain\8bc0ecc3-34d6-4165-b3e1-3a54bbe5f08c\.system_generated\logs\transcript.jsonl"
    if not os.path.exists(log_path):
        print("Log file not found.")
        return
        
    with open(log_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    print(f"Total lines: {len(lines)}")
    
    # We want to print user messages and assistant messages starting from step 1200 to 1483
    for idx, line in enumerate(lines):
        if 1200 <= idx <= 1483:
            try:
                data = json.loads(line)
                stype = data.get("type")
                if stype in ["USER_INPUT", "PLANNER_RESPONSE"]:
                    print(f"[{idx}] {stype}:")
                    print(data.get("content", "").strip())
                    print("="*60)
            except Exception as e:
                pass

if __name__ == "__main__":
    main()
