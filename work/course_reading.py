"""Original figure regions: immutable archive + explicit crop/rotation provenance."""
from course_geometry import *
from PIL import Image
import hashlib

ARCHIVE=ROOT/'学习资料/题集识别'

def figure_scene(id,filename,crop=None,rotate=0,marks=None,source=None):
    original=ARCHIVE/'题图'/filename
    im=Image.open(original).convert('RGB')
    if crop:im=im.crop(crop)
    if rotate:im=im.rotate(rotate,expand=True)
    path_=APP/f'assets/course_sources/{id}.png';path_.parent.mkdir(parents=True,exist_ok=True);im.save(path_)
    w,h=im.size;scale=120/w
    s=Scene(id,source or [filename[:7]],'paper',('front',))
    s.entity('figure',image=str(path_.relative_to(APP)).replace('\\','/'),rect=[0,0,120,h*scale])
    s.data['provenance']={'kind':'original_figure_region','source':str(original.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'crop_pixels':crop,'rotation_degrees':rotate,'output_size':[w,h]}
    for key,box in (marks or {}).items():
        x,y,W,H=box;s.entity(key,paths={'front':[path(rect(x*scale,y*scale,W*scale,H*scale),'thin')]},visible=False,ink='c17b35',role='attention')
    return s

def all_scenes():
    s=figure_scene('read_bearing_block','t02-q08-p11.png',(90,315,860,1260),-90,{'front_region':[55,40,515,390],'side_region':[650,90,270,350],'top_region':[100,495,440,220],'base':[100,405,440,16],'axis_front':[318,55,16,385],'axis_side':[780,90,16,350],'end_face':[520,100,16,315]},['t02-q08'])
    for name,line in [('cut_side',[[314,480],[314,735]]),('cut_front',[[85,613],[555,613]]),('cut_top',[[135,189],[490,189]])]:s.ink(name,'front',[[[x*120/945,y*120/945] for x,y in line]],'axis',visible=False)
    yield s
    yield figure_scene('read_end_cover','t05-q08-p27.png',(100,120,1018,768),0,{'surface_I':[440,330,75,65],'surface_II':[260,120,65,65],'surface_III':[560,395,90,65]},['t05-q08'])
    yield figure_scene('read_shaft','t06-q08-p32.png',(100,120,1018,770),0,{'chamfer_left':[68,300,55,115],'chamfer_right':[605,300,55,90],'grooves':[550,315,38,105],'detail':[185,65,120,100],'section':[475,215,70,260]},['t06-q08'])
    s=figure_scene('read_shaft_errors','t07-q09-p37.png',(100,330,1018,984),0,{'error_vertical':[270,435,45,45],'error_inverted':[478,390,45,45],'correct_example':[115,475,45,40]},['t07-q09'])
    factor=120/918
    for i,(x,y) in enumerate([(271,458),(479,415)]):
        # Independent answer overlay: retain the original erroneous raster as known evidence.
        s.entity('correct_'+str(i),patch_rect=[(x+22)*factor,(y-16)*factor,17*factor,29*factor],view='front',labels=[{'text':'3.2' if i==0 else '6.3','view':'front','at':[(x+29)*factor,(y+10)*factor],'size':26,'rotation':-pi/2,'fixed':True}],visible=False)
    s.data['verified_answer']={'count':2,'source':'原DOC第7套第10页','rule':'数字方向应从图纸下方或右方阅读；两处转向左方的数值须改正'}
    yield s
    yield figure_scene('read_lid','t08-q11-p43.png',(110,345,910,1190),0,{'front':[80,65,555,100],'holes':[240,330,260,260],'slots':[90,225,530,520],'title':[380,750,405,85],'quality':[360,82,40,36]},['t08-q11'])
    yield figure_scene('read_lid_section','t08-q11-p43.png',(185,365,750,530),0,{'datum_height':[75,110,355,10],'depth':[345,35,65,80],'quality':[275,62,40,38]},['t08-q11'])
    yield figure_scene('read_lid_plan','t08-q11-p43.png',(190,560,750,1095),0,{'datum_axes':[260,0,15,530],'thread_holes':[125,150,300,250],'slot':[385,200,160,90]},['t08-q11'])
    yield figure_scene('read_lid_note','t08-q11-p43.png',(605,675,735,915),0,{'hole_note':[15,20,105,75],'slot_note':[10,175,100,55]},['t08-q11'])
    yield figure_scene('read_local','t01-q09-p06.png',None,-90,{},['t01-q09'])

def source_answer_scene(question_id,page_offset=0):
    """Vector answer from the archived original DOC export, never a guessed answer.

    Used only for the exact paper task; conceptual 3D scenes have separate IDs.
    Blue reference strokes are animated as source-derived drawing evidence.
    """
    import fitz
    index=json.loads((ARCHIVE/'题集索引.json').read_text(encoding='utf-8'))
    q=next(x for x in index['questions'] if x['id']==question_id)
    pdf=ROOT.parent/f'tmp/pdfs/08sd{q["paper"]}.pdf'
    doc=fitz.open(pdf);half=len(doc)//2
    first=index['sets'][q['paper']-1]['pdf_pages'][0]
    local=q['pages'][page_offset]-first
    page=doc[local+half]
    region=q['regions'][page_offset];rect_=fitz.Rect([region['box_normalized'][i]*([page.rect.width,page.rect.height]*2)[i] for i in range(4)])
    draws=page.get_drawings();groups=[]
    for d in draws:
        color=d.get('color') or d.get('fill')
        if not color or len(color)<3 or color[2]<.5 or color[2]<=color[0]+.2:continue
        if not rect_.intersects(d['rect']):continue
        paths=[];cur=[]
        for item in d['items']:
            if item[0]=='l':paths.append([[float(p.x-rect_.x0),float(p.y-rect_.y0)] for p in item[1:3]])
            elif item[0]=='re':
                r=item[1];paths.append(rect(r.x0-rect_.x0,r.y0-rect_.y0,r.width,r.height))
            elif item[0]=='c':
                p0,p1,p2,p3=item[1:];points=[]
                for t in np.linspace(0,1,25):
                    p=(1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3
                    points.append([p.x-rect_.x0,p.y-rect_.y0])
                paths.append(points)
        if paths:groups.extend(paths)
    # Source rendering includes the reference answer, retained separately for QA/developer use.
    answer_path=APP/f'assets/course_sources/{question_id}-answer-{page_offset}.png'
    answer_path.parent.mkdir(parents=True,exist_ok=True);page.get_pixmap(matrix=fitz.Matrix(2,2),clip=rect_).save(answer_path)
    return dict(paths=groups,reference_image=str(answer_path.relative_to(APP)).replace('\\','/'),source_pdf=str(pdf),page=local+half+1,rect=list(rect_),sha256=hashlib.sha256(pdf.read_bytes()).hexdigest())
