import type { ExtractResult, ResolvedFormat } from './types';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

export function humanSize(size: number | undefined): string {
  if (!size) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = size;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

function formatLabel(parts: Array<string | number | undefined | null>): string {
  return parts.filter(Boolean).join(' · ');
}

function decodeEscapes(value: string): string {
  return value.replace(/\\u0026/g, '&').replace(/\\\//g, '/').replace(/\\"/g, '"');
}

export function parseYoutubeId(url: string): string | null {
  try {
    const u = new URL(url);
    if (u.hostname === 'youtu.be') return u.pathname.slice(1).split('/')[0] || null;
    if (u.pathname.startsWith('/shorts/')) return u.pathname.split('/')[2] || null;
    if (u.pathname.startsWith('/embed/')) return u.pathname.split('/')[2] || null;
    return u.searchParams.get('v');
  } catch {
    return null;
  }
}

async function extractYoutube(url: string): Promise<ExtractResult | null> {
  const videoId = parseYoutubeId(url);
  if (!videoId) return null;

  const playerRes = await fetch(
    'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': UA,
        Origin: 'https://www.youtube.com',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'ANDROID',
            clientVersion: '19.09.37',
            hl: 'en',
            gl: 'US',
          },
        },
        videoId,
      }),
    },
  );

  if (!playerRes.ok) return null;
  const player = (await playerRes.json()) as {
    videoDetails?: {
      title?: string;
      author?: string;
      lengthSeconds?: string;
      thumbnail?: { thumbnails?: Array<{ url?: string }> };
    };
    streamingData?: {
      formats?: Array<Record<string, unknown>>;
      adaptiveFormats?: Array<Record<string, unknown>>;
    };
  };

  const details = player.videoDetails;
  const streams = [
    ...(player.streamingData?.formats ?? []),
    ...(player.streamingData?.adaptiveFormats ?? []),
  ];

  const headers = { 'User-Agent': UA, Referer: 'https://www.youtube.com/' };
  const formats: ResolvedFormat[] = [];
  const seen = new Set<string>();

  for (const fmt of streams) {
    const direct = fmt.url as string | undefined;
    if (!direct) continue;

    const mime = String(fmt.mimeType ?? '');
    const height = Number(fmt.height ?? 0);
    const width = Number(fmt.width ?? 0);
    const fps = Number(fmt.fps ?? 0) || null;
    const ext = mime.includes('webm') ? 'webm' : mime.includes('mp4') ? 'mp4' : 'mp4';
    const hasVideo = mime.startsWith('video/');
    const hasAudio = mime.startsWith('audio/');
    if (!hasVideo && !hasAudio) continue;

    const formatId = String(fmt.itag ?? `${height}-${ext}`);
    if (seen.has(formatId)) continue;
    seen.add(formatId);

    const size = Number(fmt.contentLength ?? fmt.fileSize ?? 0) || undefined;
    const resolution = height ? `${width || '?'}x${height}` : hasAudio ? 'audio only' : null;

    formats.push({
      format_id: formatId,
      label: formatLabel([
        resolution,
        fps ? `${fps}fps` : null,
        ext.toUpperCase(),
        size ? humanSize(size) : null,
      ]),
      ext,
      resolution,
      fps,
      filesize: size,
      is_video: hasVideo,
      is_audio: hasAudio && !hasVideo,
      is_image: false,
      direct_url: direct,
      headers,
    });
  }

  formats.sort((a, b) => {
    const rank = (f: ResolvedFormat) => (f.is_video ? 0 : 1);
    const diff = rank(a) - rank(b);
    if (diff !== 0) return diff;
    return (b.filesize ?? 0) - (a.filesize ?? 0);
  });

  if (!formats.length) return null;

  return {
    title: details?.title,
    uploader: details?.author,
    duration: details?.lengthSeconds ? Number(details.lengthSeconds) : undefined,
    thumbnail: details?.thumbnail?.thumbnails?.at(-1)?.url,
    platform: 'YouTube',
    extractor: 'youtube',
    formats,
  };
}

