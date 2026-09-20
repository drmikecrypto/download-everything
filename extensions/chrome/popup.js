const BRIDGE = 'http://127.0.0.1:19624';

async function send() {
  const status = document.getElementById('status');
  status.textContent = 'Sending…';
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
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
