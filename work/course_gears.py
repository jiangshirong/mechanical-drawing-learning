"""Gear dimensions, involute explanatory mesh and separate conventional ink."""
from course_geometry import *
from course_solids import hatches

def involute_outline(m,z,phase=0):
    rp=m*z/2;rb=rp*cos(pi/9);ra=m*(z+2)/2;rf=m*(z-2.5)/2
    inv_a=np.tan(pi/9)-pi/9
    def half(r):
        a=np.arccos(min(1,rb/r));return pi/(2*z)+inv_a-(np.tan(a)-a)
    pts=[]
    for i in range(z):
        centre=TAU*i/z+phase
        for r,sign in [(rf,-1)]+[(r,-1) for r in np.linspace(max(rf,rb),ra,6)]+[(r,1) for r in np.linspace(ra,max(rf,rb),6)]+[(rf,1)]:
            angle=centre+sign*half(max(r,rb));pts.append([r*cos(angle),r*sin(angle)])
    return pts

def gear_scene(pair=False):
    source='t01-q08' if pair else 't02-q07';s=Scene('gear_pair' if pair else 'gear_single',[source],views=('front','left'))
    m=4 if pair else 3;zs=[20,35] if pair else [20];a=m*sum(zs)/2 if pair else 0
    widths=[28,42] if pair else [24];bores=[10,20] if pair else [10]
    s.data['parameters']={'module':m,'teeth':zs,'centre_distance':a,'drawing_scale':.5 if pair else 1,'standard_full_depth':True,'face_width':widths,'bore_radius':bores,'pressure_angle':20,'non_given':'齿宽与孔径按原图统一教学尺度；不作为题给尺寸','mesh_note':'标准渐开线齿廓，齿根过渡简化；工程投影按规定画法单独生成'}
    for i,z in enumerate(zs):
        d=m*z;da=m*(z+2);df=m*(z-2.5);zc=i*a;b=widths[i];hole=bores[i]
        phase=pi/2 if i==0 else -pi/2+pi/z
        body=CrossSection([involute_outline(m,z,phase)]).extrude(b)-cylinder(hole,b+2,centre=(0,0,-1))
        # (u,v,w)->(w,u,v), so the two axes are horizontal x and spaced vertically.
        body=body.rotate([90,0,90]).translate([-b/2,0,zc])
        add_body(s,f'gear{i}',body,project_views=False,color='7ca7bb' if i==0 else 'b9a77c')
        for kind,radius,style in [('addendum',da/2,'solid'),('pitch',d/2,'axis'),('root',df/2,'thin')]:
            s.ink(f'{kind}{i}','left',[circle(radius,(0,-zc))],style,visible=False)
        key=hole*.25
        bore=circle(hole,(0,-zc),n=96,start=.5*pi+.12,end=2.5*pi-.12)
        bore += [[key,-zc+hole+key],[-key,-zc+hole+key],bore[0]]
        s.ink(f'bore{i}','left',[bore])
        s.ink(f'axis{i}','left',[[[-da*.6,-zc],[da*.6,-zc]],[[0,-zc-da*.6],[0,-zc+da*.6]]],'axis')
        s.ink(f'side{i}','front',[rect(-b/2,-zc-da/2,b,da),[[-b/2,-zc-hole],[b/2,-zc-hole]],[[-b/2,-zc+hole],[b/2,-zc+hole]]],visible=False)
        s.ink(f'side_pitch{i}','front',[[[-b*.65,-zc-d/2],[b*.65,-zc-d/2]],[[-b*.65,-zc+d/2],[b*.65,-zc+d/2]]],'axis',visible=False)
        s.ink(f'side_root{i}','front',[[[-b/2,-zc-df/2],[b/2,-zc-df/2]],[[-b/2,-zc+df/2],[b/2,-zc+df/2]]],visible=False)
        rings=[rect(-b/2,-zc-df/2,b,df/2-hole)[:-1],rect(-b/2,-zc+hole,b,df/2-hole)[:-1]]
        lines=hatches(rings,4)
        if i:lines=[[[-p[0],p[1]] for p in line] for line in lines]
        s.ink(f'gear_hatch{i}','front',lines,'thin',visible=False)
        for name,caption,at_ in [('d',f'd = {d:g} mm',[da/2+10,-zc]),('da',f'dₐ = {da:g} mm',[-da*.35,-zc-da/2-12]),('df',f'df = {df:g} mm',[da/2+10,-zc+18])]:
            s.label(f'label_{name}{i}',caption,at_,view='left',visible=False)
    if pair:
        s.ink('centre_distance','left',[[[0,0],[0,-a]]],'axis',visible=False)
        s.label('centre_label',f'a = {a:g} mm',[max(zs)*m/2+14,-a*.5],view='left',visible=False)
        # At the mesh region, suppress the overlapping part of each addendum circle.
        radii=[m*(z+2)/2 for z in zs];arcs=[]
        for i,r in enumerate(radii):
            cur=[]
            for p in circle(r,(0,-i*a),n=256):
                other=[0,-(1-i)*a]
                outside=sum((p[k]-other[k])**2 for k in [0,1])>=radii[1-i]**2-.001
                if outside:cur.append(p)
                elif len(cur)>1:arcs.append(cur);cur=[]
            if len(cur)>1:arcs.append(cur)
        s.ink('meshing_contours','left',arcs,visible=False)
        # One tooth boundary is visible, the mating tooth boundary is hidden in the axial section.
        s.ink('contact_visible','front',[[[-widths[0]/2,-radii[0]],[widths[0]/2,-radii[0]]]],visible=False)
        s.ink('contact_hidden','front',[[[-widths[0]/2,-a+radii[1]],[widths[0]/2,-a+radii[1]]]],'dashed',visible=False)
    return s
