import json,hashlib,os
from pathlib import Path
root=Path.cwd(); app=root/'机械制图学习'
p=Path(os.environ['APPDATA'])/'Godot/app_userdata/机械制图学习/practice-v1.json'
raw=p.read_bytes(); student=json.loads(raw)
params=json.loads((app/'assets/examples/points/data.json').read_text(encoding='utf-8'))['parameters']['points_mm']
reference={}
for key,v in params.items():
    n=key.lower(); x,y,z=v
    reference[n+"'"]=[x,z];reference[n]=[x,y];reference[n+"''"]=[-y,z]
rows=[]
for i,v in student['points'].items():
    label=student.get('point_labels',{}).get(i,i)
    rows.append({'label':label,'position_mm':v,'expected_mm':reference.get(label),'matches_named_projection':v==reference.get(label)})
report={'source_file':str(p),'source_sha256':hashlib.sha256(raw).hexdigest(),'question_id':student['question_id'],'parameter_source':'assets/examples/points/data.json#parameters.points_mm','points':rows,'findings':['a与a单撇号的名称交换；b与b单撇号的名称交换。','B正面及侧面投影高度为22，正确为12+8=20。对应上方水平辅助线应从22移至20，两根竖辅助线的上端随之调整。','A三处投影的几何位置正确；B左右及前后距离正确；45度转移连接位置正确。'],'b_helper_endpoints_wrong_height': [{'line_id':line['id'],'end':end,'actual':line[end],'expected':[line[end][0],20]} for line in student['lines'] for end in ['a','b'] if line[end][1]==22],'scope':'只读核对已保存的草稿，不修改原稿，不在程序中加入自动判定或评分。'}
(app/'qa/student-practice-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(rows,ensure_ascii=False))
# Current agreements override historical notes, which remain explicitly historical.
p=root/'AGENTS.md';s=p.read_text(encoding='utf-8');s=s.replace('可撤销/重做','可撤销',1).replace('当前测距由按住D','当前测距由按住M',1).replace('框选后可批量删除，一次撤销/重做','框选后可批量删除，一次撤销',1)
i=s.index('\n\n',s.index('## 当前作图交互'))+2
s=s[:i]+'''最新快捷键：Ctrl+Z撤销，D删除当前选择的学生点/线，按住M量距，松开隐藏；L画线/P标点不变。命名弹窗、文本输入、隐藏页面及教学中不触发文档快捷操作；文本自身的Ctrl+Z仍交给原生输入框。重做按钮、redo_stack及文档重做分支已删除，不增加替代重做入口。程序仍不评分；用户请求检查练习时仅只读核对已保存草稿，不改原稿。

'''+s[i:];p.write_text(s,encoding='utf-8')
p=app/'使用说明.md';s=p.read_text(encoding='utf-8');s=s.replace('按住D临时','按住M临时').replace('L、P、D作为普通文字','L、P、D、M作为普通文字').replace('撤销、重做和删除仅影响自己的作图。','Ctrl+Z撤销，D删除选中的点或线；不提供重做。');i=s.index('\n')+1;s=s[:i]+'''\n快捷键：L画线，P标点，Ctrl+Z撤销，D删除选中的点和线；按住M临时测距，松开隐藏。点名输入期间不触发这些作图操作。重做已删除。\n'''+s[i:];p.write_text(s,encoding='utf-8')
p=app/'开发说明.md';s=p.read_text(encoding='utf-8');i=s.index('\n')+1;s=s[:i]+'''\n最新修正：文档仅保留undo_stack，移除redo按钮、历史数组与命令分支。Ctrl+Z在学生练习可见且无命名窗口/输入焦点时撤销；D单次按下删除当前选择，回声不重复；M按住量距，释放跨页面清除状态。执行文档命令先结束当前内部拖动，防止撤销后仍继续修改已替换的对象。命名输入中的文本原生撤销继续可用，文档不改变。旧段落中D测距及重做为历史。\n'''+s[i:];p.write_text(s,encoding='utf-8')
p=app/'覆盖与核验.md';s=p.read_text(encoding='utf-8');i=s.index('\n')+1;s=s[:i]+'''\n## Ctrl+Z撤销、D删除、M测距及移除重做（2026-10-11）

work/run_point_naming_qa.py经实际双击入口完成64项交互及6项重开，共70项通过。新增D删除单点、单线、混合多选、未选中无变化，Ctrl+Z单次恢复相应事务，命名窗口屏蔽删除与文档撤销，检查重做按钮及历史属性不存在；原命名、L/P、测距及保存检查同步更新为M。两个成功进程正常退出，无残留，用户草稿与观察存档哈希不变。仅Godot内部输入，未移动系统鼠标；本轮未扩展其他章节及原生全屏验收。

用户主动请求核对练习，已只读检查practice-v1.json并按现有A/B参数推导；具体数值及文件哈希保留qa/student-practice-review.json。发现正面/水平投影点名互换、B两上方投影高度22应为20；未修改原练习，也未在程序内新增评分或自动判定。
'''+s[i:];p.write_text(s,encoding='utf-8')
