// What the site assistant knows: a plain-text profile built from the same data as the site.
import type { APIRoute } from 'astro';
import { profile, experience, skills, credentials, projects, years, firstName, summary, phoneDisplay } from '../../lib/content';
import { getPosts, getRepos } from '../../lib/feeds';
import { range } from '../../lib/dates';

export const GET: APIRoute = async () => {
  const [posts, repos] = await Promise.all([getPosts(), getRepos()]);
  const { certifications, recognition, education } = credentials;
  const out: string[] = [];
  const add = (...lines: string[]) => out.push(...lines);

  add(
    `Name: ${profile.name}`,
    `Role: ${profile.role} at ${profile.company}`,
    `Location: ${profile.location}`,
    `Experience: ${years}+ years`,
    `Contact: the contact form at ${profile.site}/#contact, email ${profile.email}${profile.phone ? `, phone ${phoneDisplay}` : ''}, LinkedIn ${profile.links.linkedin}`,
    '',
    `Summary: ${summary}`,
    '',
    'About:',
    ...profile.about.map((p) => `- ${p}`),
    `- ${profile.offWork}`,
    '',
    'Skills:',
    ...skills.map((s) => `- ${s.group}: ${s.items.join(', ')}`),
    '',
    'Work history (newest first):',
  );
  for (const e of experience) {
    for (const r of e.roles) {
      add(`- ${r.title}, ${e.company}${e.location ? ` (${e.location})` : ''}, ${range(r.start, r.end)}${r.note ? `. ${r.note}` : ''}`);
      r.highlights.forEach((h) => add(`  * ${h}`));
    }
  }
  if (projects.length) {
    add('', 'Projects:', ...projects.map((p) => `- ${p.name}${p.status ? ` (${p.status})` : ''}: ${p.summary} ${[p.url, p.repo].filter(Boolean).join(' ')}`.trim()));
  }
  add(
    '',
    'Certifications:',
    ...certifications.map((c) => `- ${c.name}, ${c.issuer}${c.expired ? ' (expired)' : ''}`),
    '',
    'Community:',
    ...recognition.map((r) => `- ${r.name}, ${r.issuer}${r.since ? `, since ${r.since}` : ''}`),
    '',
    'Education:',
    ...education.map((e) => `- ${e.degree}, ${e.school}, ${e.start}–${e.end}`),
    '',
    `Languages: ${profile.languages.map((l) => `${l.name} (${l.level})`).join(', ')}`,
  );
  if (posts.length) {
    add('', 'Articles on Medium:', ...posts.map((p) => `- ${p.title} (${p.date.slice(0, 7)}) ${p.url} : ${p.excerpt}`));
  }
  if (repos.length) {
    add('', 'Public GitHub repositories:', ...repos.map((r) => `- ${r.name}${r.description ? `: ${r.description}` : ''} ${r.url}`));
  }

  const body = { name: profile.name, firstName, role: profile.role, location: profile.location, text: out.join('\n') };
  return new Response(JSON.stringify(body), { headers: { 'Content-Type': 'application/json' } });
};
