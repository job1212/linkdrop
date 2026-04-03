const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');
const https = require('https');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Run yt-dlp and return parsed JSON output
function ytDlp(args) {
  return new Promise((resolve, reject) => {
    // Add cookies file if it exists or use env var
    const cookiesArgs = [];
    if (process.env.YOUTUBE_COOKIES) {
      // Write cookies from env var to a temp file
      const fs = require('fs');
      const cookiePath = '/tmp/yt_cookies.txt';
      fs.writeFileSync(cookiePath, process.env.YOUTUBE_COOKIES);
      cookiesArgs.push('--cookies', cookiePath);
    }

    const proc = spawn('yt-dlp', [...cookiesArgs, ...args]);
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', d => stdout += d.toString());
    proc.stderr.on('data', d => stderr += d.toString());

    proc.on('close', code => {
      if (code === 0) resolve(stdout.trim());
      else reject(new Error(stderr.trim() || 'yt-dlp failed'));
    });
  });
}

// Fetch a URL and return body as string
function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, res => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => resolve({ body: data, headers: res.headers, status: res.statusCode }));
    }).on('error', reject);
  });
}

// Extract Open Graph / meta image from any webpage
function extractMetaImage(html) {
  const og = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
    || html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
  const title = html.match(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i)
    || html.match(/<title[^>]*>([^<]+)<\/title>/i);
  const desc = html.match(/<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i);
  return {
    image: og ? og[1] : null,
    title: title ? title[1].trim() : 'Image',
    description: desc ? desc[1] : null
  };
}

// Handle Unsplash URLs — extract photo ID and build direct CDN download URL
async function handleUnsplash(url) {
  const match = url.match(/unsplash\.com\/photos\/(?:[^/]+-)?([a-zA-Z0-9_-]+)(?:\?|$)/);
  if (!match) throw new Error('Could not parse Unsplash photo ID');
  const photoId = match[1];

  // Use the Unsplash CDN directly — format: https://images.unsplash.com/photo-<id>
  // We scrape the OG image tag which gives us the full-res CDN URL
  let title = 'Unsplash Photo';
  let thumbnail = null;
  let imageUrl = null;

  try {
    const { body } = await fetchUrl(url);
    const meta = extractMetaImage(body);
    if (meta.title) title = meta.title;
    if (meta.image) {
      // OG image is a sized preview — swap to full resolution by removing size params
      imageUrl = meta.image.split('?')[0] + '?q=80&fm=jpg&fit=max';
      thumbnail = meta.image;
    }
  } catch (_) {}

  // Fallback to known CDN pattern
  if (!imageUrl) {
    imageUrl = `https://images.unsplash.com/photo-${photoId}?q=80&fm=jpg&fit=max`;
    thumbnail = imageUrl;
  }

  return {
    title,
    thumbnail,
    uploader: null,
    platform: 'Unsplash',
    duration: null,
    formats: [
      { format_id: 'original', ext: 'jpg', quality: 'Full Resolution', hasVideo: false, hasAudio: false, filesize: null, _directUrl: imageUrl }
    ]
  };
}

// Generic image/media page handler using OG tags
async function handleGenericPage(url) {
  const { body, headers } = await fetchUrl(url);
  const contentType = headers['content-type'] || '';

  // It's a direct media file
  if (contentType.startsWith('image/') || contentType.startsWith('video/') || contentType.startsWith('audio/')) {
    const ext = contentType.split('/')[1].split(';')[0];
    const filename = url.split('/').pop().split('?')[0] || `download.${ext}`;
    return {
      title: filename,
      thumbnail: contentType.startsWith('image/') ? url : null,
      platform: 'Direct',
      duration: null,
      uploader: null,
      formats: [
        { format_id: 'direct', ext, quality: ext.toUpperCase(), hasVideo: contentType.startsWith('video/'), hasAudio: contentType.startsWith('audio/'), filesize: null, _directUrl: url }
      ]
    };
  }

  // HTML page — extract OG image
  const meta = extractMetaImage(body);
  if (!meta.image) throw new Error('No downloadable media found on this page');

  return {
    title: meta.title,
    thumbnail: meta.image,
    platform: 'Web',
    duration: null,
    uploader: null,
    formats: [
      { format_id: 'og-image', ext: 'jpg', quality: 'Original', hasVideo: false, hasAudio: false, filesize: null, _directUrl: meta.image }
    ]
  };
}

