from course_geometry import *
from course_solids import hatches,plane_sheet

def shaft():
    body=cylinder(15,32,'x',(-40,0,0))+cylinder(22,6,'x',(-8,0,0))+cylinder(18,46,'x',(-2,0,0))
    # Front-facing keyseat, depth 3 from the left-hand shaft surface.
    key=Manifold.cube([22,10,6]).translate([-35,-22,-3])
    for x in [-35,-13]:key+=cylinder(3,10,'y',(x,-12,0))
    body-=key
    body-=cylinder(2.5,7,centre=(-24,0,10))+Manifold.cylinder(2.5,0,2.5,48).translate([-24,0,7.5])
    # Two communicating blind holes, taken from the original given figure.
    body-=cylinder(3,30,'x',(14,0,0))+Manifold.cylinder(3,0,3,48).rotate([0,90,0]).translate([11,0,0])
    body-=cylinder(3,18,centre=(20,0,0))+Manifold.cylinder(3,0,3,48).translate([20,0,-3])
    return body

def all_scenes():
    body=shaft()
    for kind,x in [('key',-24),('hole',20)]:
        s=Scene('removed_'+kind,['t03-q07'],views=('front','left'))
        add_body(s,'body',body)
        section=body.rotate([0,-90,0]).slice(x)
        # Local cut axes (-z,y) -> (y,-z), looking along +x as the indicated cutting arrows.
        rings=[[[float(p[1]),float(p[0])] for p in ring] for ring in section.to_polygons()]
        s.ink('outline','left',[ring+[ring[0]] for ring in rings],visible=False)
        s.ink('hatching','left',hatches(rings),'thin',visible=False)
        boundary,mesh=plane_sheet([1,0,0],x,24);s.entity('cutting_plane',world=[boundary],mesh=mesh,visible=False,opacity=.2,color='c69762')
        s.ink('cut_location','front',[[[x,-25],[x,25]]],'axis',visible=False)
        s.label('direction','沿箭头方向看截面',[x-10,34],visible=False)
        s.data['view_titles']={'front':'已知投影','left':'移出断面'}
        s.data['parameters']={'left_radius':15,'right_radius':18,'key_depth':3,'key_width':6,'cut_x':x,'view_direction':[1,0,0]}
        s.data['provenance'].update(note='按原题孔槽关系重绘，3 mm为题给键槽深度；其余为教学尺度',source_conflict='原DOC答案右侧已知图与原题的两盲孔表达不同；本场景以原题给出的相交盲孔为准，不照抄替换后的通孔图')
        yield s
    # Contrast for the source selection question: side slots are open notches,
    # while the conical drill bottom must remain a continuous curved outline.
    s=Scene('removed_compare',['t08-q09'],views=('front','left'))
    b=cylinder(16,56,'x',(-28,0,0))
    for y in [-17,11]:b-=Manifold.cube([30,6,7]).translate([-15,y,-3.5])
    b-=cylinder(4,7,centre=(0,0,11))+Manifold.cylinder(4,0,4,48).translate([0,0,7])
    add_body(s,'body',b)
    sec=b.rotate([0,-90,0]).slice(0)
    rings=[[[float(p[1]),float(p[0])] for p in ring] for ring in sec.to_polygons()]
    s.ink('correct','left',[ring+[ring[0]] for ring in rings],visible=False)
    s.ink('hatching','left',hatches(rings),'thin',visible=False)
    s.ink('wrong_slots','left',[[[-16,-3.5],[-16,3.5]],[[16,-3.5],[16,3.5]]],visible=False,ink='a64e46')
    s.ink('rear_arc','left',[[[y,-sqrt(16**2-y*y)] for y in np.linspace(-4,4,33)]],visible=False)
    s.data['view_titles']={'front':'已知结构','left':'断面比较'};s.data['verified_answer']={'source':'原DOC第8套第11页','correct_choice':'b'}
    yield s
