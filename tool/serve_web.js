const fs = require('fs');
const http = require('http');
const path = require('path');

const root = path.resolve(__dirname, '..', 'build', 'web');
const port = Number(process.env.PORT || 8080);
const host = process.env.HOST || '127.0.0.1';
const types = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

http
  .createServer((request, response) => {
    const requestPath = decodeURIComponent((request.url || '/').split('?')[0]);
    let filePath = path.join(root, requestPath === '/' ? 'index.html' : requestPath);

    if (!filePath.startsWith(root) || !fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
      filePath = path.join(root, 'index.html');
    }

    response.writeHead(200, {
      'Content-Type': types[path.extname(filePath)] || 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(response);
  })
  .listen(port, host, () => {
    console.log(`Pitch Duel web build running at http://${host}:${port}`);
  });
