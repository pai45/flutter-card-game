const fs = require('fs');

const outputPath = 'docs/data/ipl_players.md';

const csvContent = fs.readFileSync('ipl_players.csv', 'utf8');
const lines = csvContent.trim().split('\n');

let mdContent = '# IPL 2026 Players\n\n';
mdContent += '| Name | Short Name | Team | Team Code | Role | Rating | Tier |\n';
mdContent += '|---|---|---|---|---|---|---|\n';

// Skip header (i=1)
for (let i = 1; i < lines.length; i++) {
  const columns = lines[i].split(',');
  if (columns.length >= 7) {
    mdContent += `| ${columns[0]} | ${columns[1]} | ${columns[2]} | ${columns[3]} | ${columns[4]} | ${columns[5]} | ${columns[6]} |\n`;
  }
}

fs.mkdirSync('docs/data', { recursive: true });
fs.writeFileSync(outputPath, mdContent);
console.log(`Successfully created ${outputPath}`);
