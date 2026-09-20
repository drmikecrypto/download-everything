# Browser companions — Send to DEF

Load these unpacked extensions while the **DEF** desktop app is running (Settings → Browser companion bridge on).

| Browser | Path | Load |
|---------|------|------|
| Chrome / Edge / Brave | [`chrome/`](chrome/) | `chrome://extensions` → Developer mode → Load unpacked |
| Firefox | [`firefox/`](firefox/) | `about:debugging` → This Firefox → Load Temporary Add-on → `manifest.json` |

The extension POSTs `{ "url": "<tab>" }` to `http://127.0.0.1:19624/v1/open`. Nothing leaves your machine.
