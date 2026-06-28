import { defineConfig } from 'astro/config';

const site = process.env.SITE_URL || 'https://download-everything.pages.dev';
const base = process.env.BASE_PATH || '/';

export default defineConfig({
  site,
  base,
  output: 'static',
  build: {
    inlineStylesheets: 'auto',
  },
  vite: {
    define: {
      'import.meta.env.PUBLIC_API_URL': JSON.stringify(
        process.env.PUBLIC_API_URL || 'http://localhost:8000'
      ),
    },
  },
});
