"""Every paper demand maps to a method and an executable representative.

The status describes teaching coverage, not a claim that rendering/geometry QA
has passed. Those evidence layers are recorded separately in qa/course-*.
"""
from course_geometry import *

METHODS={
'point_locate':('points','distances','t01-q01','已知三项面距作点'),
'point_transfer':('points','alignment','t01-q01','两面投影求第三投影'),
'point_relative':('points','relative','t01-q01','相对位移定位'),
'horizontal':('line','parallel_plane','horizontal','水平线定长定角作图'),
'line_transfer':('line','projection','third-height','补直线第三投影'),
'line_height':('line','point_on_line','third-height','按面距在线上取点'),
'ratio':('line','point_on_line','ratio','按线段比例取点'),
'parallel':('line','parallel','through-parallel','过点作平行线'),
'line_meet':('line','intersection','through-intersect','按面距确定交点再连线'),
'transversal':('line','intersection','transversal','同时满足平行及两次相交'),
'plane_transfer':('plane','projection','third-general','补平面第三投影'),
'plane_collapse':('plane','projection','third-edge','积聚投影中保留各顶点对应'),
'plane_horizontal':('plane','in-line','in-horizontal','面内作水平线'),
'plane_frontal':('plane','in-line','in-frontal','面内作正平线'),
'plane_vertex':('plane','in-line','through-vertex','过顶点作面内水平线'),
'plane_point':('plane','in-point','in-point','按两项面距在面内取点'),
'quadrilateral':('plane','complete','quad-missing','借对角线补普通四边形'),
'parallelogram':('plane','complete','parallel-quad','利用正平线和对边平行补平行四边形'),
'cut_prism':('intersection_plane','prism','cut-prism','棱柱截交线与轮廓'),
'cut_cylinder':('intersection_plane','cylinder','cut-cylinder','圆柱槽口与截交线'),
'cut_cone':('intersection_plane','cone','cut-cone','圆锥截面取点与连曲线'),
'cut_sphere':('intersection_plane','sphere','cut-sphere','球面开槽与截交线'),
'intersect_inner':('intersection_solids','inner','intersection-inner','两圆柱孔的公共曲线'),
'intersect_shell':('intersection_solids','shell','intersection-shell','内外表面分别求交'),
'shape_analysis':('combination','slope','combination-slope','形体分解与补第三视图'),
'face_analysis':('combination','base','combination-base','线面分析与补第三视图'),
'third_top':('combination','bracket','combination-bracket','由主左视图补俯视图'),
'missing':('combination','missing','combination-missing','补多视图缺漏线'),
'full':('section','full','section-full','全剖及肋板规定'),
'half':('section','half','section-half','全剖与半剖配合'),
'local':('section','local','section-local','局部剖范围及分界'),
'stepped':('section','stepped','section-stepped','平行剖切平面合并表达'),
'rotated':('section','rotated','section-rotated','倾斜剖切部分转正'),
'combined_section':('section','combined','section-combined','多部位剖切及肋板表达'),
'section_missing':('section','missing','section-missing','剖视图中的轮廓补线'),
'removed_key':('removed_section','key','removed-key','键槽与钻孔的移出断面'),
'removed_hole':('removed_section','hole','removed-hole','相交孔槽的移出断面'),
'removed_compare':('removed_section','compare','removed-compare','开口与回转孔槽规定对照'),
'datum':('dimensions','datum','dimensions-lid','长宽高主要尺寸基准'),
'datum_block':('dimensions','block','dimensions-block','从对称线与底面确定基准'),
'locating':('dimensions','location','dimensions-lid','定形与定位尺寸'),
'thread_judge':('threads','external','thread-judge','内外螺纹线型与端面圆'),
'thread_engaged':('threads','engaged','thread-engaged','旋合与未旋合部分画法'),
'bolt':('threads','bolt','bolt-connect','螺栓连接补图'),
'stud':('threads','stud','stud-connect','双头螺柱及盲孔连接'),
'bolt_error':('threads','bolt','bolt-correct','螺栓连接改错'),
'mark_coarse':('threads','mark_coarse','thread-mark-coarse','普通粗牙内螺纹标记'),
'mark_fine':('threads','mark_fine','thread-mark-fine','细牙及内外螺纹标记'),
'mark_pipe':('threads','mark_pipe','thread-mark-pipe','G管螺纹及公称尺寸代号'),
'gear_single':('gears','single','gear-single','单齿轮计算与规定画法'),
'gear_pair':('gears','pair','gear-pair','啮合、中心距和绘图比例'),
'bearing':('bearings','structure','bearing-assembly','304代号及20/52/15尺寸'),
'bearing_mount':('bearings','assembly','bearing-assembly','内外圈与孔轴装配'),
'tol_hole':('requirements','hole','tolerance-hole','孔的基本尺寸与公差带'),
'tol_shaft':('requirements','shaft','tolerance-shaft','轴的基本尺寸与公差带'),
'perp_axis':('requirements','perpendicular','tolerance-perpendicular','带直径符号的轴线垂直度'),
'perp_plane':('requirements','plane','tolerance-plane','不带直径符号的表面垂直度'),
'parallel_plane':('requirements','parallel','tolerance-parallel','平行度、基准与公差域'),
'rough_symbol':('roughness','symbol','roughness-quality','粗糙度符号及数值解释'),
'rough_surface':('roughness','surface','roughness-surfaces','跨视图追踪粗糙度所指表面'),
'rough_error':('roughness','errors','roughness-errors','数字阅读方向改错'),
'read_views':('part_drawing','overview','read-block','识别视图和剖视表达'),
'read_cuts':('part_drawing','overview','read-block','由剖视识别剖切位置'),
'read_outline':('part_drawing','restore','read-outline','由剖视恢复外形'),
'process':('part_drawing','details','read-shaft','局部放大、倒角及退刀槽'),
'shaft_section':('part_drawing','shaft_section','read-shaft','齿轮轴的键槽断面'),
'lid_holes':('part_drawing','note','read-lid','螺孔数量、深度及分布'),
'lid_slots':('part_drawing','note','read-lid','槽形、槽宽与锪平'),
'material':('part_drawing','material','read-lid','标题栏材料牌号'),
}

