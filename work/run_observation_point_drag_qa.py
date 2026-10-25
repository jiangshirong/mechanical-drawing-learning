import json
import time
import run_map_qa as h

started = time.time()
try:
    h.launch("--qa-observation-point-drag", 120)
    print(h.report("observation-point-drag-check.json", started))
finally:
    (h.APP / "qa/observation-point-drag-process.json").write_text(json.dumps(h.RECORDS, ensure_ascii=False, indent=2), encoding="utf-8")
