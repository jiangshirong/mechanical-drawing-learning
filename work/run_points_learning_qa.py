"""Real launcher, owned off-screen processes, viewport-only input, isolated drafts."""
import json
import hashlib
import subprocess
import time
from pathlib import Path
import run_map_qa as qa

started = time.time()
app = qa.APP
user = Path.home() / "AppData/Roaming/Godot/app_userdata/机械制图学习"
user.mkdir(parents=True, exist_ok=True)
def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
original_saves = {name:fingerprint(user/name) for name in ["practice-v1.json","observation-v1.json"]}
def run(flag,filename,timeout=120):
    qa.launch(flag,timeout)
    log = (app / "runtime/latest-run.log").read_text(encoding="utf-8")
    (app / "qa" / (filename.replace('.json','.log'))).write_text(log,encoding="utf-8")
    assert "SCRIPT ERROR" not in log and "ERROR:" not in log,log
    return qa.report(filename,started)
for name in ["qa-practice-v1.json", "qa-points-observation.json"]:
    (user / name).unlink(missing_ok=True)
(user / "qa-practice-corrupt.json").write_text('{"schema_version":1,"lines": BROKEN',encoding="utf-8")
try:
    count = run("--qa-points-check","points-learning-check.json",180)
    reopened = run("--qa-points-reopen","points-reopen.json",40)
    corrupt = run("--qa-points-corrupt","points-corrupt.json",40)
    fresh = run("--qa-points-fresh-guide","points-fresh-guide.json",40)
    assert {name:fingerprint(user/name) for name in original_saves} == original_saves, "User saves changed"
    print(json.dumps({"practice_and_presentations":count,"reopen":reopened,"corrupt":corrupt,"fresh_concept":fresh,"user_saves_unchanged":True,"processes":qa.RECORDS},ensure_ascii=False))
finally:
    (app / "qa/points-process-check.json").write_text(json.dumps(qa.RECORDS,ensure_ascii=False,indent=2),encoding="utf-8")
