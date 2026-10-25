"""Beginner-facing visual evidence, authored independently of question answers.

All additions are hidden in the original observation/task states. Explanatory
scales and enlarged errors are explicitly recorded, never original dimensions.
"""
from course_geometry import *
import copy

def thread_mesh(internal,length,major=10.,minor=8.,pitch=4.2):
    """Closed ideal helical tooth surface; drawing convention stays independent."""
    n=96;levels=max(24,int(length/pitch*32));rings=[]
    for j in range(levels+1):
        z=length*j/levels;ring=[]
        for i in range(n):
            theta=TAU*i/n;phase=(z/pitch-i/n)%1
            tooth=1-2*min(phase,1-phase);radius=minor+(major-minor)*tooth
            ring.append([radius*cos(theta),radius*sin(theta),z])
        rings.append(ring)
    tris=[]
    for j in range(levels):
        for i in range(n):
            k=(i+1)%n;a,b,c,d=rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i]
            tris+=(tri_quad(a,d,c,b) if internal else tri_quad(a,b,c,d))
    if internal:
        for i in range(n):
            k=(i+1)%n;a=[17*cos(TAU*i/n),17*sin(TAU*i/n),0];b=[17*cos(TAU*k/n),17*sin(TAU*k/n),0];c=[b[0],b[1],length];d=[a[0],a[1],length]
            tris+=tri_quad(a,b,c,d)+tri_quad(a,rings[0][i],rings[0][k],b)+tri_quad(d,c,rings[-1][k],rings[-1][i])
    else:
        for i in range(n):
            k=(i+1)%n;tris += [[0,0,0],rings[0][k],rings[0][i],[0,0,length],rings[-1][i],rings[-1][k]]
    return tris

def teaching_scenes():
    s=Scene('dimension_method',['t02-q08','t08-q11'],'paper',('front',))
    s.data['parameters']={'width':84,'height':50,'hole_radius':8,'hole_centre':[28,30],'teaching_only':True}
    s.data['provenance']['note']='仅用于区别定形、定位、总体尺寸及基准；尺寸为教学参数。'
    s.ink('outline','front',[rect(0,-50,84,50),circle(8,(28,-30))])
    s.ink('centre','front',[[[14,-30],[42,-30]],[[28,-44],[28,-16]]],'axis')
    s.ink('base','front',[[[0,0],[84,0]]],visible=False)
    for key,a,b,label in [('size',[20,-30],[36,-30],'⌀16'),('position',[47,0],[47,-30],'30'),('overall',[98,0],[98,-50],'50')]:
        s.entity(key,visible=False,brace={'view':'front','a':a,'b':b,'label':label})
    s.label('scale_note','教学示意',[0,16],size=18)
    yield s
    s=Scene('thread_principle',['t05-q06','t03-q06'],'paper',('front',))
    s.data['parameters']={'major_radius':10,'minor_radius':8,'pitch':4,'teaching_only':True}
    s.data['provenance']['note']='放大轴向牙形用于说明牙顶、牙底、螺距；并非原题尺寸或制造牙型。'
    profile=[]
    for k in range(5):profile += [[k*4,0],[k*4+1,0],[k*4+2,-8],[k*4+3,-8],[k*4+4,0]]
    s.ink('profile','front',[profile,[[0,0],[0,8],[20,8],[20,0]]])
    s.ink('crest','front',[[[2,-8],[3,-8]],[[6,-8],[7,-8]],[[10,-8],[11,-8]]],visible=False)
    s.ink('root','front',[[[4,0],[5,0]],[[8,0],[9,0]],[[12,0],[13,0]]],visible=False)
    s.label('crest_name','牙顶',[25,-8],visible=False)
    s.label('root_name','牙底',[25,3],visible=False)
    s.entity('pitch',visible=False,brace={'view':'front','a':[2,-13],'b':[6,-13],'label':'螺距'})
    s.label('scale_note','轴向牙形 · 放大示意',[0,16],size=18)
    yield s
    s=Scene('roughness_profile',['t05-q08','t08-q11'],'paper',('front',))
    s.ink('surface','front',[[[0,0],[100,0]]])
    s.label('surface_name','图纸上的表面',[0,-10],size=20)
    wave=[[x,35+4*sin(x*1.4)+2*sin(x*3.1)] for x in np.linspace(0,100,241)]
    s.ink('profile','front',[wave],visible=False)
    s.ink('smoother','front',[[[p[0],65+(p[1]-35)*.35] for p in wave]],visible=False)
    s.label('profile_name','放大后的微小起伏',[0,22],visible=False)
    s.label('smoother_name','相同放大尺度下，起伏较小',[0,54],visible=False)
    s.data['parameters']={'profiles':'illustrative, not measured Ra values','amplitude_ratio':.35}
    yield s

