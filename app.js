const API = 'http://localhost:3000/api';

// Platform detection (for UI hints only — backend handles all URLs)
const platformPatterns = {
  youtube:   /(?:youtube\.com\/(?:watch\?v=|shorts\/|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
  twitter:   /(?:twitter\.com|x\.com)\/\w+\/status\/(\d+)/,
  instagram: /instagram\.com\/(?:p|reel|tv)\/([a-zA-Z0-9_-]+)/,
  tiktok:    /tiktok\.com\/@[\w.-]+\/video\/(\d+)|vm\.tiktok\.com\/([a-zA-Z0-9]+)/,
  reddit:    /reddit\.com\/r\/[\w]+\/comments\/([a-zA-Z0-9]+)/,
  imgur:     /imgur\.com\/(?:a\/|gallery\/)?([a-zA-Z0-9]+)/,
  direct:    /\.(jpg|jpeg|png|gif|webp|mp4|webm|mp3|wav|pdf|zip)(\?.*)?$/i
};

let currentInfo = null;

function detectPlatform(url) {
  for (const [name, regex] of Object.entries(platformPatterns)) {
    if (regex.test(url)) return name;
  }
  return 'generic';
}

async function handleFetch() {
  const input = document.getElementById('urlInput');
  const url = input.value.trim();

  if (!url) { showError('Please enter a URL'); return; }

  setLoading(true);
  hideError();
  hideResults();
  currentInfo = null;

  const platform = detectPlatform(url);

  // Direct files — no backend needed
  if (platform === 'direct') {
    setLoading(false);
    const filename = url.split('/').pop().split('?')[0];
    showDirectDownload({ url, filename });
    return;
  }

  // Imgur — direct image
  if (platform === 'imgur') {
    setLoading(false);
    const match = url.match(platformPatterns.imgur);
    showImageResult({ imageUrl: `https://i.imgur.com/${match[1]}.jpg`, sourceUrl: url, title: 'Imgur Image' });
    return;
  }

  // Everything else — hit the backend
  try {
    const res = await fetch(`${API}/info?url=${encodeURIComponent(url)}`);
    const data = await res.json();

    if (!res.ok) throw new Error(data.error || 'Failed to fetch info');

    currentInfo = { ...data, url };
    renderResult(data, url);
  } catch (err) {
    showError(`Could not fetch content: ${err.message}`);
  } finally {
    setLoading(false);
  }
}

function renderResult(data, url) {
  const resultCard = document.getElementById('resultCard');
  const mediaPreview = document.getElementById('mediaPreview');
  const metaInfo = document.getElementById('metaInfo');
  const downloadOptions = document.getElementById('downloadOptions');

  mediaPreview.innerHTML = '';
  metaInfo.innerHTML = '';
  downloadOptions.innerHTML = '';

  // Thumbnail preview
  if (data.thumbnail) {
    mediaPreview.innerHTML = `<img src="${escapeHtml(data.thumbnail)}" alt="Thumbnail" />`;
  }

  // Meta
  const duration = data.duration ? formatDuration(data.duration) : '';
  metaInfo.innerHTML = `
    <p class="meta-title">${escapeHtml(data.title || 'Untitled')}</p>
    <p class="meta-source">
      ${escapeHtml(data.platform || '')}
      ${data.uploader ? ` · ${escapeHtml(data.uploader)}` : ''}
      ${duration ? ` · ${duration}` : ''}
    </p>
  `;

  // Format buttons
  if (data.formats && data.formats.length) {
    const videoFormats = data.formats.filter(f => f.hasVideo && f.hasAudio);
    const audioFormats = data.formats.filter(f => !f.hasVideo && f.hasAudio);
    const videoOnly    = data.formats.filter(f => f.hasVideo && !f.hasAudio);
    const imageFormats = data.formats.filter(f => !f.hasVideo && !f.hasAudio);

    let html = '';

    if (videoFormats.length) {
      html += `<p class="format-label">Video + Audio</p>`;
      html += videoFormats.map(f => formatBtn(f, url)).join('');
    }
    if (audioFormats.length) {
      html += `<p class="format-label">Audio only</p>`;
      html += audioFormats.slice(0, 3).map(f => formatBtn(f, url)).join('');
    }
    if (videoOnly.length) {
      html += `<p class="format-label">Video only</p>`;
      html += videoOnly.slice(0, 3).map(f => formatBtn(f, url)).join('');
    }
    if (imageFormats.length) {
      html += `<p class="format-label">Image</p>`;
      html += imageFormats.map(f => formatBtn(f, url)).join('');
    }

    downloadOptions.innerHTML = html;
  } else {
    // Fallback: best quality
    const dlUrl = `${API}/download?url=${encodeURIComponent(url)}&title=${encodeURIComponent(data.title || 'download')}`;
    downloadOptions.innerHTML = `<a href="${dlUrl}" class="download-btn primary" download>⬇ Download Best Quality</a>`;
  }

  resultCard.classList.remove('hidden');
  document.getElementById('directDownloadCard').classList.add('hidden');
}

function formatBtn(f, url) {
  const size = f.filesize ? ` (${formatBytes(f.filesize)})` : '';
  const label = f.hasVideo ? `${f.quality} ${f.ext}${size}` : `${f.ext.toUpperCase()} ${f.hasAudio ? 'audio' : 'image'}${size}`;
  const icon = f.hasVideo ? '⬇' : f.hasAudio ? '🎵' : '🖼';
  const cls = f.hasVideo && f.hasAudio ? 'primary' : 'secondary';

  // Direct URL formats (Unsplash, OG images) — use direct_url param
  if (f._directUrl) {
    const dlUrl = `${API}/download?direct_url=${encodeURIComponent(f._directUrl)}&title=${encodeURIComponent(currentInfo?.title || 'download')}`;
    return `<a href="${dlUrl}" class="download-btn ${cls}" download>${icon} ${escapeHtml(label)}</a>`;
  }

  const dlUrl = `${API}/download?url=${encodeURIComponent(url)}&format_id=${f.format_id}&title=${encodeURIComponent(currentInfo?.title || 'download')}`;
  return `<a href="${dlUrl}" class="download-btn ${cls}" download>${icon} ${escapeHtml(label)}</a>`;
}

function showImageResult({ imageUrl, sourceUrl, title }) {
  const resultCard = document.getElementById('resultCard');
  document.getElementById('mediaPreview').innerHTML = `<img src="${escapeHtml(imageUrl)}" alt="Preview" />`;
  document.getElementById('metaInfo').innerHTML = `<p class="meta-title">${escapeHtml(title)}</p>`;
  document.getElementById('downloadOptions').innerHTML = `
    <button onclick="downloadBlob('${escapeHtml(imageUrl)}', 'image.jpg')" class="download-btn primary">⬇ Download Image</button>
    <a href="${escapeHtml(sourceUrl)}" target="_blank" class="download-btn secondary">Open Original</a>
  `;
  resultCard.classList.remove('hidden');
  document.getElementById('directDownloadCard').classList.add('hidden');
}

function showDirectDownload({ url, filename }) {
  document.getElementById('directFileName').textContent = filename;
  document.getElementById('directFileType').textContent = filename.split('.').pop().toUpperCase() + ' File';
  document.getElementById('directDownloadBtn').onclick = () => {
    const a = document.createElement('a');
    a.href = url; a.download = filename; a.target = '_blank';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
  };
  document.getElementById('directDownloadCard').classList.remove('hidden');
  document.getElementById('resultCard').classList.add('hidden');
}

async function downloadBlob(url, filename) {
  try {
    const res = await fetch(url);
    const blob = await res.blob();
    const blobUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = blobUrl; a.download = filename;
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(blobUrl), 100);
  } catch {
    showError('Download failed. Try opening the original link.');
  }
}

// UI helpers
function setLoading(loading) {
  const btn = document.getElementById('fetchBtn');
  document.getElementById('btnText').classList.toggle('hidden', loading);
  document.getElementById('btnSpinner').classList.toggle('hidden', !loading);
  btn.disabled = loading;
}

function showError(message) {
  const box = document.getElementById('errorBox');
  box.textContent = message;
  box.style.color = '';
  box.style.background = '';
  box.style.borderColor = '';
  box.classList.remove('hidden');
}

function showStatus(message) {
  const box = document.getElementById('errorBox');
  box.style.color = 'var(--muted)';
  box.style.background = 'rgba(136,136,153,0.08)';
  box.style.borderColor = 'rgba(136,136,153,0.2)';
  box.textContent = message;
  box.classList.remove('hidden');
}

function hideError() {
  const box = document.getElementById('errorBox');
  box.classList.add('hidden');
  box.style.color = '';
  box.style.background = '';
  box.style.borderColor = '';
}

function hideResults() {
  document.getElementById('resultCard').classList.add('hidden');
  document.getElementById('directDownloadCard').classList.add('hidden');
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = String(text);
  return div.innerHTML;
}

function formatDuration(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`
    : `${m}:${String(s).padStart(2,'0')}`;
}

function formatBytes(bytes) {
  if (!bytes) return '';
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}

// Enter key
document.getElementById('urlInput').addEventListener('keypress', e => {
  if (e.key === 'Enter') handleFetch();
});
