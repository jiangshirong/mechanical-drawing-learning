"""Arrange unchanged render captures for inspection; not substitute renders."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
APP=Path(__file__).resolve().parents[1]/'机械制图学习';qa=APP/'qa'
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
for suffix in ['normal','minimum']:
    report=qa/f'course-beginner-{suffix}.json'
    if not report.exists():continue
    data=json.loads(report.read_text(encoding='utf8'))
    followup=qa/f'course-beginner-legacy-{suffix}.json'
    if followup.exists():
        pictures={p['file']:p for p in data['pictures']}
        pictures.update({p['file']:p for p in json.loads(followup.read_text(encoding='utf8'))['pictures']})
        data['pictures']=list(pictures.values())
    chapters={}
    for p in data['pictures']:
        if p['stage']=='settled':chapters.setdefault(p['beat'].split(':')[0],[]).append(p)
    for chapter,pics in chapters.items():
        for n in range(0,len(pics),6):
            page=pics[n:n+6];out=Image.new('RGB',(1200,398*((len(page)+1)//2)),'#dfe4e6');draw=ImageDraw.Draw(out)
            for i,p in enumerate(page):
                img=Image.open(qa/p['file']).convert('RGB');img.thumbnail((600,365))
                x=(i%2)*600;y=(i//2)*398;out.paste(img,(x,y+28));draw.text((x+5,y+5),p['beat'],font=font,fill='#172d3b')
            out.save(qa/f'beginner-sheet-{chapter}-{n//6+1}-{suffix}.jpg',quality=92)
