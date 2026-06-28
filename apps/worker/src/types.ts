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

export interface ResolvedFormat extends MediaFormat {
  direct_url: string;
  headers: Record<string, string>;
}

export interface ExtractResult {
  title?: string;
  description?: string;
  thumbnail?: string;
  uploader?: string;
  duration?: number;
  platform: string;
  extractor: string;
  formats: ResolvedFormat[];
}

export interface Env {
  CORS_ORIGINS?: string;
  YTDLP_BACKEND?: string;
}
