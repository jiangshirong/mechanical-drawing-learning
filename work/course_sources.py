"""Developer-only source references and the original/modern convention boundary."""
from course_geometry import *
from PIL import Image
import pymupdf
import hashlib

ANSWER_PAGES={'t01-q03':[8],'t01-q04':[8,9],'t01-q05':[9],'t01-q06':[10],'t01-q07':[10],'t01-q08':[11],'t01-q09':[11,12],
't02-q03':[7],'t02-q06':[9],'t02-q07':[9],'t02-q08':[10,11],
't03-q04':[9],'t03-q05':[9],'t03-q06':[10],'t03-q07':[10],'t03-q08':[11],
't04-q03':[7],'t04-q04':[8],'t04-q07':[10,11],
't05-q04':[7],'t05-q06':[8],'t05-q08':[9,10],
't06-q04':[7],'t06-q08':[9,10],
't07-q03':[7],'t07-q05':[8],'t07-q09':[10],
't08-q07':[10],'t08-q08':[10],'t08-q09':[11],'t08-q10':[11],'t08-q11':[12]}

CONFLICTS=[
{'question':'t04-q06','conflict':'题干写双头螺柱，连接图实为带头螺栓','decision':'按实际结构归入螺栓连接改错；不据误写题干生成螺柱实体'},
{'question':'t02-q08','conflict':'题干要求解释垂直度 ⊥⌀0.05 C，DOC文字答案改答同轴度⌀0.02 B','decision':'依据题干与图中垂直度框格，解释圆柱形公差域与基准C'},
{'question':'t03-q07','conflict':'DOC答案重画的右侧孔与原题所给相交盲孔形状不同','decision':'保留原题孔形，按实际剖切位置计算断面；答案图只作独立来源'},
{'question':'t08-q11','conflict':'原图为锪平Φ44，DOC填空答案出现23','decision':'采用原图Φ44；23是槽宽，二者分别说明'},
{'question':'t03-q04','conflict':'多部位剖切不能简化为一个普通正投影','decision':'对照原DOC第9页的左侧旋转部分、右侧偏置孔及纵向肋板后分别构建，再合并表达'}]

STANDARDS=[
{'topic':'304轴承','original':'原DOC第三套第11页：向心球轴承，04对应内径20，3表示尺寸系列；图给外径52、宽15','current_boundary':'现代6304可核对20×52×15，不把旧代号304直接解释为现代代号中的类型数字','primary':'https://eshop.ntn-snr.com/en/product/6304-SNR/6304'},
{'topic':'G1/2','original':'保留原卷G1/2字样与内螺纹所指表面','current_boundary':'G为55°非螺纹密封管螺纹；1/2是尺寸代号，不把12.7 mm当成外径','primary':'https://openstd.samr.gov.cn/bzgk//std/std_list?p.p1=0&p.p2=GB%2FT7307-2001'},
{'topic':'Q235-A','original':'原图标题栏Q235-A','current_boundary':'按碳素结构钢解释Q、235、质量等级A；不作所有厚度均恒定235 MPa的保证','primary':'https://openstd.samr.gov.cn/bzgk/std/newGbInfo?hcno=728DD12CB05533A5AE309BF47E6CBAA0'},
{'topic':'粗糙度','original':'本卷沿用旧式数值与“其余”标注；原图保持不改','current_boundary':'按原卷语境识读省略的Ra；不把旧式整体当错图。1993与2006标注位置、参数写法不同；改错题仅改数字阅读方向','primary':'https://qr.csupress.com.cn/uploadFiles/101/1061/pdf/5-6%20%E7%B2%97%E7%B3%99%E5%BA%A6%E6%A0%87%E6%B3%A8%E6%96%B9%E6%B3%95%E6%96%B0%E6%97%A7%E6%A0%87%E5%87%86%E5%AF%B9%E6%AF%94.pdf'},
{'topic':'螺纹规定画法','original':'区分原题错图和正确工程表达','current_boundary':'采用GB/T4459.1的规定画法，工程投影独立于螺旋网格','primary':'https://std.samr.gov.cn/gb/search/gbDetailed?id=wy%2FJ%2FNgC4LY%3D&mode=p'},
{'topic':'齿轮画法','original':'原卷给出m、z与比例；齿宽、孔径未注处用教学比例','current_boundary':'GB/T4459.2规定画法；渐开线3D用于形状理解，齿根过渡作简化','primary':'https://openstd.samr.gov.cn/bzgk/std/newGbInfo?hcno=DB37A333DC65C632DE6538C6DAD74E44'}]


