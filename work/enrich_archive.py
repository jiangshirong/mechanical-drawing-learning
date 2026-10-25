"""Enrich from cached word boxes only: never re-render or re-OCR unchanged sources."""
from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'学习资料/题集识别'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
d=read(BASE/'题集索引.json')
for q in d['questions']:
 lines=[];sub=[]
 for region in q['regions']:
  page=read(BASE/'文字定位'/f"p{region['page']:02}.json")
  lo,hi=region['box_normalized'][1],region['box_normalized'][3]
  local=[l for l in page['lines'] if lo<=l['top']/page['height_pt']<hi and not re.search(r'第\s*\d+\s*页\s*共',l['text'])]
  lines.extend([l['text'] for l in local])
  # Extract individual word-level markers, including two subquestions on one line.
  for w in page['words']:
   if not lo<=w['top']/page['height_pt']<hi:continue
   text=w['text']
   match=re.search(r'[（(]([1-9])[）)]|^([1-9])[．.]',text)
   if not match:continue
   # Reject decimal dimensions such as 6.3.
   if re.match(r'^\d[.]\d',text):continue
   number=int(match.group(1) or match.group(2))
   if any(s['number']==number for s in sub):continue
   continuation=' '.join(v['text'] for v in page['words'] if abs(v['top']-w['top'])<4 and v['x0']>=w['x0'])
   sub.append({'id':q['id']+f'-s{number:02}','number':number,'page':region['page'],'marker_bbox_pt':[w['x0'],w['top'],w['x1'],w['bottom']],'text_candidate':continuation,'figure_region':region['image'],'status':'原文定位；图形小题共享本大题裁切'})
 q['task']='\n'.join(lines)
 for match in re.finditer(r'[（(]([1-9])[）)]',q['task']):
  number=int(match.group(1))
  if not any(s['number']==number for s in sub):
   region=q['regions'][0]
   sub.append({'id':q['id']+f'-s{number:02}','number':number,'page':region['page'],'text_candidate':q['task'][match.start():].split('\n')[0],'figure_region':region['image'],'position_region':region['box_normalized'],'status':'行内小题；用对应原文字框定位'})
 q['score_mentions']=[{'value':int(v),'context':context} for context in lines for v in re.findall(r'(\d+)\s*分',context)]
 # Total score is from initial prose, before subquestion labels or dimensional drawings.
 header=' '.join(lines[:4])
 m=re.search(r'[（(]\s*(\d+)\s*分',header)
 q['total_points']=int(m.group(1)) if m else None
 q['points_candidates']=re.findall(r'(\d+)\s*分',header)
 q['subquestions']=sorted(sub,key=lambda s:s['number'])
 q['recognition_candidates']=[{'page':p,'cache':f'ocr原始/p{p:02}.json','scope':'用regions坐标筛选字框；尺寸/符号候选未等同原题事实'} for p in sorted(set(q['pages']))]
 q['pending_checks']=[] if q['total_points'] else ['分值跨行或符号分离；回看题干局部核实']
 q['teaching_assumptions']=[]
 q['verified_facts']={'pdf_pages':sorted(set(q['pages'])),'question_number':q['question'],'answer_removed_by_user':True}
write(BASE/'题集索引.json',d)
rows=['# 全题索引','', '43 页、8 套、69 道大题；题干与续页来自缓存。识别候选保留坐标，尺寸符号未经逐字人工校对的项目不当作确证。','', '| 题目 | PDF页 | 分值 | 题型 | 小题编号 |','|---|---|---|---|---|']
for q in d['questions']:rows.append(f"| {q['id']} | {','.join(map(str,sorted(set(q['pages']))))} | {q['total_points'] if q['total_points'] is not None else '待核'} | {q['category']} | {','.join(str(s['number']) for s in q['subquestions']) or '无独立编号'} |")
(BASE/'全题索引.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
answers=[]
for n in [1,2,7]:
 matches=list(ROOT.parent.rglob(f'08sd{n}.doc'))
 if matches:
  p=matches[0]
  answers.append({'original':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'converted_cache':f'08sd{n}-source.pdf','conversion':'本机Word打开原DOC并导出PDF；原DOC未修改','matched_examples':{1:['points'],2:['line','plane','slope','base'],7:['bracket']}[n]})
write(BASE/'答案来源/来源记录.json',answers)
print({'questions':len(d['questions']),'subquestions':sum(len(q['subquestions']) for q in d['questions']),'scores_unresolved':[q['id'] for q in d['questions'] if q['total_points'] is None]})
