const BRIDGE = 'http://127.0.0.1:19624';
const tabsApi = typeof browser !== 'undefined' ? browser.tabs : chrome.tabs;

async function send() {
  const status = document.getElementById('status');
  status.textContent = 'Sending…';
  try {
    const list = await tabsApi.query({ active: true, currentWindow: true });
    const tab = list[0];
    if (!tab?.url || !tab.url.startsWith('http')) {
      status.textContent = 'No http(s) tab URL.';
      return;
    }
    const health = await fetch(`${BRIDGE}/health`).then((r) => r.json()).catch(() => null);
    if (!health?.ok) {
      status.textContent = 'DEF is not running (bridge offline).';
      return;
    }
    const res = await fetch(`${BRIDGE}/v1/open`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: tab.url }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    status.textContent = 'Sent — check DEF.';
  } catch (e) {
    status.textContent = `Failed: ${e}`;
  }
}

document.getElementById('send').addEventListener('click', send);
