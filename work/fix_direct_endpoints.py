from pathlib import Path
p=Path('机械制图学习/practice_board.gd');s=p.read_text(encoding='utf-8');s=s.replace('\tif handles_only: return {}','''\t# Endpoints are editable directly in both remaining tools.
\tfor line in document.lines:
\t\tfor key in ["a","b"]:
\t\t\tif p.distance_to(Canvas.at(line[key])) <= threshold:
\t\t\t\treturn {"kind":"line","id":line.id,"end":key}
\tif handles_only: return {}''',1);p.write_text(s,encoding='utf-8')
