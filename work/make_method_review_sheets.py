"""Contact sheets from unchanged actual Godot renders for manual inspection."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
QA=Path(__file__).resolve().parents[1]/'机械制图学习/qa'
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
for suffix in ['normal','minimum']:
 path=QA/f'course-method-{suffix}.json'
 if not path.exists():continue
 data=json.loads(path.read_text(encoding='utf8'));chapters={}
 for p in data['pictures']:
  if p['stage'] in ['after','more-vertices','space-first','projections']:chapters.setdefault(p['beat'].split(':')[0],[]).append(p)
 for chapter,pics in chapters.items():
  for page in range(0,len(pics),6):
   rows=pics[page:page+6];out=Image.new('RGB',(1200,410*((len(rows)+1)//2)),'#dfe4e6');draw=ImageDraw.Draw(out)
   for i,p in enumerate(rows):
    image=Image.open(QA/p['file']).convert('RGB');image.thumbnail((600,375));x=i%2*600;y=i//2*410
    out.paste(image,(x,y+28));draw.text((x+5,y+5),p['beat']+' '+p['stage'],font=font,fill='#172d3b')
   out.save(QA/f'method-sheet-{chapter}-{page//6+1}-{suffix}.jpg',quality=93)
