// Loads one file in 16 MB Range slices into a single buffer and transfers it
// to the page. Runs in a throwaway worker: the page terminates it right after,
// which drops every slice's garbage at once instead of waiting for a GC.
'use strict';
self.onmessage = async (event) => {
  const url = event.data.url;
  try {
    const slice = 16 * 1024 * 1024;
    const head = await fetch(url, { headers: { Range: 'bytes=0-0' } });
    if (head.status !== 206) throw new Error(`fetch ${url}: HTTP ${head.status}, no range support`);
    const length = Number((head.headers.get('Content-Range') || '').split('/')[1]);
    const buffer = new Uint8Array(length);
    for (let offset = 0; offset < length; offset += slice) {
      const end = Math.min(offset + slice, length) - 1;
      const response = await fetch(url, { headers: { Range: `bytes=${offset}-${end}` } });
      if (response.status !== 206) throw new Error(`fetch ${url} @${offset}: HTTP ${response.status}`);
      buffer.set(new Uint8Array(await response.arrayBuffer()), offset);
    }
    self.postMessage({ buffer }, [buffer.buffer]);
  } catch (e) {
    self.postMessage({ error: String(e) });
  }
};