def enhance(scene):
    """Idempotent author pass; same input parameters yield the same overlays."""
    s=Scene(scene['id']);s.data=copy.deepcopy(scene);e=s.data['entities'];sid=scene['id']
    if sid.startswith('basic_'):
        p=s.data['parameters']['surface_point']
        e['point']['triangles']=mesh_triangles(Manifold.sphere(.8,16).translate(p))
        if sid=='basic_cone':
            factor=48/(48-p[2]);base=[p[0]*factor,p[1]*factor,0]
            s.projected('point_generator',[[base,[0,0,48]]],visible=False,color='d88b37')
    if sid=='section_half':
        from course_sections import half_body
        body=half_body();quarter=Manifold.cube([100,100,120]).translate([-100,-100,-20])
        removed=body^quarter;kept=body-removed
        add_body(s,'half_cut',kept,visible=False,project_views=False)
        add_body(s,'half_removed',removed,visible=False,project_views=False,color='9bb9c7')
        for name,source in [('half_outline','section_outline'),('half_hatching','hatching')]:
            s.entity(name,paths={'left':copy.deepcopy(e[source]['paths']['left'])},visible=False)
        s.data['parameters']['half_concept']={'view':'left','removed_region':'x < 0 and y < 0','original_volume':body.volume(),'kept_volume':kept.volume(),'removed_volume':removed.volume()}
    if sid in ['thread_external','thread_internal']:
        length=24 if sid.endswith('internal') else 42;pitch=4.2
        e['model']['triangles']=thread_mesh(sid.endswith('internal'),length,pitch=pitch)
        helix=[[10*cos(t),10*sin(t),pitch*t/TAU] for t in np.linspace(0,TAU*length/pitch,641)]
        e['helix']['world']=[path(helix)]
        s.data['parameters']['physical_thread']={'pitch':pitch,'length':length,'major_radius':10,'minor_radius':8,'kind':'ideal triangular helix, not manufacturing geometry'}
    if sid.startswith('gear_') and sid in ['gear_single','gear_pair']:
        m=s.data['parameters']['module'];zs=s.data['parameters']['teeth']
        for i,z in enumerate(zs):
            zc=i*s.data['parameters']['centre_distance']
            for key,r in [('tooth_tips',m*(z+2)/2),('tooth_roots',m*(z-2.5)/2),('reference',m*z/2)]:
                pts=[[s.data['parameters']['face_width'][i]/2+.15,r*cos(t),zc+r*sin(t)] for t in np.linspace(0,TAU,193)]
                s.entity(f'{key}{i}',world=[pts],visible=False,color='d88b37',role='attention')
    if sid=='bearing':
        s.label('code','304',[1,49],visible=False)
        # Old code is introduced beside the actual bearing, before decomposing it.
        e['code']['labels'][0]['size']=26
        # Dimensions refer to the same axial projection, not an empty front view.
        B=s.data['parameters']['B'];D=s.data['parameters']['D'];d=s.data['parameters']['d']
        s.ink('dimension_outline','front',[rect(0,-D/2,B,D)],visible=False)
        s.ink('dimension_bore','front',[[[0,-d/2],[B,-d/2]],[[0,d/2],[B,d/2]]],'dashed',visible=False)
        s.ink('diameter_witness','front',[[[B,-d/2],[24,-d/2]],[[B,d/2],[24,d/2]]],'thin',visible=False)
        s.ink('size_witness','front',[[[-14,-D/2],[0,-D/2]],[[-14,D/2],[0,D/2]],[[0,D/2],[0,33]],[[B,D/2],[B,33]]],'thin',visible=False)
    if sid in ['tolerance_hole','tolerance_shaft']:
        s.label('zero_label','零线：基本尺寸',[0,74 if sid.endswith('hole') else 53],visible=False,size=20)
        s.label('zone_label','允许尺寸的范围',[26,30 if sid.endswith('hole') else 102],visible=False,size=20)
        s.ink('bounds','front',[[[25,35],[95,35]],[[25,60],[95,60]]] if sid.endswith('hole') else [[[25,65],[95,65]],[[25,90],[95,90]]],visible=False)
        s.ink('measured','front',[[[18,47 if sid.endswith('hole') else 76],[102,47 if sid.endswith('hole') else 76]]],visible=False,ink='548a69')
        s.label('scale_note','偏差放大示意，不表示公差数值',[0,125],visible=False,size=18)
    if sid in ['tolerance_perpendicular','tolerance_plane','tolerance_parallel']:
        s.label('datum_name','基准 C' if sid.endswith('perpendicular') else '基准 A',[78,72],visible=False)
        s.label('zone_name','允许区域 · 放大示意',[-2,90],visible=False,size=18)
        invalid=copy.deepcopy(e['actual']);invalid['initial']=0;invalid['color']='b94747';invalid['ink']='b94747'
        axis=2 if sid.endswith('parallel') else 0
        # Same orientation; a local bulge crosses one bound. Explicit counterexample.
        if 'triangles' in invalid:
            for p in invalid['triangles']:
                if (p[0]==60 if axis==2 else p[2]==30):p[axis]+=12
        for line in invalid.get('world',[]):
            for p in line['points']:
                if p[2]==30:p[0]+=12
        for line in invalid.get('paths',{}).get('front',[]):
            for p in line['points']:
                if (p[0]==60 if axis==2 else p[1]==30):p[1 if axis==2 else 0]+=(-12 if axis==2 else 12)
        e['outside']=invalid
        s.label('outside_name','局部越界',[70,15],visible=False)
        # Give the symbol frame and the enlarged geometric diagram separate room.
        # Restore the canonical old coordinates before translating (idempotent pass).
        old_shift=s.data['parameters'].get('diagram_vertical_offset_mm',0)
        for name in ['datum','zone','actual']:
            for line in e[name].get('paths',{}).get('front',[]):
                for p in line['points']:p[1]-=old_shift
        # Rebuild the counterexample from the unshifted 2D actual trace.
        e['outside']['paths']=copy.deepcopy(e['actual'].get('paths',{}))
        for line in e['outside'].get('paths',{}).get('front',[]):
            for p in line['points']:
                if (p[0]==60 if axis==2 else p[1]==30):p[1 if axis==2 else 0]+=(-12 if axis==2 else 12)
        for name in ['datum','zone','actual','outside','datum_name','zone_name','outside_name']:
            for line in e[name].get('paths',{}).get('front',[]):
                for p in line['points']:p[1]+=18
            for label in e[name].get('labels',[]):label['at'][1]+=18
        s.data['parameters']['diagram_vertical_offset_mm']=18
    if sid.startswith('cut_'):
        # Mark derived intersections, not unrelated points along a circular bracket.
        lines=e['intersection']['world'];pts=[]
        for line in lines:
            ps=line['points']
            for p in ([ps[0],ps[len(ps)//2],ps[-1]] if len(ps)>2 else [ps[0],ps[-1]]):
                if not any(np.linalg.norm(np.array(p)-q)<.05 for q in pts):pts.append(p)
        crosses=[]
        for p in pts:
            crosses += [[add(p,[-.65,0,0]),add(p,[.65,0,0])],[add(p,[0,0,-.65]),add(p,[0,0,.65])]]
        s.projected('common_points',crosses,visible=False,color='d88b37')
    if sid.startswith('intersection_'):
        # One actual point, two generator constraints; projections share the point.
        p=s.data['parameters'];R=p['horizontal_radius'];r=p['vertical_radius'];t=pi/4
        # The inner example opens toward the camera. Its lower intersection is
        # visible inside the cavity; the upper one is hidden behind the roof.
        sign=-1 if sid=='intersection_inner' else 1
        hit=[r*cos(t),r*sin(t),sign*sqrt(R*R-r*r*sin(t)**2)]
        vertical=[[hit[0],hit[1],-R-8 if sign<0 else 0],[hit[0],hit[1],R+8]]
        horizontal=[[-34,hit[1],hit[2]],[34,hit[1],hit[2]]]
        s.projected('point_vertical',[vertical],visible=False,color='d88b37')
        s.projected('point_horizontal',[horizontal],visible=False,color='d88b37')
        s.projected('common_point',[[add(hit,[-1,0,0]),add(hit,[1,0,0])],[add(hit,[0,0,-1]),add(hit,[0,0,1])]],visible=False)
        e['common_point']['triangles']=mesh_triangles(Manifold.sphere(1.1,16).translate(hit))
        s.data['parameters']['demonstration_common_point']=hit
    if sid.startswith('combination_') and sid!='combination_missing':
        # The original verified model already contains world endpoints for each ink.
        # Reuse them to show the exact surface feature in space and all known views.
        for feature in ['slot','slope','bore','round','upright_hole','base_hole']:
            lines=[]
            for key,entity in list(e.items()):
                if '_'+feature+'_' not in key:continue
                for paths in entity.get('paths',{}).values():
                    lines += [p['world_points'] for p in paths if p.get('world_points') and all(q is not None for q in p['world_points'])]
            if lines:s.entity('feature_'+feature,world=lines,visible=False,color='d88b37',role='attention')
    if sid=='read_end_cover':
        scale=120/s.data['provenance']['output_size'][0]
        for name,box in [('surface_I_note',[745,20,80,48]),('surface_II_note',[95,108,65,55]),('surface_III_note',[280,72,100,65])]:
            x,y,w,h=box;s.entity(name,paths={'front':[path(rect(x*scale,y*scale,w*scale,h*scale),'thin')]},visible=False,ink='c17b35',role='attention')
    from course_method_review import enhance as method_enhance
    return method_enhance(s.data)
