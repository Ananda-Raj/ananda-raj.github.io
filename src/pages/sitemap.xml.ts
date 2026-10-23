import type { APIRoute } from 'astro';
import { assistantOn } from '../lib/content';

export const GET: APIRoute = ({ site }) => {
  const urls = ['/', '/cv/', ...(assistantOn ? ['/how-it-works/'] : [])].map((p) => `<url><loc>${new URL(p, site)}</loc></url>`).join('');
  return new Response(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`, {
    headers: { 'Content-Type': 'application/xml' },
  });
};
