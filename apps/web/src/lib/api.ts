export interface MediaFormat {
  format_id: string;
  label: string;
  ext: string;
  resolution?: string | null;
  fps?: number | null;
  vcodec?: string | null;
  acodec?: string | null;
  filesize?: number | null;
  filesize_approx?: number | null;
  tbr?: number | null;
  is_video: boolean;
  is_audio: boolean;
  is_image: boolean;
}

export interface AnalyzeResponse {
  url: string;
  title?: string | null;
  description?: string | null;
  thumbnail?: string | null;
  uploader?: string | null;
  duration?: number | null;
  platform?: string | null;
  extractor?: string | null;
  formats: MediaFormat[];
  error?: string | null;
}

/** Cloudflare Worker API — always warm (no Render cold starts). Override at build time. */
const WORKER_API = 'https://download-everything-api.drmikecrypto.workers.dev';

export const API_URL =
  (typeof import.meta !== 'undefined' && import.meta.env?.PUBLIC_API_URL) ||
  (typeof window !== 'undefined' &&
  (window.location.hostname.endsWith('github.io') || window.location.hostname.endsWith('pages.dev'))
    ? WORKER_API
    : 'http://localhost:8000');

export function formatDuration(seconds: number | null | undefined): string {
  if (!seconds) return '';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function formatBytes(bytes: number | null | undefined): string {
  if (!bytes) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = bytes;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

export function downloadUrl(mediaUrl: string, formatId: string): string {
  const params = new URLSearchParams({ url: mediaUrl, format_id: formatId });
  return `${API_URL}/download?${params.toString()}`;
}

function friendlyFetchError(err: unknown): Error {
  if (err instanceof TypeError && /failed to fetch/i.test(err.message)) {
    return new Error('Could not reach the download server. Check your connection and try again.');
  }
  if (err instanceof Error) return err;
  return new Error('Something went wrong.');
}

async function postAnalyze(url: string): Promise<AnalyzeResponse> {
  const res = await fetch(`${API_URL}/analyze`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    const detail = (err as { detail?: unknown }).detail;
    throw new Error(
      typeof detail === 'string'
        ? detail
        : Array.isArray(detail)
          ? String((detail[0] as { msg?: string })?.msg ?? 'Analysis failed')
          : 'Analysis failed',
    );
  }
  return res.json();
}

export async function analyzeUrl(
  url: string,
  onStatus?: (message: string) => void,
): Promise<AnalyzeResponse> {
  try {
    onStatus?.('Analyzing link…');
    return await postAnalyze(url);
  } catch (err) {
    throw friendlyFetchError(err);
  }
}