def combine(images,path_):
    width=max(i.width for i in images);height=sum(i.height for i in images)+20*(len(images)-1)
    out=Image.new('RGB',(width,height),'white');y=0
    for im in images:out.paste(im,(0,y));y+=im.height+20
    path_.parent.mkdir(parents=True,exist_ok=True);out.save(path_)


def build(courses,scenes,index):
    questions={q['id']:q for q in index['questions']};catalog={}
    ids=set(q for c in courses.values() for scene in c['scenes'] for q in scenes[scene]['source_questions'])
    for qid in sorted(ids):
        q=questions[qid];path_=APP/f'assets/course_sources/{qid}-original.png'
        images=[Image.open(ROOT/'学习资料/题集识别'/r['image']).convert('RGB') for r in q['regions']];combine(images,path_)
        record={'question_image':str(path_.relative_to(APP)).replace('\\','/'),'archive_pages':q['pages'],'original_statement':q['task']}
        if qid in ANSWER_PAGES:
            pdf=ROOT.parent/f'tmp/pdfs/08sd{int(qid[1:3])}.pdf';doc=pymupdf.open(pdf)
            pages=ANSWER_PAGES[qid];images=[]
            for num in pages:
                pix=doc[num-1].get_pixmap(matrix=pymupdf.Matrix(1.7,1.7));images.append(Image.frombytes('RGB',[pix.width,pix.height],pix.samples))
            path_=APP/f'assets/course_sources/{qid}-reference.png';combine(images,path_)
            record.update(answer_image=str(path_.relative_to(APP)).replace('\\','/'),answer_source={'file':str(pdf.relative_to(ROOT.parent)),'pages':pages,'sha256':hashlib.sha256(pdf.read_bytes()).hexdigest()})
        catalog[qid]=record
    for c in courses.values():
        c['sources']={qid:catalog[qid] for scene in c['scenes'] for qid in scenes[scene]['source_questions'] if qid in catalog}
        for obs in c['observations']:obs['source_questions']=scenes[obs['state']['scene']]['source_questions']
        for task in c['tasks']:
            q=task['source_questions'][0]
            if q in catalog:task['source_image']=catalog[q]['question_image'];task['answer_image']=catalog[q].get('answer_image','')
    write_json(APP/'模型/course_source_audit.json',{'checked':'2026-10-23','source_sha256':index['source']['sha256'],'conflicts':CONFLICTS,'conventions':STANDARDS,'catalog':catalog})
    text=['# 全卷来源与约定核验','', '原合订卷：43页、8套、69道大题。题目与原DOC答案是两套独立来源；不把OCR候选或答案中的错误提升为题给事实。','', '## 冲突处理','']
    for item in CONFLICTS:text+=['- '+item['question']+'：'+item['conflict']+'。处理：'+item['decision']+'。']
    text+=['','## 旧卷与现行资料的边界','']
    for item in STANDARDS:text+=['- **'+item['topic']+'**：'+item['original']+'。'+item['current_boundary']+'。[核验资料]('+item['primary']+')']
    text+=['','## 几何与表达','', '题给数字、共享参数推导值、未注尺寸的教学尺度分别保存在场景参数和来源记录中。无尺寸图采用相容模型，不声称唯一标准实体。解析交线与规定画法分别生成；螺纹错图保留为独立已知图片。','', '原DOC页面仅供开发者参考，不会自动进入讲解正文。课程正文不显示题号。外部标准目录可核对版本及名称，不能代替尚未获得的标准全文逐条审查。']
    (APP/'全卷来源核验.md').write_text('\n'.join(text)+'\n',encoding='utf8')
