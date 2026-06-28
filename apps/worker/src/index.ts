import { Hono } from 'hono';
import { cors } from 'hono/cors';
import {
  extractMedia,
  mediaType,
  pickFormat,
  safeFilename,
  toAnalyzeResponse,
} from './extractors';
import type { AnalyzeResponse, Env } from './types';

type Bindings = Env;

const app = new Hono<{ Bindings: Bindings }>();

function corsOrigins(env: Bindings): string[] {
  const raw = env.CORS_ORIGINS ?? 'http://localhost:4321';
  return raw.split(',').map((o) => o.trim()).filter(Boolean);
}

app.use('*', async (c, next) => {
  const allowed = corsOrigins(c.env);
  const middleware = cors({
    origin: (origin) => {
      if (!origin) return allowed[0] ?? '*';
      if (allowed.includes(origin)) return origin;
      if (origin.endsWith('.pages.dev')) return origin;
      if (origin.endsWith('.github.io')) return origin;
      return allowed[0] ?? origin;
    },
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    allowHeaders: ['Content-Type'],
    maxAge: 86400,
  });
  return middleware(c, next);
});

app.get('/health', (c) =>
  c.json({ status: 'ok', service: 'download-everything', runtime: 'cloudflare-workers' }),
);

app.post('/analyze', async (c) => {
  let body: { url?: string };
  try {
    body = await c.req.json<{ url?: string }>();
  } catch {
    return c.json({ detail: 'Invalid JSON body.' }, 400);
  }

  const url = body.url?.trim();
  if (!url) return c.json({ detail: 'url is required.' }, 422);

  try {
    const result = await extractMedia(url);
    return c.json(toAnalyzeResponse(url, result) satisfies AnalyzeResponse);
  } catch (err) {
    const backend = c.env.YTDLP_BACKEND?.replace(/\/$/, '');
    if (backend) {
      try {
        const proxy = await fetch(`${backend}/analyze`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url }),
        });
        const payload = (await proxy.json()) as AnalyzeResponse | { detail?: string };
        return c.json(payload, proxy.ok ? 200 : 422);
      } catch {
        /* fall through */
      }
    }
    const message = err instanceof Error ? err.message : 'Analysis failed.';
    return c.json({ detail: message }, 422);
  }
});

app.get('/download', async (c) => {
  const url = c.req.query('url')?.trim();
  const formatId = c.req.query('format_id') ?? 'best';
  const filename = c.req.query('filename') ?? undefined;

  if (!url) return c.json({ detail: 'url is required.' }, 422);

  try {
    const result = await extractMedia(url);
    const format = pickFormat(result, formatId);
    if (!format) return c.json({ detail: 'Format not found.' }, 422);

    const upstream = await fetch(format.direct_url, {
      headers: format.headers,
      redirect: 'follow',
    });

    if (!upstream.ok || !upstream.body) {
      return c.json({ detail: `Upstream returned ${upstream.status}.` }, 422);
    }

    const outName = filename || safeFilename(result.title, format.ext);
    const headers = new Headers();
    headers.set('Content-Type', mediaType(format.ext));
    headers.set('Content-Disposition', `attachment; filename="${outName}"`);
    const len = upstream.headers.get('Content-Length');
    if (len) headers.set('Content-Length', len);

    return new Response(upstream.body, { status: 200, headers });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Download failed.';
    return c.json({ detail: message }, 422);
  }
});

export default app;
