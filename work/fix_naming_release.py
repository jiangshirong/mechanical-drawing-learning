from pathlib import Path
p=Path('机械制图学习/practice_view.gd');s=p.read_text(encoding='utf-8');s=s.replace('var naming_release := false\n','');s=s.replace('\t\t\tif naming_release and not event.pressed:\n\t\t\t\tnaming_release = false\n\t\t\t\taccept_event()\n\t\t\t\treturn\n','').replace('\t\t\t\tnaming_release = true\n','');p.write_text(s,encoding='utf-8')
