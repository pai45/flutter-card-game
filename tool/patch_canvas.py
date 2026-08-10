from pathlib import Path
p = Path(r"C:\Users\priya\.cursor\projects\c-Users-priya-OneDrive-Desktop-flutter-projects-card-game\canvases\player-cards-database.canvas.tsx")
text = p.read_text(encoding="utf-8")
start = text.find("      <Table")
end = text.find("      />", start)
if start < 0 or end < 0:
    raise SystemExit(f"markers missing {start} {end}")
end = end + len("      />")
new = """      <Table
        stickyHeader
        striped
        headers={[
          'Player',
          'Sport',
          'Role',
          'Team / country',
          'Pos',
          'OVR',
          'Tier',
          'Image',
          'Portrait asset',
        ]}
        columnAlign={[
          'left',
          'left',
          'left',
          'left',
          'left',
          'right',
          'left',
          'left',
          'left',
        ]}
        rows={filtered.slice(0, 400).map((p) => {
          const team =
            p.code && p.code !== p.teamOrCountry
              ? p.teamOrCountry + ' (' + p.code + ')'
              : p.teamOrCountry;
          return [
            p.name,
            titleCase(p.sport),
            p.role,
            team,
            p.pos,
            p.ovr,
            p.tier,
            p.img ? 'Yes' : '\u2014',
            p.portrait || '\u2014',
          ];
        })}
      />"""
text = text[:start] + new + text[end:]
text = text.replace("<Spacer height={8} />", "<Spacer />")
p.write_text(text, encoding="utf-8")
print("ok")
print("columns left", text.count("columns={["))
print("sortable left", text.count("sortable"))