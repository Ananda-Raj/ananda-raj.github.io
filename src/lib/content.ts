import { parse } from 'yaml';
import { z } from 'astro/zod';

// Imported through Vite so the dev server reloads when the admin saves a file.
const files = import.meta.glob<string>('../data/*.yaml', { query: '?raw', import: 'default', eager: true });

// YAML turns 2018-05 into a string, but 2018 into a number.
const month = z.union([z.string(), z.number()]).transform(String);
const url = z.string().url();

const Profile = z.object({
  name: z.string(),
  role: z.string(),
  company: z.string(),
  location: z.string(),
  phone: z.string().optional(),
  careerStart: month,
  email: z.string().email(),
  site: url,
  links: z.object({ linkedin: url, github: url, medium: url }),
  focus: z.array(z.string()),
  tagline: z.string(),
  contact: z.object({ heading: z.string(), text: z.string() }),
  about: z.array(z.string()),
  offWork: z.string(),
  summary: z.string(),
  languages: z.array(z.object({ name: z.string(), level: z.string() })),
});

const Role = z.object({
  title: z.string(),
  start: month,
  end: month.optional().nullable(),
  note: z.string().optional(),
  cvBullets: z.number().int().positive().optional(),
  highlights: z.array(z.string()).default([]),
});

const Experience = z.array(
  z.object({
    company: z.string(),
    location: z.string().optional(),
    draft: z.boolean().default(false),
    roles: z.array(Role).min(1),
  }),
);

const Skills = z.array(z.object({ group: z.string(), items: z.array(z.string()) }));

const Credentials = z.object({
  certifications: z.array(
    z.object({ name: z.string(), issuer: z.string(), expired: z.boolean().default(false), url: url.optional() }),
  ),
  recognition: z.array(z.object({ name: z.string(), issuer: z.string(), since: z.number().optional(), url: url.optional() })),
  education: z.array(z.object({ degree: z.string(), school: z.string(), start: z.number(), end: z.number() })),
});

const Projects = z.array(
  z.object({
    name: z.string(),
    show: z.boolean().default(true),
    status: z.string().optional(),
    summary: z.string(),
    tech: z.array(z.string()).default([]),
    url: url.optional(),
    repo: url.optional(),
  }),
);

const Settings = z.object({ apiUrl: z.union([url, z.literal('')]).default(''), assistant: z.boolean().default(true) });

function load<T extends z.ZodTypeAny>(file: string, schema: T): z.infer<T> {
  const raw = parse(files[`../data/${file}`]) ?? {};
  const result = schema.safeParse(raw);
  if (!result.success) {
    throw new Error(`src/data/${file} is invalid:\n${result.error.issues.map((i) => `  ${i.path.join('.')}: ${i.message}`).join('\n')}`);
  }
  return result.data;
}

export const profile = load('profile.yaml', Profile);
export const experience = load('experience.yaml', Experience);
export const skills = load('skills.yaml', Skills);
export const credentials = load('credentials.yaml', Credentials);
export const projects = load('projects.yaml', Projects).filter((p) => p.show);
export const settings = load('settings.yaml', Settings);

// PUBLIC_API_URL overrides the setting for local testing.
export const apiUrl = (import.meta.env.PUBLIC_API_URL || settings.apiUrl).replace(/\/$/, '');
export const assistantOn = Boolean(apiUrl) && settings.assistant;

// Stops the live build from publishing placeholder text.
const drafts = experience.filter((e) => e.draft).map((e) => e.company);
if (drafts.length && process.env.CI) {
  throw new Error(`Draft content in experience.yaml (${drafts.join(', ')}). Review it and remove "draft: true" before publishing.`);
}

// "V Ananda Raj" -> "Ananda Raj" for the greeting.
export const firstName = profile.name.split(' ').filter((w) => w.replace('.', '').length > 1).join(' ');

export const years = Math.floor((Date.now() - new Date(`${profile.careerStart}-01`).getTime()) / (365.25 * 864e5));
export const summary = profile.summary.replace('{years}', `${years}+`);
// Shows +918129524634 as +91 81295 24634.
export const phoneDisplay = profile.phone?.replace(/^\+91(\d{5})(\d{5})$/, '+91 $1 $2') ?? profile.phone;
export const cvFile = `${profile.name.replace(/\s+/g, '-')}-CV.pdf`;
