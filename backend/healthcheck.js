// backend/healthcheck.js
const https = require('https');
const http = require('http');
const fs = require('fs');

const port = process.env.PORT || 8000;
const sslEnabled = process.env.SSL_ENABLED === 'true';

const options = {
  hostname: 'localhost',
  port: port,
  path: '/api/health',
  method: 'GET',
  timeout: 5000,
  rejectUnauthorized: false // Para certificados autofirmados
};

// Determinar si usar HTTPS o HTTP
const useHttps = sslEnabled && fs.existsSync('/app/certs/cert.pem') && fs.existsSync('/app/certs/key.pem');
const protocol = useHttps ? https : http;

console.log(`Health check using ${useHttps ? 'HTTPS' : 'HTTP'} on port ${port}`);

const req = protocol.request(options, (res) => {
  console.log(`Health check response: ${res.statusCode}`);
  if (res.statusCode === 200) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

req.on('error', (err) => {
  console.error('Health check failed:', err.message);
  process.exit(1);
});

req.on('timeout', () => {
  console.error('Health check timeout');
  req.abort();
  process.exit(1);
});

req.end();