# Each outer list is one original numbered subquestion; tuples split combined demands.
ASSIGN={
't01-q01':[('point_locate','point_transfer'),('point_relative','point_transfer')],
't01-q02':['quadrilateral'],'t01-q03':['cut_prism','cut_sphere'],'t01-q04':['shape_analysis','face_analysis'],
't01-q05':['full'],'t01-q06':['rotated'],'t01-q07':['bolt'],'t01-q08':[('gear_pair',)],
't01-q09':['read_views','datum','mark_pipe','tol_hole','rough_symbol','read_outline'],
't02-q01':['horizontal'],'t02-q02':['parallelogram'],'t02-q03':['shape_analysis','face_analysis'],
't02-q04':['full'],'t02-q05':['removed_key'],'t02-q06':['stud'],'t02-q07':['gear_single'],
't02-q08':['read_views','datum_block','tol_hole','mark_coarse','read_cuts','perp_axis'],
't03-q01':['plane_horizontal'],'t03-q02':['transversal'],'t03-q03':['shape_analysis','face_analysis'],
't03-q04':['combined_section'],'t03-q05':['section_missing'],'t03-q06':['thread_engaged'],
't03-q07':[('removed_key','removed_hole')],'t03-q08':[('bearing','bearing_mount')],
't03-q09':['read_views','datum','tol_hole','mark_fine','read_outline','rough_symbol'],
't04-q01':['plane_point'],'t04-q02':['parallel','line_meet'],'t04-q03':['shape_analysis','face_analysis','cut_cone'],
't04-q04':[('full','half')],'t04-q05':['section_missing'],'t04-q06':['bolt_error'],
't04-q07':['read_views','datum','tol_hole','mark_coarse','rough_symbol','parallel_plane'],
't05-q01':['ratio'],'t05-q02':[('plane_transfer','plane_collapse')],'t05-q03':['shape_analysis'],
't05-q04':['intersect_shell'],'t05-q05':['face_analysis'],'t05-q06':['thread_judge'],'t05-q07':['full'],
't05-q08':[('rough_surface',),'tol_shaft'],
't06-q01':['ratio'],'t06-q02':['plane_transfer'],'t06-q03':['shape_analysis'],'t06-q04':['intersect_inner'],
't06-q05':['face_analysis'],'t06-q06':['thread_judge'],'t06-q07':['full'],
't06-q08':['mark_fine','perp_plane','process',('shaft_section',)],
't07-q01':['line_transfer','line_height'],'t07-q02':['transversal'],'t07-q03':['cut_cylinder'],'t07-q04':['intersect_shell'],
't07-q05':['third_top'],'t07-q06':['face_analysis'],'t07-q07':['full'],'t07-q08':['thread_judge'],
't07-q09':['tol_shaft','perp_plane','process','rough_error',('shaft_section',)],
't08-q01':['point_relative'],'t08-q02':['parallel','line_meet'],'t08-q03':['plane_frontal','plane_vertex'],
't08-q04':['cut_cylinder'],'t08-q05':['intersect_inner'],'t08-q06':['face_analysis'],'t08-q07':['missing'],
't08-q08':['stepped'],'t08-q09':['removed_compare'],'t08-q10':['bolt_error'],
't08-q11':['read_views','datum','locating','lid_holes','lid_slots','rough_symbol','material'],
}

