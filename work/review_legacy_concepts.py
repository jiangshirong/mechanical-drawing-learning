"""Shared author review hooks; no edits to original-question lesson groups."""
from copy import deepcopy

def revise(config,chapter):
    groups=config['concept'];beats={b['id']:b for g in groups for b in g['beats']}
    def text(id,value):beats[id]['text']=value
    def insert(gid,id,value,after=None):
        group=next(g for g in groups if g['id']==gid)
        if id in beats:return
        original=group['beats'][0] if after is None else beats[after]
        b=deepcopy(original);b.update(id=id,text=value,action={'type':'none' if chapter=='plane' else 'focus'})
        for key in ['setup','callout_kind','problem_conditions','label_focus']:b.pop(key,None)
        if chapter=='plane':b['callout_kind']='normal'
        index=0 if after is None else group['beats'].index(original)+1
        group['beats'].insert(index,b);beats[id]=b
    if chapter=='points':
        insert('planes','planes:purpose','怎样把空间点的位置画在纸上？先认识从三个方向接收投影的平面。')
        # Context highlights the existing object, not the next action's plane.
        beats['planes:purpose']['anchor']=['A']
        beats['planes:purpose']['focus']=['A']
        text('planes:H','从上向下投影的平面是水平面 H。')
        text('planes:V','从前向后投影的平面是正面 V。')
        text('planes:W','从左向右投影的平面是侧面 W。')
        text('distances:coordinates','只说在前、在上还不够；到三个面的距离共同确定 A 的位置。')
        text('feet:V','从 A 向 V 面作垂线，垂足 a′ 就是它的正面投影。')
        text('unfold:V','三个面还在空间中。要把投影放到同一张纸上，先固定 V 面。')
        text('unfold:distance','展开不改变投影点到转轴的距离。')
        # Distances to X/Z use their perpendicular feet, not the inter-view gap.
        for id in ['unfold:distance','alignment:depth']:
            beats[id]['anchor']=['A_x','A_top','A_height','A_left']
            beats[id]['focus']=list(beats[id]['anchor'])
        insert('relative','relative:purpose','现在已知 A，要按左右、上下、前后的相对位置作出 B。')
        # B has not been constructed yet; do not preview its future location.
        beats['relative:purpose']['anchor']=['A_front']
        beats['relative:purpose']['focus']=['A_front']
        text('relative8:front','若条件改为“B 在 A 前方 18 mm”，从 A 向前量取。')
        # Names make sense once all three feet actually exist on the planes.
        planes=next(g for g in groups if g['id']=='planes');feet=next(g for g in groups if g['id']=='feet')
        name=next((b for b in planes['beats'] if b['id']=='planes:names'),None)
        if name:
            planes['beats'].remove(name);feet['beats'].append(name)
    elif chapter=='line':
        insert('projection','projection:purpose','已经会定位点；给出 A、B 两端点，就能确定线段及其投影。')
        text('point_on_line:height-point','C 在线段 AB 上，等高辅助线与 a′b′ 的交点就是 c′。')
        text('point_on_line:height-transfer','C 仍须在线上：由 c′ 对应到 ab，再补侧面投影。')
        text('division:parts-context','同一条线上改用比例条件：AC∶CB＝2∶3。')
        text('division:parts','把空间 AB 五等分，再对应到各面投影。')
        beats['division:parts']['action']['duration']=2.6
        text('parallel:through-result','选取同名端点对应的位置，再补空间线段和侧面投影。')
        text('parallel:compare','看水平投影：方向不同，因此这组空间直线并不平行。')
        insert('intersection','intersection:both-clue','CD 垂直 V 面，在正面积聚成一点；所求线必须经过这个投影点。',after='intersection:both-front-context')
        beats['intersection:both-clue']['scene']='both'
        beats['intersection:both-clue']['focus']=beats['intersection:both-clue']['anchor']=['front:CD','space:CD']
        text('intersection:both-front','过 c′d′ 作 a′b′ 的平行线，与 e′f′ 相交，确定另一个交点。')
        text('intersection:both-top','向水平投影对应，在 cd、ef 上分别确定两个交点。')
        text('intersection:both-space','连接两个交点，得到同时平行 AB、并与 CD 和 EF 相交的线。')
        group=next(g for g in groups if g['id']=='intersection');group['beats']=[b for b in group['beats'] if b['id']!='intersection:result']
        config.setdefault('knowledge_resume_aliases',{})['intersection:result']='intersection:both-space'
    elif chapter=='plane':
        text('projection:surface','已知空间平面 ABCD，分别求它的三面投影。')
        text('projection:vertices','积聚后顶点仍各自对应；这条线不表示原平面只剩一条边。')
        text('in-line:problem','给出平面 ABC，要求在面内作一条距 H 面 10 mm 的线。')
        text('in-line:level','线上各点高度都为 10 mm，先画正面水平辅助线。')
        text('in-line:intersections','辅助线与两条边的交点，同时属于这个平面。')
        text('in-line:joined','连接面内两点，得到所求面内直线。')
        text('in-line:frontal','若改为距 V 面 15 mm，就从水平投影画等距线；求交点的方法相同。')
        text('in-point:problem','平面内的点 P 距 H 面 15 mm、距 V 面 12 mm，怎样同时满足？')
        # Reuse the already taught face-line construction as one continuous action.
        ids=['in-point:level','in-point:intersections','in-point:other-points','in-point:joined']
        actions=[deepcopy(beats[id]['action']) for id in ids]
        first=beats[ids[0]];first.update(text='先用高度 15 mm 作面内水平线，P 必须在这条线上。',action={'type':'sequence','actions':actions,'duration':4.2})
        group=next(g for g in groups if g['id']=='in-point');group['beats']=[b for b in group['beats'] if b['id'] not in ids[1:]]
        config.setdefault('knowledge_resume_aliases',{}).update({id:ids[0] for id in ids[1:]})
        text('in-point:depth','再从水平投影按距 V 面 12 mm 画辅助线。')
        text('in-point:P-top','两条条件线的交点 p，同时满足两个面距。')
        text('complete:problem','普通四边形 ABCD 缺顶点 c 的水平投影，怎样借已知顶点求它？')
        text('complete:AC-front','连接 a′、c′，借对角线建立一条面内辅助线。')
        text('complete:E-front','两条对角线交于同一空间点 E，先确定 e′。')
        text('complete:E-top','E 也在 BD 上；由 e′ 对应到 bd，确定 e。')
        text('complete:AC-top','A、E、C 共线，所以 c 必须在 ae 的延长线上。')
        text('complete:C-top','再用 c′ 的左右位置，与 ae 相交确定 c。')
        text('complete:parallel-context','只有题目明确给出平行四边形时，才可用对边平行补点。')
        # Reversing the 45-degree transfer is a new use, so demonstrate the first vertex.
        old=beats['complete:third-endpoints']
        targets=deepcopy(old['action']['targets'])
        old.update(text='由 a″ 经45°线转移，与 a′ 对正，确定 a。',action={'type':'project_points','targets':targets[:1],'duration':2.4})
        following=deepcopy(old);following.update(id='complete:third-remaining',text='同样求出 b、c。',action={'type':'project_points','targets':targets[1:],'duration':3.2})
        complete=next(g for g in groups if g['id']=='complete')
        complete['beats'].insert(complete['beats'].index(old)+1,following)
        text('complete:third-problem','已知正面、侧面投影，先由 a′、a″ 求 a。')
        # AC's frontal condition determines C before any parallelogram construction.
        scene=config['scenes']['parallel-quad'];refs=scene['refs'];a=refs['A_top'];c=refs['C_top'];b=refs['B_top'];d=refs['D_top']
        refs['parallel_c_end']=[c[0]+(5 if c[0]>a[0] else -5),a[1]]
        refs['parallel_ab_end']=[b[0]+.16*(b[0]-a[0]),b[1]+.16*(b[1]-a[1])]
        refs['parallel_cb_end']=[b[0]+.16*(b[0]-c[0]),b[1]+.16*(b[1]-c[1])]
        text('complete:parallel-context','已知平行四边形 ABCD，AC 为正平线，补水平投影。')
        beats['complete:parallel-context']['callout_kind']='problem'
        template=deepcopy(beats['complete:parallel-complete'])
        def addition(id,copy,action,anchor):
            value=deepcopy(template);value.update(id=id,text=copy,action=action,anchor=anchor);return value
        line=lambda id,a,b:{'type':'line','id':id,'a':a,'b':b,'dashed':True}
        additions=[
            addition('complete:parallel-c-distance','AC 平行 V 面，a、c 到 X 的距离相同。',line('parallel_c_distance','A_top','parallel_c_end'),['A_top','parallel_c_end']),
            addition('complete:parallel-c','由 c′ 向下对应，交点确定 c。',{'type':'sequence','actions':[line('parallel_c_align','C_front','C_top'),{'type':'points','points':[{'ref':'C_top','name':'c'}]}],'duration':1.8},['C_front','C_top']),
            addition('complete:parallel-ab','连接 d、c；过 a 作 dc 的平行线。',{'type':'sequence','actions':[{'type':'outline','paths':[['D_top','C_top']]},line('parallel_ab','A_top','parallel_ab_end')],'duration':1.8},['D_top','C_top','A_top']),
            addition('complete:parallel-b','过 c 作 ad 的平行线，与前线交于 b。',{'type':'sequence','actions':[line('parallel_cb','C_top','parallel_cb_end'),{'type':'points','points':[{'ref':'B_top','name':'b'}]}],'duration':1.8},['A_top','D_top','C_top','B_top'])]
        at=next(i for i,x in enumerate(complete['beats']) if x['id']=='complete:parallel-complete')
        complete['beats'][at:at]=additions
        end=beats['complete:parallel-complete'];end.update(text='连成边界，擦去临时辅助线。',action={'type':'sequence','actions':[{'type':'outline','paths':[['A_top','B_top'],['B_top','C_top']]},{'type':'erase','targets':['parallel_c_distance','parallel_c_align','parallel_ab','parallel_cb']}],'duration':2.2})
    for g in groups:g['text']=''.join(b['text'] for b in g['beats'])
    config['beginner_review']={'date':'2026-10-25','chapter':chapter,'scope':'concept'}
    return config