// GET /api/info?url=... — returns available formats
app.get('/api/info', async (req, res) => {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'url is required' });

  // Unsplash — handle directly, yt-dlp gets 401
  if (/unsplash\.com\/photos\//.test(url)) {
    try {
      return res.json(await handleUnsplash(url));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  try {
    const raw = await ytDlp(['--dump-json', '--no-playlist', '--no-warnings', url]);

    const info = JSON.parse(raw);

    // Pick useful formats: deduplicate by quality label
    const seen = new Set();
    const formats = (info.formats || [])
      .filter(f => f.ext && (f.vcodec !== 'none' || f.acodec !== 'none'))
      .map(f => ({
        format_id: f.format_id,
        ext: f.ext,
        quality: f.format_note || f.height ? `${f.height}p` : f.format_id,
        filesize: f.filesize || f.filesize_approx || null,
        hasVideo: f.vcodec !== 'none',
        hasAudio: f.acodec !== 'none',
        fps: f.fps || null
      }))
      .filter(f => {
        const key = `${f.quality}-${f.ext}-${f.hasVideo}-${f.hasAudio}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .sort((a, b) => {
        // Sort: video+audio first, then by quality desc
        if (a.hasVideo && a.hasAudio && !(b.hasVideo && b.hasAudio)) return -1;
        if (b.hasVideo && b.hasAudio && !(a.hasVideo && a.hasAudio)) return 1;
        return (parseInt(b.quality) || 0) - (parseInt(a.quality) || 0);
      })
      .slice(0, 12);

    res.json({
      title: info.title,
      thumbnail: info.thumbnail,
      duration: info.duration,
      uploader: info.uploader,
      platform: info.extractor_key,
      formats
    });
  } catch (err) {
    // yt-dlp failed — try generic OG image extraction
    try {
      return res.json(await handleGenericPage(url));
    } catch (_) {
      return res.status(500).json({ error: err.message });
    }
  }
});

// GET /api/download?url=...&format_id=...&direct_url=... — streams the file to browser
app.get('/api/download', async (req, res) => {
  const { url, format_id, title, direct_url } = req.query;
  if (!url && !direct_url) return res.status(400).json({ error: 'url is required' });

  // Direct URL proxy (Unsplash, OG images, etc.)
  if (direct_url) {
    const ext = direct_url.split('?')[0].split('.').pop().toLowerCase() || 'jpg';
    const mimeMap = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp', mp4: 'video/mp4', mp3: 'audio/mpeg' };
    const mime = mimeMap[ext] || 'application/octet-stream';
    const filename = `${(title || 'download').replace(/[^\w\s-]/g, '').trim()}.${ext}`;

    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', mime);

    const client = direct_url.startsWith('https') ? https : http;
    const request = client.get(direct_url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, stream => {
      if (stream.statusCode === 301 || stream.statusCode === 302) {
        // Follow redirect
        const redirectUrl = stream.headers.location;
        const rc = redirectUrl.startsWith('https') ? https : http;
        rc.get(redirectUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } }, rs => rs.pipe(res))
          .on('error', err => res.status(500).json({ error: err.message }));
      } else {
        stream.pipe(res);
      }
    });
    request.on('error', err => res.status(500).json({ error: err.message }));
    return;
  }

  try {
    // Get format info first to determine extension
    const infoRaw = await ytDlp([
      '--dump-json', '--no-playlist', '--no-warnings',
      ...(format_id ? ['-f', format_id] : ['-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best']),
      url
    ]);
    const info = JSON.parse(infoRaw);
    const ext = format_id
      ? (info.formats?.find(f => f.format_id === format_id)?.ext || 'mp4')
      : 'mp4';

    const filename = `${(title || info.title || 'download').replace(/[^\w\s-]/g, '').trim()}.${ext}`;

    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', 'application/octet-stream');

    const args = [
      '--no-playlist',
      '--no-warnings',
      '-f', format_id || 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
      '-o', '-',  // output to stdout
      url
    ];

    const proc = spawn('yt-dlp', args);
    proc.stdout.pipe(res);
    proc.stderr.on('data', d => console.error('[yt-dlp]', d.toString()));
    proc.on('close', code => {
      if (code !== 0 && !res.headersSent) {
        res.status(500).json({ error: 'Download failed' });
      }
    });

    req.on('close', () => proc.kill());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`LinkDrop server running at http://localhost:${PORT}`);
});