function parseTikTokUrl(url: string): boolean {
  return /tiktok\.com|vm\.tiktok\.com/i.test(url);
}

async function extractTikTok(url: string): Promise<ExtractResult | null> {
  if (!parseTikTokUrl(url)) return null;

  const res = await fetch(url, {
    headers: { 'User-Agent': UA, Accept: 'text/html' },
    redirect: 'follow',
  });
  const html = await res.text();

  let title = 'TikTok video';
  let author: string | undefined;
  let thumb: string | undefined;
  let playUrl: string | undefined;

  const universal = html.match(
    /<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application\/json">([\s\S]*?)<\/script>/,
  );
  if (universal?.[1]) {
    try {
      const data = JSON.parse(universal[1]) as Record<string, unknown>;
      const scope = data['__DEFAULT_SCOPE__'] as Record<string, unknown> | undefined;
      const detail = scope?.['webapp.video-detail'] as Record<string, unknown> | undefined;
      const item = detail?.itemInfo as Record<string, unknown> | undefined;
      const itemStruct = item?.itemStruct as Record<string, unknown> | undefined;
      if (itemStruct) {
        title = String(itemStruct.desc || title);
        author = (itemStruct.author as Record<string, unknown> | undefined)?.uniqueId as string | undefined;
        const video = itemStruct.video as Record<string, unknown> | undefined;
        thumb = video?.cover as string | undefined;
        playUrl =
          (video?.downloadAddr as string | undefined) ||
          (video?.playAddr as string | undefined);
      }
    } catch {
      /* fall through */
    }
  }

  if (!playUrl) {
    const addr = html.match(/"downloadAddr":"([^"]+)"/) || html.match(/"playAddr":"([^"]+)"/);
    if (addr?.[1]) playUrl = decodeEscapes(addr[1]);
  }

  if (!playUrl) return null;

  const headers = { 'User-Agent': UA, Referer: 'https://www.tiktok.com/' };
  return {
    title,
    uploader: author,
    thumbnail: thumb,
    platform: 'TikTok',
    extractor: 'tiktok',
    formats: [
      {
        format_id: 'best',
        label: 'Best available · MP4',
        ext: 'mp4',
        is_video: true,
        is_audio: false,
        is_image: false,
        direct_url: playUrl,
        headers,
      },
    ],
  };
}

function parseTweetId(url: string): string | null {
  const match = url.match(/(?:twitter\.com|x\.com)\/\w+\/status\/(\d+)/i);
  return match?.[1] ?? null;
}

async function extractTwitter(url: string): Promise<ExtractResult | null> {
  const id = parseTweetId(url);
  if (!id) return null;

  const apiUrl = `https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=en&token=1`;
  const res = await fetch(apiUrl, { headers: { 'User-Agent': UA } });
  if (!res.ok) return null;

  const data = (await res.json()) as {
    text?: string;
    user?: { name?: string };
    mediaDetails?: Array<{
      type?: string;
      video_info?: { variants?: Array<{ url?: string; content_type?: string; bitrate?: number }> };
      media_url_https?: string;
    }>;
  };

  const formats: ResolvedFormat[] = [];
  const headers = { 'User-Agent': UA, Referer: 'https://x.com/' };

  for (const media of data.mediaDetails ?? []) {
    if (media.type === 'video') {
      const variants = [...(media.video_info?.variants ?? [])]
        .filter((v) => v.content_type?.includes('mp4'))
        .sort((a, b) => (b.bitrate ?? 0) - (a.bitrate ?? 0));
      variants.forEach((variant, index) => {
        if (!variant.url) return;
        formats.push({
          format_id: `mp4-${index}`,
          label: formatLabel(['MP4', variant.bitrate ? `${Math.round(variant.bitrate / 1000)} kbps` : null]),
          ext: 'mp4',
          is_video: true,
          is_audio: false,
          is_image: false,
          direct_url: variant.url,
          headers,
        });
      });
    } else if (media.media_url_https) {
      formats.push({
        format_id: `img-${formats.length}`,
        label: 'Image',
        ext: 'jpg',
        is_video: false,
        is_audio: false,
        is_image: true,
        direct_url: media.media_url_https,
        headers,
      });
    }
  }

  if (!formats.length) return null;

  return {
    title: data.text?.slice(0, 120) || 'X media',
    uploader: data.user?.name,
    platform: 'X',
    extractor: 'twitter',
    formats,
  };
}