def build(index,courses):
    questions={q['id']:q for q in index['questions']};assert set(questions)==set(ASSIGN)
    task_sources={}
    for c in courses.values():
        for t in c['tasks']:task_sources[(c['id'],t['id'])]=t['source_questions']
    for chapter,file in [('line','line_practice.json'),('plane','plane_questions.json')]:
        for t in json.loads((APP/'模型'/file).read_text(encoding='utf8'))['tasks']:task_sources[(chapter,t['id'])]=[t['question_id']]
    task_sources[('points','t01-q01')]=['t01-q01']
    rows=[]
    for qid,demands in ASSIGN.items():
        q=questions[qid];requirements=[]
        for i,method_keys in enumerate(demands):
            if isinstance(method_keys,str):method_keys=(method_keys,)
            refs=[]
            for method in method_keys:
                chapter,group,task,title=METHODS[method]
                assert (chapter,task) in task_sources,('Missing representative',qid,method,task)
                refs.append({'method_id':method,'chapter':chapter,'section':group,'task':task,'method':title,'status':'完整示范' if qid in task_sources[(chapter,task)] else '同法覆盖'})
            numbered=q.get('subquestions',[])
            original=numbered[i].get('text_candidate','') if i<len(numbered) else q['heading']
            requirements.append({'id':f'{qid}:requirement:{i+1}','original_number':numbered[i].get('number') if i<len(numbered) else None,'source_text':original,'demand':'；'.join(ref['method'] for ref in refs),'demonstrations':refs})
        if qid=='t05-q08':requirements[0]['answer_fields']=['表面Ⅰ','表面Ⅱ','表面Ⅲ']
        if qid in ['t06-q08','t07-q09']:requirements[2]['answer_fields']=['倒角数量','倒角尺寸','退刀槽数量','退刀槽尺寸']
        if qid=='t08-q11':
            requirements[3]['answer_fields']=['螺孔数量','公称直径','螺纹深度','均布方式']
            requirements[4]['answer_fields']=['槽数量','槽形','槽宽','锪平直径']
        if qid in ['t05-q06','t06-q06','t07-q08']:requirements[0]['answer_fields']=['方案1','方案2','方案3','方案4']
        rows.append({'question':qid,'pages':q['pages'],'original_text':q['task'],'requirements':requirements})
    methods={k:dict(chapter=v[0],section=v[1],task=v[2],title=v[3]) for k,v in METHODS.items()}
    result={'schema_version':2,'source_sha256':index['source']['sha256'],'question_count':len(rows),'requirement_count':sum(len(q['requirements']) for q in rows),'methods':methods,'questions':rows,'status_meanings':{'完整示范':'代表任务实际讲解此原题要求','必要变式':'同方法但判断条件不同，保留独立对照','同法覆盖':'复用明确列出的解法，不因数字或视图变化重讲','待核实':'未完成来源或方法核对，禁止视为已交付'},'evidence_boundary':'覆盖归属与内容、数学、播放、渲染验收分别记录；不以存在一条JSON记录代替验收。'}
    for q in rows:
        if q['question'] in ['t08-q01','t08-q09','t03-q04','t08-q10']:
            for req in q['requirements']:
                for ref in req['demonstrations']:ref['status']='必要变式'
    write_json(APP/'模型/course_coverage.json',result)
    return result
