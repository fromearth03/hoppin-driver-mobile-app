// Local CORS proxy for the HOPPIN demo. The Flutter web apps call this on
// localhost; it forwards to the live API and adds permissive CORS headers so
// the browser stops blocking. Demo-only — never ship this.
const http = require('http');
const https = require('https');

const TARGET_HOST = 'api.hoppin.tech';
const PORT = 8090;

http.createServer((req, res) => {
  // CORS for every response, including the preflight.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'authorization,content-type,apikey,x-client-info');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const opts = {
    host: TARGET_HOST, port: 443, path: req.url, method: req.method,
    headers: { ...req.headers, host: TARGET_HOST },
  };
  const upstream = https.request(opts, (up) => {
    // strip any upstream CORS so ours is the only one
    const h = { ...up.headers };
    delete h['access-control-allow-origin'];
    res.writeHead(up.statusCode, { ...h,
      'access-control-allow-origin': '*' });
    up.pipe(res);
  });
  upstream.on('error', (e) => { res.writeHead(502); res.end('proxy error: ' + e.message); });
  req.pipe(upstream);
}).listen(PORT, () => console.log('CORS proxy on http://localhost:' + PORT + ' -> https://' + TARGET_HOST));
