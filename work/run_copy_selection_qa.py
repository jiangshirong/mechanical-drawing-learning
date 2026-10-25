"""Native text selection/copy through Viewport events, independent offscreen saves."""
import json,time
import run_map_qa as qa
started=time.time()
try:
    qa.launch('--qa-line-learning',90,('--qa-copy-only',))
    print(qa.report('copy-selection-check.json',started),'checks passed')
finally:
    (qa.APP/'qa/copy-selection-process-check.json').write_text(json.dumps(dict(processes=qa.RECORDS,system_mouse_moved=False,drag_timer_native_cursor_not_simulated=True),indent=2),encoding='utf-8')
