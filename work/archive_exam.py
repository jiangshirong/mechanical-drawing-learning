"""One-time, hash-aware source archive. No generated redraws of exam figures."""
from pathlib import Path
import hashlib,json,re,shutil
import pdfplumber

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parent/'工程制图—试卷'/'工程制图试卷合订本(AI处理).pdf'
OUT=ROOT/'学习资料'/'题集识别'
SETS=[(1,6),(7,11),(12,17),(18,22),(23,27),(28,32),(33,37),(38,43)]
def write(p,data):
 p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def kind(t):
 for words,tag in [('相贯','相贯线'),('截切 截交','截交线'),('螺纹 螺柱 螺栓','螺纹与连接'),('齿轮 啮合','齿轮'),('轴承','轴承'),('读零件 读端盖 读齿轮 釜盖','零件图'),('断面','断面'),('剖视 全剖 半剖','剖视'),('第三视图 第三面 两视图 缺线 图线','补视图与补线'),('点 平面 直线 水平线 投影','点线面投影')]:
  if any(w in t for w in words.split()):return tag
 return '待细分'
def main():
 sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
 manifest=OUT/'题集索引.json'
 if manifest.exists() and json.loads(manifest.read_text(encoding='utf-8'))['source']['sha256']==sha:
  print('Archive unchanged; using cached index.');return
 for d in ['原页','文字定位','题图','ocr原始','答案来源']:(OUT/d).mkdir(parents=True,exist_ok=True)
 shutil.copy2(SOURCE,OUT/'原题合订本.pdf')
 pages=[];questions=[];current=None;qn=0;last_set=0
 with pdfplumber.open(SOURCE) as pdf:
  for n,page in enumerate(pdf.pages,1):
   s=next(i+1 for i,(a,b) in enumerate(SETS) if a<=n<=b)
   if s!=last_set:current=None;qn=0;last_set=s
   text=page.extract_text(layout=False) or ''
   lines=page.extract_text_lines()
   raw={'pdf_page':n,'paper':s,'width_pt':page.width,'height_pt':page.height,'text':text,'chars':[{'text':c['text'],'bbox':[c['x0'],c['top'],c['x1'],c['bottom']]} for c in page.chars],'words':page.extract_words(),'lines':lines,'review_status':'文字提取；题干经浏览核对，尺寸符号仍逐题核验'}
   write(OUT/'文字定位'/f'p{n:02}.json',raw)
   (OUT/'文字定位'/f'p{n:02}.txt').write_text(text,encoding='utf-8')
   image=page.to_image(resolution=150).original.convert('RGB')
   image.save(OUT/'原页'/f'p{n:02}.png')
   headings=[l for l in lines if re.match(r'^[一二三四五六七八九十]+[、.．]',l['text'].strip())]
   bounds=[(h,h['top']/page.height) for h in headings]
   if current and (not bounds or bounds[0][1]>.12):
    current['pages'].append(n)
    end=bounds[0][1] if bounds else .98
    if end>.13:
     box=[.03,.025,.97,max(.03,end-.008)]
     crop=OUT/'题图'/f'{current["id"]}-p{n:02}.png'
     image.crop(tuple(int(a*b) for a,b in zip(box,[image.width,image.height,image.width,image.height]))).save(crop)
     current['regions'].append({'page':n,'box_normalized':box,'image':crop.relative_to(OUT).as_posix(),'continuation':True})
   for j,(h,top) in enumerate(bounds):
    qn+=1;end=bounds[j+1][1]-.009 if j+1<len(bounds) else .98
    block='\n'.join(l['text'] for l in lines if l['top']>=h['top']-.5 and l['top']/page.height<end)
    # Footer is source metadata, not part of a question task.
    block=re.sub(r'第\s*\d+\s*页\s*共\s*\d+\s*页','',block).strip()
    pts=re.findall(r'(\d+)\s*分',h['text'])
    current={'id':f't{s:02}-q{qn:02}','paper':s,'question':qn,'task':block,'heading':h['text'],'points_candidates':pts,'category':kind(block),'pages':[n],'subparts':[l['text'] for l in lines if h['top']<=l['top']<end*page.height and re.match(r'^(?:[1-9][.．]|[（(]\s*[1-9])',l['text'])],'regions':[],'status':'题干已提取；原图已归档；几何与答案另行核验'}
    box=[.03,max(0,top-.008),.97,end]
    crop=OUT/'题图'/f'{current["id"]}-p{n:02}.png'
    image.crop(tuple(int(a*b) for a,b in zip(box,[image.width,image.height,image.width,image.height]))).save(crop)
    current['regions'].append({'page':n,'box_normalized':box,'image':crop.relative_to(OUT).as_posix()})
    questions.append(current)
   pages.append({'page':n,'paper':s,'page_image':f'原页/p{n:02}.png','text':f'文字定位/p{n:02}.txt','positions':f'文字定位/p{n:02}.json','ocr':f'ocr原始/p{n:02}.json'})
 index={'schema_version':1,'source':{'file':str(SOURCE),'sha256':sha,'local_copy':'原题合订本.pdf','pages':43,'note':'用户已裁去答案，仅保留题目。印刷页码总数沿用原卷，不代表缺页。'},'sets':[{'paper':i+1,'pdf_pages':[a,b]} for i,(a,b) in enumerate(SETS)],'pages':pages,'questions':questions,'information_classes':['原题核实事实','提取或OCR候选','教学设定','待核项']}
 write(manifest,index)
 (OUT/'阅读说明.md').write_text('# 试卷档案读取顺序\n\n先查题集索引，再读对应文字定位与 OCR。题干可搜索，图形用题图或原页核对。OCR 是候选，不是答案。\n\n43 页是用户保留的题目，原卷答案已裁去。每套原印刷总页数保留，不记为缺页。全部原页与题图保留原像素关系，无生成式重绘。\n\n只有新来源哈希或具体疑点需要重新识别。首次生成 OCR 后直接读缓存。首期六题的参数、事实和教学设定见程序 assets/catalog.json；答案出处见答案来源目录。其余题型仅归档，不表示已经实现。\n',encoding='utf-8')
 print(json.dumps({'pages':len(pages),'papers':8,'questions':len(questions),'sha256':sha},ensure_ascii=False))
if __name__=='__main__':main()
