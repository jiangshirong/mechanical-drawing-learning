"""Run the real double-click launcher; track only processes created for this test."""
import json, subprocess, time, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'机械制图学习'
def snapshot():
    cmd="Get-CimInstance Win32_Process -Filter \"Name like 'godot%'\" | Select-Object ProcessId,CreationDate,CommandLine | ConvertTo-Json -Compress"
    p=subprocess.run(['powershell.exe','-NoProfile','-Command',cmd],capture_output=True,text=True,encoding='utf-8',errors='replace',creationflags=0x08000000,check=True)
    obj=json.loads(p.stdout) if p.stdout.strip() else []
    return obj if isinstance(obj,list) else [obj]

def launch(flag,timeout):
    before={p['ProcessId'] for p in snapshot()}
    hidden=subprocess.STARTUPINFO();hidden.dwFlags|=subprocess.STARTF_USESHOWWINDOW;hidden.wShowWindow=0
    subprocess.run(['cmd.exe','/d','/c',str(APP/'开始学习.cmd'),'--qa',flag]+sys.argv[1:],cwd=APP,creationflags=0x08000000,startupinfo=hidden,check=True)
    owned={}
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        rows=snapshot()
        for p in rows:
            if p['ProcessId'] not in before and flag in (p.get('CommandLine') or ''):owned[p['ProcessId']]=p
        live=[p for p in rows if p['ProcessId'] in owned and p['CreationDate']==owned[p['ProcessId']]['CreationDate']]
        if owned and not live:return {'flag':flag,'owned_processes':list(owned),'normal_exit':True,'remaining':[]}
        time.sleep(1)
    # Timeout cleanup is scoped to this test's PID and creation identity.
    for p in snapshot():
        if p['ProcessId'] in owned and p['CreationDate']==owned[p['ProcessId']]['CreationDate']:
            subprocess.run(['powershell.exe','-NoProfile','-Command',f"Stop-Process -Id {p['ProcessId']} -Force"],capture_output=True,creationflags=0x08000000)
    raise RuntimeError(f'QA timeout: {flag}; stopped only test-created processes')

records=[]
if '--qa-reopen-only' in sys.argv and (APP/'qa/guide-process-check.json').exists():
    records=json.loads((APP/'qa/guide-process-check.json').read_text(encoding='utf-8'))
started=time.time()
try:
    with (APP/'qa/guide-import.log').open('w',encoding='utf-8') as output:
        editor=subprocess.Popen([str(APP/'runtime/godot.exe'),'--headless','--editor','--path',str(APP),'--import','--quit'],stdout=output,stderr=output,creationflags=0x08000000)
        code=editor.wait(timeout=40)
        records.append({'flag':'asset-import','owned_processes':[editor.pid],'normal_exit':code==0,'remaining':[]})
        assert code==0,code
        assert "SCRIPT ERROR" not in (APP/"qa/guide-import.log").read_text(encoding="utf-8"), "Godot script import failed"
    if '--qa-reopen-only' not in sys.argv:
        records.append(launch('--qa-guide-check',180))
        assert (APP/'qa/guide-interaction-check.json').stat().st_mtime>=started,'QA did not write a fresh report'
    checks=json.loads((APP/'qa/guide-interaction-check.json').read_text(encoding='utf-8'))
    assert all(c['passed'] for c in checks),[c for c in checks if not c['passed']]
    records.append(launch('--qa-guide-reopen',30))
    reopened=json.loads((APP/'qa/guide-reopen.json').read_text(encoding='utf-8'))
    assert reopened['free_mode'] and reopened['guide_hidden'] and reopened['id']=='section' and reopened['guide_step']=='rib_convention',reopened
    assert reopened['qa_window_offscreen'] and reopened['qa_no_focus'],reopened
    print(json.dumps({'interaction_checks':len(checks),'reopen':reopened,'processes':records},ensure_ascii=False))
finally:
    (APP/'qa/guide-process-check.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
