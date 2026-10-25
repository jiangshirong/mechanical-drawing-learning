from pathlib import Path
p=Path('机械制图学习/practice_board.gd');s=p.read_text(encoding='utf-8');s=s.replace('if not existing.is_empty() and existing.kind == "line":\n\t\t\t\tchoose_hit(existing)\n\t\t\t\treturn','''if not existing.is_empty() and existing.kind == "line":
\t\t\t\tvar line := find_line(existing.id)
\t\t\t\t# Body clicks select; endpoint clicks can start a new line.
\t\t\t\tif p.distance_to(Canvas.at(line[existing.end])) > 9.0/view.zoom:
\t\t\t\t\tchoose_hit(existing)
\t\t\t\t\treturn''');p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/practice_view.gd');s=p.read_text(encoding='utf-8').replace('elif edit_hit.kind == "point": board.click_content','else: board.click_content');p.write_text(s,encoding='utf-8')
p=Path('机械制图学习/point_naming_check.gd');s=p.read_text(encoding='utf-8');a=s.index('\tawait hold_key(KEY_D,true)\n\tawait hover_mm([-8,-6])');s=s[:a]+'''\tawait click_mm([-15,-10])
\tcheck("endpoint_can_start_new_line",b.pending==[-15.0,-10.0])
\tawait click_mm([-20,-15])
\tcheck("endpoint_new_line_complete",b.document.lines.size()==2 and b.document.lines[1].a==[-15.0,-10.0])
\tb.command("undo")
\tcheck("connected_line_undo",b.document==prior)
'''+s[a:];p.write_text(s,encoding='utf-8')
