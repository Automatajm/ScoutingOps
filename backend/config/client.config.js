// =====================================================
// CLIENT CONFIGURATION - MULTI-CLIENTE SIN HARDCODING
// =====================================================
// Este módulo maneja configuración específica por cliente
// eliminando COMPLETAMENTE el hardcoding de nombres

const os = require('os');

/**
 * Obtiene el nombre del cliente desde variables de entorno
 * Prioridad: CLIENT_NAME > APP_NAME > hostname > 'pestcontrol'
 */
function getClientName() {
  return (
    process.env.CLIENT_NAME ||
    process.env.APP_NAME?.toLowerCase() ||
    os.hostname().toLowerCase() ||
    'pestcontrol'
  );
}

/**
 * Detecta si estamos en Docker analizando el entorno
 */
function isDocker() {
  try {
    // Método 1: Variable de entorno explícita
    if (process.env.DOCKER_CONTAINER === 'true') {
      return true;
    }

    // Método 2: Analizar hostname (Docker usa IDs hexadecimales)
    const hostname = os.hostname();
    if (hostname.length === 12 && /^[0-9a-f]{12}$/.test(hostname)) {
      return true;
    }

    // Método 3: Verificar archivo .dockerenv
    const fs = require('fs');
    if (fs.existsSync('/.dockerenv')) {
      return true;
    }

    // Método 4: Verificar cgroup
    if (fs.existsSync('/proc/1/cgroup')) {
      const cgroup = fs.readFileSync('/proc/1/cgroup', 'utf8');
      if (cgroup.includes('docker') || cgroup.includes('containerd')) {
        return true;
      }
    }

    return false;
  } catch (e) {
    return false;
  }
}

/**
 * Obtiene la IP principal del sistema
 */
function getMainIP() {
  const networks = os.networkInterfaces();

  // Priorizar WiFi/Wireless
  for (const name of Object.keys(networks)) {
    for (const net of networks[name]) {
      if (
        net.family === 'IPv4' &&
        !net.internal &&
        (name.toLowerCase().includes('wi-fi') ||
          name.toLowerCase().includes('wifi') ||
          name.toLowerCase().includes('wireless'))
      ) {
        return net.address;
      }
    }
  }

  // Fallback a primera interfaz no-interna
  for (const name of Object.keys(networks)) {
    for (const net of networks[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        return net.address;
      }
    }
  }

  return 'localhost';
}

/**
 * Genera URLs dinámicas basadas en cliente y entorno
 */
function generateUrls(clientName, port, flavor, inDocker) {
  const protocol = process.env.SSL_ENABLED === 'true' ? 'https' : 'http';
  const hostname = inDocker ? 'pest_control_backend' : clientName;
  const ip = getMainIP();

  // URL Manual override
  const manualApiUrl = process.env.MANUAL_API_URL;
  const manualBackendUrl = process.env.MANUAL_BACKEND_URL;

  if (manualApiUrl && manualBackendUrl) {
    return {
      apiUrl: manualApiUrl,
      baseUrl: manualBackendUrl,
      publicUrl: manualBackendUrl,
      local: `${protocol}://localhost:${port}`,
      network: `${protocol}://${ip}:${port}`,
      client: `${protocol}://${hostname}:${port}`,
    };
  }

  // URLs generadas automáticamente
  const baseUrl = inDocker
    ? `${protocol}://${hostname}:${port}`
    : `${protocol}://${hostname}:${port}`;

  return {
    apiUrl: manualApiUrl || `${baseUrl}/api`,
    baseUrl: manualBackendUrl || baseUrl,
    publicUrl: `${protocol}://${hostname}:${parseInt(port) + 80}`,
    local: `${protocol}://localhost:${port}`,
    network: `${protocol}://${ip}:${port}`,
    client: `${protocol}://${hostname}:${port}`,
  };
}

/**
 * Genera lista de orígenes CORS permitidos según cliente y entorno
 */
