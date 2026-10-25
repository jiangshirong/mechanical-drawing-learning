import json,subprocess,time,sys
from pathlib import Path
APP=Path(__file__).resolve().parents[1]/'机械制图学习'
def snapshot():
    cmd="Get-CimInstance Win32_Process -Filter \"Name like 'godot%'\" | Select-Object ProcessId,CreationDate,CommandLine | ConvertTo-Json -Compress"
    p=subprocess.run(['powershell.exe','-NoProfile','-Command',cmd],capture_output=True,text=True,encoding='utf-8',errors='replace',creationflags=0x08000000,check=True)
    obj=json.loads(p.stdout) if p.stdout.strip() else []
    return obj if isinstance(obj,list) else [obj]
stage=sys.argv[1]
with (APP/'qa/render-import.log').open('w',encoding='utf-8') as log:
    child=subprocess.Popen([str(APP/'runtime/godot.exe'),'--headless','--editor','--path',str(APP),'--import','--quit'],stdout=log,stderr=log,creationflags=0x08000000)
    assert child.wait(40)==0
assert 'SCRIPT ERROR' not in (APP/'qa/render-import.log').read_text(encoding='utf-8'), 'Godot import failed'
started=time.time()
before={p['ProcessId'] for p in snapshot()}
hidden=subprocess.STARTUPINFO();hidden.dwFlags|=subprocess.STARTF_USESHOWWINDOW;hidden.wShowWindow=0
args=['cmd.exe','/d','/c',str(APP/'开始学习.cmd'),'--qa','--qa-render-bench']
if stage=='after':args.append('--after')
subprocess.run(args,cwd=APP,creationflags=0x08000000,startupinfo=hidden,check=True)
owned={};deadline=time.monotonic()+100
while time.monotonic()<deadline:
    rows=snapshot()
    for p in rows:
        if p['ProcessId'] not in before and '--qa-render-bench' in (p.get('CommandLine') or ''):owned[p['ProcessId']]=p
    live=[p for p in rows if p['ProcessId'] in owned and p['CreationDate']==owned[p['ProcessId']]['CreationDate']]
    if owned and not live:break
    time.sleep(1)
else:
    for p in live:
        subprocess.run(['powershell.exe','-NoProfile','-Command',f"Stop-Process -Id {p['ProcessId']} -Force"],capture_output=True,creationflags=0x08000000)
    raise RuntimeError('Render QA timeout; stopped only test-owned processes')
assert (APP/f'qa/render-{stage}.json').stat().st_mtime >= started, 'Stale render report'
report=json.loads((APP/f'qa/render-{stage}.json').read_text(encoding='utf-8'))
report['owned_processes']=list(owned);report['remaining']=[]
(APP/f'qa/render-{stage}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
