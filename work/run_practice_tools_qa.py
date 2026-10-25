"""Practice name/coordinate/dimension/marquee checks without desktop input."""
import hashlib
import json
import time
from pathlib import Path
import run_map_qa as qa

started = time.time()
app = qa.APP
user = Path.home()/"AppData/Roaming/Godot/app_userdata/机械制图学习"
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
original = {n:digest(user/n) for n in ["practice-v1.json","observation-v1.json"]}
for name in ["qa-practice-tools.json","qa-practice-tools-observation.json"]:
    (user/name).unlink(missing_ok=True)
counts = {}
try:
    for flag,filename in [("--qa-practice-tools","practice-tools-check.json"),("--qa-practice-tools-reopen","practice-tools-reopen.json")]:
        qa.launch(flag,90)
        log = (app/"runtime/latest-run.log").read_text(encoding="utf-8")
        (app/"qa"/filename.replace(".json",".log")).write_text(log,encoding="utf-8")
        assert "SCRIPT ERROR" not in log and "ERROR:" not in log,log
        counts[filename] = qa.report(filename,started)
    assert {n:digest(user/n) for n in original} == original
    print(json.dumps({"checks":counts,"user_saves_unchanged":True,"processes":qa.RECORDS},ensure_ascii=False))
finally:
    (app/"qa/practice-tools-process.json").write_text(json.dumps(qa.RECORDS,ensure_ascii=False,indent=2),encoding="utf-8")
