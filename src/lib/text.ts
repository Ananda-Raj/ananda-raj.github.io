// Splits multi-line text into paragraphs and bullet lists ("•", "-" or "*" lines).
export type Block = { type: 'p' | 'list'; lines: string[] };

const BULLET = /^[•*-]\s+/;

export function blocks(text: string): Block[] {
  const out: Block[] = [];
  for (const chunk of text.trim().split(/\n\s*\n/)) {
    let current: Block | undefined;
    for (const raw of chunk.split('\n')) {
      const line = raw.trim();
      if (!line) continue;
      const type = BULLET.test(line) ? 'list' : 'p';
      if (current?.type !== type) out.push((current = { type, lines: [] }));
      current.lines.push(line.replace(BULLET, ''));
    }
  }
  return out;
}

// First paragraph, without a repeated "Name:" prefix.
export function firstLine(text: string, name: string) {
  const first = blocks(text)[0]?.lines.join(' ') ?? '';
  return first.startsWith(`${name}:`) ? first.slice(name.length + 1).trim() : first;
}
