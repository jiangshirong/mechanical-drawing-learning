"""Compare actual rendered points and label/ball occlusion, without desktop input."""
import json
import subprocess
import sys
import time
import run_map_qa as harness

stage = "before" if "--before" in sys.argv else "after"
app = harness.APP
started = time.time()
try:
    with (app / "qa/point-quality-import.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([str(app / "runtime/godot.exe"), "--headless", "--editor", "--path", str(app), "--import", "--quit"], stdout=log, stderr=log, creationflags=0x08000000)
        code = process.wait(timeout=40)
        harness.RECORDS.append({"flag":"asset-import", "owned_processes":[process.pid], "normal_exit":code == 0, "remaining":[]})
        assert code == 0, code
    assert "SCRIPT ERROR" not in (app / "qa/point-quality-import.log").read_text(encoding="utf-8")
    harness.launch("--qa-point-quality-check", 180, ("--before",) if stage == "before" else ())
    count = harness.report(f"point-quality-{stage}.json", started)
    print(json.dumps({"stage":stage, "checks":count, "processes":harness.RECORDS}, ensure_ascii=False), flush=True)
finally:
    (app / f"qa/point-quality-{stage}-process.json").write_text(json.dumps(harness.RECORDS, ensure_ascii=False, indent=2), encoding="utf-8")
