// Reads the CV PDF back as plain text, the way an ATS does, and fails the build on problems.
import fs from 'node:fs';
import { getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs';
import { parse } from 'yaml';

const profile = parse(fs.readFileSync('src/data/profile.yaml', 'utf8'));
const experience = parse(fs.readFileSync('src/data/experience.yaml', 'utf8'));
const file = `dist/${profile.name.replace(/\s+/g, '-')}-CV.pdf`;

const doc = await getDocument({ data: new Uint8Array(fs.readFileSync(file)), verbosity: 0 }).promise;
let text = '';
for (let i = 1; i <= doc.numPages; i++) {
  const content = await (await doc.getPage(i)).getTextContent();
  text += content.items.map((it) => it.str + (it.hasEOL ? '\n' : '')).join('') + '\n';
}
fs.mkdirSync('.astro', { recursive: true });
fs.writeFileSync('.astro/cv.txt', text);

const lines = text.split('\n').map((l) => l.trim().toUpperCase());
const problems = [];

if (/[\uFB00-\uFB06]/.test(text)) problems.push('Ligature characters found; some ATS misread these words.');

// Section order on the CV. Required sections must exist; the rest are checked only when present.
const ORDER = ['SUMMARY', 'SKILLS', 'EXPERIENCE', 'CERTIFICATIONS', 'COMMUNITY AND RECOGNITION', 'PROJECTS', 'PUBLICATIONS', 'EDUCATION', 'LANGUAGES'];
const REQUIRED = ['SUMMARY', 'SKILLS', 'EXPERIENCE', 'EDUCATION'];
const found = ORDER.map((h) => [h, lines.indexOf(h)]).filter(([, at]) => at !== -1);
for (const h of REQUIRED) {
  if (!found.some(([f]) => f === h)) problems.push(`Heading "${h}" missing.`);
}
for (let i = 1; i < found.length; i++) {
  if (found[i][1] < found[i - 1][1]) problems.push(`Heading "${found[i][0]}" should come after "${found[i - 1][0]}".`);
}

for (const needle of [profile.name, profile.email, profile.role, ...experience.map((e) => e.company)]) {
  if (!text.includes(needle)) problems.push(`"${needle}" not found in the PDF text.`);
}

if (problems.length) {
  console.error(`[cv-check] ${file}\n  - ${problems.join('\n  - ')}`);
  process.exit(1);
}
console.log(`[cv-check] ${doc.numPages} page(s), ${found.length} sections in order, text readable.`);
