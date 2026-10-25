"""Exercise the real launcher with internal Godot input and isolated saves."""
import ctypes
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "机械制图学习"
RECORDS = []

def snapshot():
    # Native process enumeration avoids a stalled WMI service blocking QA cleanup.
    import psutil
    rows=[]
    for p in psutil.process_iter(['pid','name']):
        try:
            if (p.info['name'] or '').lower().startswith('godot'):
                rows.append(dict(ProcessId=p.pid,CreationDate=p.create_time(),CommandLine=' '.join(p.cmdline())))
        except (psutil.NoSuchProcess,psutil.AccessDenied):
            continue
    return rows


def request_close(pid):
    callback_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    @callback_type
    def visit(window, _):
        owner = ctypes.c_ulong()
        ctypes.windll.user32.GetWindowThreadProcessId(ctypes.c_void_p(window), ctypes.byref(owner))
        if owner.value == pid:
            ctypes.windll.user32.PostMessageW(ctypes.c_void_p(window), 0x0010, 0, 0)
        return True
    ctypes.windll.user32.EnumWindows(visit, 0)

def launch(flag, timeout=120, extra=()):
    before = {row["ProcessId"] for row in snapshot()}
    hidden = subprocess.STARTUPINFO()
    hidden.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    hidden.wShowWindow = 0
    subprocess.run(["cmd.exe", "/d", "/c", str(APP / "开始学习.cmd"), "--qa", flag, *extra], cwd=APP, creationflags=0x08000000, startupinfo=hidden, check=True)
    owned = {}
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        rows = snapshot()
        for row in rows:
            if row["ProcessId"] not in before and flag in (row.get("CommandLine") or ""):
                owned[row["ProcessId"]] = row
        live = [row for row in rows if row["ProcessId"] in owned and row["CreationDate"] == owned[row["ProcessId"]]["CreationDate"]]
        if owned and not live:
            RECORDS.append({"flag": flag, "owned_processes": list(owned), "normal_exit": True, "remaining": []})
            return
        time.sleep(1)
    # Ask only this run's exact processes to close normally before any forced cleanup.
    for row in live:
        request_close(row["ProcessId"])
    time.sleep(5)
    remaining = [row for row in snapshot() if row["ProcessId"] in owned and row["CreationDate"] == owned[row["ProcessId"]]["CreationDate"]]
    for row in remaining:
        subprocess.run(["powershell.exe", "-NoProfile", "-Command", f"Stop-Process -Id {row['ProcessId']} -Force"], capture_output=True, creationflags=0x08000000)
    RECORDS.append({"flag": flag, "owned_processes": list(owned), "normal_exit": False, "close_requested": True, "forced_cleanup": [row["ProcessId"] for row in remaining]})
    raise RuntimeError(f"Acceptance timeout: {flag}")

def report(filename, since):
    path = APP / "qa" / filename
    assert path.stat().st_mtime >= since, f"Report is stale: {filename}"
    checks = json.loads(path.read_text(encoding="utf-8"))
    failures = [check for check in checks if not check["passed"]]
    assert not failures, failures
    return len(checks)

def main():
    started = time.time()
    map_only = "--map-only" in sys.argv
    try:
        with (APP / "qa/map-import.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen([str(APP / "runtime/godot.exe"), "--headless", "--editor", "--path", str(APP), "--import", "--quit"], stdout=log, stderr=log, creationflags=0x08000000)
            code = process.wait(timeout=40)
            RECORDS.append({"flag": "asset-import", "owned_processes": [process.pid], "normal_exit": code == 0, "remaining": []})
            assert code == 0, code
        assert "SCRIPT ERROR" not in (APP / "qa/map-import.log").read_text(encoding="utf-8")
        canvas_count = None
        if not map_only:
            launch("--qa-canvas-check")
            canvas_count = report("canvas-interaction-check.json", started)
        launch("--qa-map-check")
        count = report("knowledge-map-check.json", started)
        launch("--qa-map-reopen", 35)
        reopen_count = report("knowledge-map-reopen.json", started)
        regression_count = None
        if not map_only:
            launch("--qa-guide-check", 180)
            regression_count = report("guide-interaction-check.json", started)
        print(json.dumps({"canvas_checks": canvas_count, "map_checks": count, "reopen_checks": reopen_count, "regression_checks": regression_count, "processes": RECORDS}, ensure_ascii=False), flush=True)
    finally:
        process_report = "knowledge-label-process-check.json" if map_only else "canvas-process-check.json"
        (APP / "qa" / process_report).write_text(json.dumps(RECORDS, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