function generateCorsOrigins(clientName, backendPort, frontendPort, flavor) {
  const origins = [];

  if (flavor === 'development') {
    // Desarrollo: Permitir TODO
    return ['*'];
  }

  // HTTPS y HTTP del cliente
  origins.push(
    `https://${clientName}:${backendPort}`,
    `http://${clientName}:${backendPort}`,
    `https://${clientName}:${frontendPort}`,
    `http://${clientName}:${frontendPort}`
  );

  // Localhost para desarrollo
  if (flavor !== 'production') {
    origins.push(
      `https://localhost:${backendPort}`,
      `http://localhost:${backendPort}`,
      `https://localhost:${frontendPort}`,
      `http://localhost:${frontendPort}`,
      `https://127.0.0.1:${backendPort}`,
      `http://127.0.0.1:${backendPort}`,
      `https://127.0.0.1:${frontendPort}`,
      `http://127.0.0.1:${frontendPort}`
    );
  }

  // IP de red local
  const ip = getMainIP();
  if (ip !== 'localhost') {
    origins.push(
      `https://${ip}:${backendPort}`,
      `http://${ip}:${backendPort}`,
      `https://${ip}:${frontendPort}`,
      `http://${ip}:${frontendPort}`
    );
  }

  // Dominios de producción según cliente
  if (flavor === 'production') {
    origins.push(
      `https://app.${clientName}.com`,
      `https://api.${clientName}.com`,
      `https://${clientName}.com`
    );
  }

  // Staging
  if (flavor === 'staging') {
    origins.push(
      `https://staging.${clientName}.com`,
      `https://staging-api.${clientName}.com`
    );
  }

  // Variable manual de CORS
  if (process.env.ALLOWED_ORIGINS) {
    const manualOrigins = process.env.ALLOWED_ORIGINS.split(',').map((o) =>
      o.trim()
    );
    origins.push(...manualOrigins);
  }

  // Eliminar duplicados
  return [...new Set(origins)];
}

/**
 * Genera patrones regex para CORS según cliente
 */
function generateCorsPatterns(clientName, flavor) {
  const patterns = [
    // Puerto dinámico para el cliente
    new RegExp(`^https?:\\/\\/${clientName}:\\d+$`, 'i'),
  ];

  // Solo en desarrollo: localhost con cualquier puerto
  if (flavor === 'development') {
    patterns.push(/^https?:\/\/localhost:\d+$/, /^https?:\/\/127\.0\.0\.1:\d+$/);
  }

  // Subdominios del cliente en producción
  if (flavor === 'production' || flavor === 'staging') {
    patterns.push(
      new RegExp(`^https:\\/\\/[a-zA-Z0-9-]+\\.${clientName}\\.com$`)
    );
  }

  // IP de red local en desarrollo/staging
  if (flavor !== 'production') {
    patterns.push(/^https?:\/\/192\.168\.\d+\.\d+:\d+$/);
    patterns.push(/^https?:\/\/10\.\d+\.\d+\.\d+:\d+$/);
    patterns.push(/^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d+\.\d+:\d+$/);
  }

  return patterns;
}

/**
 * Configuración completa del cliente
 */
class ClientConfig {
  constructor() {
    this.clientName = getClientName();
    this.inDocker = isDocker();
    this.ip = getMainIP();
    this.hostname = os.hostname();
    this.platform = os.platform();
    this.arch = os.arch();

    console.log(`🏢 Cliente detectado: ${this.clientName}`);
    console.log(`🐳 Docker: ${this.inDocker ? 'SÍ' : 'NO'}`);
    console.log(`📡 IP detectada: ${this.ip}`);
    console.log(`🖥️  Hostname: ${this.hostname}`);
  }

  /**
   * Genera configuración completa para el cliente actual
   */
  getConfig(flavor, backendPort, frontendPort) {
    const urls = generateUrls(
      this.clientName,
      backendPort,
      flavor,
      this.inDocker
    );

    const corsOrigins = generateCorsOrigins(
      this.clientName,
      backendPort,
      frontendPort,
      flavor
    );

    const corsPatterns = generateCorsPatterns(this.clientName, flavor);

    return {
      client: {
        name: this.clientName,
        inDocker: this.inDocker,
        ip: this.ip,
        hostname: this.hostname,
        platform: this.platform,
        arch: this.arch,
      },
      urls,
      cors: {
        origins: corsOrigins,
        patterns: corsPatterns,
        enabled: process.env.CORS_ENABLED !== 'false',
        credentials: process.env.CORS_CREDENTIALS !== 'false',
      },
    };
  }

  /**
   * Genera información de sistema para logging
   */
  getSystemInfo() {
    return {
      client: this.clientName,
      hostname: this.hostname,
      platform: this.platform,
      arch: this.arch,
      nodeVersion: process.version,
      docker: this.inDocker,
      ip: this.ip,
      uptime: process.uptime,
    };
  }
}

// Singleton
const clientConfig = new ClientConfig();

module.exports = clientConfig;
