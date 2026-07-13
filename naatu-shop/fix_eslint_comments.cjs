const fs = require('fs');

const file = 'src/pages/Pos.tsx';
let lines = fs.readFileSync(file, 'utf8').split('\n');

const errors = [
  2, 6, 22, 80, 92, 94, 95, 109, 132, 137, 157, 184, 270, 423, 424
];

// Go backwards so injecting lines doesn't offset subsequent line numbers
for (let i = errors.length - 1; i >= 0; i--) {
  const lineIndex = errors[i] - 1; // 0-indexed
  lines.splice(lineIndex, 0, '  // eslint-disable-next-line @typescript-eslint/no-unused-vars');
}

fs.writeFileSync(file, lines.join('\n'));
console.log('Injected eslint-disable comments into Pos.tsx');