function parseInstagramCode(url: string): string | null {
  const match = url.match(/instagram\.com\/(?:p|reel|tv|stories\/[^/]+\/)([A-Za-z0-9_-]+)/i);
  return match?.[1] ?? null;
}

async function extractInstagram(url: string): Promise<ExtractResult | null> {
  if (!/instagram\.com|instagr\.am/i.test(url)) return null;

  const normalized = url.split('?')[0].replace(/\/$/, '') + '/';
  const res = await fetch(normalized, {
    headers: { 'User-Agent': UA, Accept: 'text/html' },
    redirect: 'follow',
  });
  const html = await res.text();

  const title =
    html.match(/<meta property="og:title" content="([^"]+)"/)?.[1] ||
    html.match(/<meta name="twitter:title" content="([^"]+)"/)?.[1] ||
    'Instagram media';
  const thumb = html.match(/<meta property="og:image" content="([^"]+)"/)?.[1];

  const video =
    html.match(/<meta property="og:video" content="([^"]+)"/)?.[1] ||
    html.match(/<meta property="og:video:secure_url" content="([^"]+)"/)?.[1];

  const headers = { 'User-Agent': UA, Referer: 'https://www.instagram.com/' };
  const formats: ResolvedFormat[] = [];

  if (video) {
    formats.push({
      format_id: 'best',
      label: 'Best available · MP4',
      ext: 'mp4',
      is_video: true,
      is_audio: false,
      is_image: false,
      direct_url: decodeEscapes(video),
      headers,
    });
  }

  if (!formats.length && thumb) {
    formats.push({
      format_id: 'image',
      label: 'Image',
      ext: 'jpg',
      is_video: false,
      is_audio: false,
      is_image: true,
      direct_url: decodeEscapes(thumb),
      headers,
    });
  }

  if (!formats.length) return null;

  return {
    title,
    thumbnail: thumb ? decodeEscapes(thumb) : undefined,
    platform: 'Instagram',
    extractor: 'instagram',
    formats,
  };
}

export async function extractMedia(url: string): Promise<ExtractResult> {
  const extractors = [extractYoutube, extractTikTok, extractTwitter, extractInstagram];
  for (const run of extractors) {
    const result = await run(url);
    if (result?.formats.length) return result;
  }
  throw new Error(
    'Unsupported URL on the edge API. Try YouTube, TikTok, Instagram, or X — or self-host the Docker API for 1,800+ sites.',
  );
}

export function pickFormat(result: ExtractResult, formatId: string): ResolvedFormat | undefined {
  if (formatId === 'best') return result.formats[0];
  return result.formats.find((f) => f.format_id === formatId);
}

export function toAnalyzeResponse(url: string, result: ExtractResult) {
  return {
    url,
    title: result.title,
    description: result.description,
    thumbnail: result.thumbnail,
    uploader: result.uploader,
    duration: result.duration,
    platform: result.platform,
    extractor: result.extractor,
    formats: result.formats.map(({ direct_url: _direct, headers: _headers, ...fmt }) => fmt),
  };
}

export function safeFilename(title: string | undefined, ext: string): string {
  const base = (title || 'download').replace(/[^\w\s\-_.]/g, '').trim().slice(0, 80) || 'download';
  return `${base}.${ext.replace(/^\./, '')}`;
}

export function mediaType(ext: string): string {
  if (['mp4', 'webm', 'mkv', 'mov'].includes(ext)) return `video/${ext}`;
  if (['mp3', 'm4a', 'opus', 'aac', 'ogg'].includes(ext)) return `audio/${ext}`;
  if (['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext)) return `image/${ext}`;
  return 'application/octet-stream';
}
