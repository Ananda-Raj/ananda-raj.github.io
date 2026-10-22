import fs from 'node:fs';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';
import { profile } from './content';

export type Post = { title: string; url: string; date: string; excerpt: string; image?: string; tags: string[] };
export type Repo = { name: string; url: string; description: string; language: string | null; updated: string };

// Last good copies, used when Medium or GitHub can't be reached during a build.
const cacheDir = path.resolve('src/data/cache');
const readCache = <T>(f: string): T[] => {
  try {
    return JSON.parse(fs.readFileSync(path.join(cacheDir, f), 'utf8'));
  } catch {
    return [];
  }
};
const writeCache = (f: string, data: unknown) => {
  fs.mkdirSync(cacheDir, { recursive: true });
  fs.writeFileSync(path.join(cacheDir, f), JSON.stringify(data, null, 2) + '\n');
};

const text = (html: string) =>
  html
    .replace(/<figure[\s\S]*?<\/figure>/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&#39;|&#x27;|&rsquo;/g, '’')
    .replace(/&quot;|&#34;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();

async function fetchPosts(): Promise<Post[]> {
  const handle = new URL(profile.links.medium).hostname.split('.')[0];
  const res = await fetch(`https://medium.com/feed/@${handle}`, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`Medium ${res.status}`);
  const feed = new XMLParser({ ignoreAttributes: false }).parse(await res.text());
  const items = [].concat(feed?.rss?.channel?.item ?? []);
  return items.map((i: any) => {
    const html = String(i['content:encoded'] ?? '');
    const body = text(html);
    return {
      title: String(i.title),
      url: String(i.link).split('?')[0],
      date: new Date(i.pubDate).toISOString(),
      excerpt: body.length > 220 ? body.slice(0, 220).replace(/\s+\S*$/, '') + '…' : body,
      image: [...html.matchAll(/<img[^>]+src="([^"]+)"/g)].map((m) => m[1]).find((src) => !src.includes('/_/stat')),
      tags: [].concat(i.category ?? []).map(String),
    };
  });
}

async function fetchRepos(): Promise<Repo[]> {
  const user = new URL(profile.links.github).pathname.split('/')[1];
  const headers: Record<string, string> = { Accept: 'application/vnd.github+json' };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const res = await fetch(`https://api.github.com/users/${user}/repos?per_page=100&sort=pushed`, { headers, signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`GitHub ${res.status}`);
  const repos: any[] = await res.json();
  return repos
    .filter((r) => !r.fork && !r.archived && !r.name.endsWith('.github.io'))
    .map((r) => ({ name: r.name, url: r.html_url, description: r.description ?? '', language: r.language, updated: r.pushed_at }));
}

async function withCache<T>(name: string, file: string, get: () => Promise<T[]>): Promise<T[]> {
  try {
    const fresh = await get();
    if (fresh.length) writeCache(file, fresh);
    return fresh.length ? fresh : readCache<T>(file);
  } catch (err) {
    console.warn(`[feeds] ${name} unavailable (${(err as Error).message}); using cached copy.`);
    return readCache<T>(file);
  }
}

let posts: Promise<Post[]> | undefined;
let repos: Promise<Repo[]> | undefined;
export const getPosts = () => (posts ??= withCache('Medium', 'medium.json', fetchPosts));
export const getRepos = () => (repos ??= withCache('GitHub', 'github.json', fetchRepos));
