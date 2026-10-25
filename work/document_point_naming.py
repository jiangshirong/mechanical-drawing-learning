from pathlib import Path
p=Path('AGENTS.md');s=p.read_text(encoding='utf-8');a=s.index('点章节学生点名为工具行输入框');z=s.index('\n\n',a);s=s[:a]+'''点章节不再提供常驻“点名”输入框：标点模式单击放置未命名点，双击已有点打开模态命名框；单击已有点只选择，不移动或复制它。允许中文、撇号等自由名称，重名不能覆盖别的点；清空名称可保留未命名点。命名仅改显示名称，不改内部点ID、位置或画布大小，可撤销/重做。practice-v1.json版本1增加可选point_labels映射（ID到显示名称），旧档缺此字段时以原字典键显示点名；未命名点用独立ID。命名框不入档，模式切换/教学关闭弹窗，教学中禁用输入。最新入口work/run_point_naming_qa.py；之前依赖常驻输入框的两份QA脚本属于历史交互，不再作为当前命名功能验收。'''+s[z:];s=s.replace('右键单击取消未完成预览；','右键单击取消选中及未完成预览，不修改作图或撤销历史；',1);p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/使用说明.md');s=p.read_text(encoding='utf-8');a=s.index('标点工具在');z=s.index('选择线段后',a);s=s[:a]+'''标点模式单击放点，双击已放置的点弹出输入框，自由命名或修改名称；支持中文、字母和撇号，重名会提示，不覆盖其他点。未命名点也可保留。右键单击取消选中和未完成线段，右键拖动仍为框选。'''+s[z:];p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/开发说明.md');s=p.read_text(encoding='utf-8');i=s.index('\n',s.index('# '))+1;s=s[:i]+'''
当前命名交互（替代下方常驻输入框历史）：标点单击产生独立未命名点，双击点弹出内嵌模态ConfirmationDialog。名称修改只更新可选document.point_labels，不改变points字典ID及毫米位置；旧版本1无标签映射的草稿直接使用原键作为显示名称。标签空字符串代表未命名，重复非空名称及控制字符拒绝，损坏标签引用拒绝并保护原档。命名事务可撤销，弹窗关闭/取消不写名称，模式切换关闭弹窗。右键单击deselect()取消选择与预览；右拖框选保持原语义。最新专项入口work/run_point_naming_qa.py；points_learning_check/practice_tools_check中常驻输入框相关场景是历史场景，现由point_naming_check替代，旧报告不算本轮检查。
'''+s[i:];p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/覆盖与核验.md');s=p.read_text(encoding='utf-8');i=s.index('\n')+1;s=s[:i]+'''
## 点命名弹窗与右键取消选择（2026-10-11）

最新实际双击启动入口：work/run_point_naming_qa.py。32项交互检查及6项重开检查通过，报告qa/point-naming-check.json、point-naming-reopen.json，截图point-naming-dialog.png。包含多未命名点、双击不复制、输入聚焦、中文/撇号输入、重名保护、重命名不改位置、撤销重做、取消弹窗、右键点/线取消选择不改历史、右拖框选与批量删除撤销、教学退出保持草稿、旧存档格式接受、扩展标签校验及存档重开。

两个成功验收进程均正常退出，无本次进程残留；原用户草稿与观察存档哈希不变，内部事件未移动系统鼠标。此前一轮QA脚本自身类型推断错误已修复，其窗口请求正常关闭；随后修正QA的内嵌弹窗焦点点击，最终上述报告通过。此前常驻点名输入框专项报告属于历史版本；本轮未重跑其他六章或原生全屏检查。
'''+s[i:];p.write_text(s,encoding='utf-8')
