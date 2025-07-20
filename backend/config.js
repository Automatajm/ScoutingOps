// ===== config.js ACTUALIZADO =====
require('dotenv').config();
const os = require('os');

// ===== FUNCIÓN PARA DETECTAR IP PRINCIPAL =====
function getMainIP() {
  const networks = os.networkInterfaces();
  
  for (const name of Object.keys(networks)) {
    for (const net of networks[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        if (name.toLowerCase().includes('wi-fi') || 
            name.toLowerCase().includes('wifi') || 
            name.toLowerCase().includes('wireless')) {
          console.log(`📡 IP WiFi detectada: ${net.address} (${name})`);
          return net.address;
        }
      }
    }
  }
  
  for (const name of Object.keys(networks)) {
    for (const net of networks[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(`📡 IP detectada: ${net.address} (${name})`);
        return net.address;
      }
    }
  }
  
  return 'localhost';
}

// ===== CONFIGURACIÓN PRINCIPAL =====
const config = {
  // Básicos (requeridos)
  environment: process.env.ENVIRONMENT || 'development',
  version: process.env.VERSION || '1.0.0',
  port: parseInt(process.env.PORT) || 8000,
  host: process.env.HOST || '0.0.0.0',
  
  // URLs
  apiUrl: process.env.API_URL || `https://${getMainIP()}:8000/api`,
  baseUrl: process.env.BASE_URL || `https://${getMainIP()}:8000`,
  publicUrl: process.env.PUBLIC_URL || `https://${getMainIP()}:8080`,
  
  // Base de datos
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || 'Pest_Control',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '0824',
    
    // Pool de conexiones (NUEVO)
    pool: {
      max: parseInt(process.env.DB_POOL_MAX) || 10,
      min: parseInt(process.env.DB_POOL_MIN) || 2,
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 10000,
      connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 5000,
      statementTimeout: parseInt(process.env.DB_STATEMENT_TIMEOUT) || 15000,
      queryTimeout: parseInt(process.env.DB_QUERY_TIMEOUT) || 15000
    }
  },
  
  // Logging (NUEVO)
  logging: {
    queries: process.env.LOG_QUERIES === 'true',
    errors: process.env.LOG_ERRORS !== 'false', // default true
    requests: process.env.LOG_REQUESTS === 'true',
    pretty: process.env.PRETTY_LOGS === 'true',
    level: process.env.LOG_LEVEL || 'info'
  },
  
  // Seguridad (NUEVO)
  security: {
    saltRounds: parseInt(process.env.SALT_ROUNDS) || 10,
    jwtSecret: process.env.JWT_SECRET || 'fallback-secret-key',
    tokenExpiration: process.env.TOKEN_EXPIRATION || '24h',
    helmetEnabled: process.env.HELMET_ENABLED === 'true',
    sessionSecure: process.env.SESSION_SECURE === 'true',
    cookieSecure: process.env.COOKIE_SECURE === 'true'
  },
  
  // SSL/TLS (NUEVO)
  ssl: {
    enabled: process.env.SSL_ENABLED === 'true',
    certPath: process.env.SSL_CERT_PATH || 'C:/Users/owner/Desktop/pestcontrol/backend/certs/cert.pem',
    keyPath: process.env.SSL_KEY_PATH || 'C:/Users/owner/Desktop/pestcontrol/backend/certs/key.pem'
  },
  
  // Timeouts (NUEVO)
  timeouts: {
    server: parseInt(process.env.SERVER_TIMEOUT) || 30000,
    request: parseInt(process.env.REQUEST_TIMEOUT) || 15000
  },
  
  // CORS (NUEVO)
  cors: {
    origins: process.env.CORS_ORIGIN ? 
      process.env.CORS_ORIGIN.split(',').map(origin => origin.trim()) : 
      ['http://localhost:8080', 'https://localhost:8080'],
    credentials: process.env.CORS_CREDENTIALS === 'true'
  },
  
  // Rate Limiting (NUEVO)
  rateLimit: {
    windowMs: (parseInt(process.env.RATE_LIMIT_WINDOW) || 15) * 60 * 1000, // minutos a ms
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100
  },
  
  // Monitoreo (NUEVO)
  monitoring: {
    enabled: process.env.MONITORING_ENABLED === 'true',
    metricsEndpoint: process.env.METRICS_ENDPOINT || '/metrics',
    healthCheckInterval: parseInt(process.env.HEALTH_CHECK_INTERVAL) || 30000,
    apmEnabled: process.env.APM_ENABLED === 'true'
  },
  
  // Performance (NUEVO)
  performance: {
    gzipEnabled: process.env.GZIP_ENABLED === 'true',
    etagEnabled: process.env.ETAG_ENABLED === 'true',
    cacheControlMaxAge: parseInt(process.env.CACHE_CONTROL_MAX_AGE) || 0
  },
  
  // CDN y Assets (NUEVO)
  assets: {
    cdnUrl: process.env.CDN_URL || null,
    staticAssetsUrl: process.env.STATIC_ASSETS_URL || null
  },
  
  // Flutter Web (NUEVO)
  flutter: {
    useSkia: process.env.FLUTTER_WEB_USE_SKIA === 'true',
    autoDetect: process.env.FLUTTER_WEB_AUTO_DETECT !== 'false',
    renderer: process.env.FLUTTER_WEB_RENDERER || 'html',
    cacheAssets: process.env.FLUTTER_WEB_CACHE_ASSETS === 'true'
  },
  
  // Servicios Externos (NUEVO)
  services: {
    email: process.env.EMAIL_SERVICE_ENABLED === 'true',
    sms: process.env.SMS_SERVICE_ENABLED === 'true',
    pushNotifications: process.env.PUSH_NOTIFICATIONS_ENABLED === 'true'
  },
  
  // Backup (NUEVO)
  backup: {
    enabled: process.env.DB_BACKUP_ENABLED === 'true',
    schedule: process.env.DB_BACKUP_SCHEDULE || '0 2 * * *',
    retentionDays: parseInt(process.env.DB_BACKUP_RETENTION_DAYS) || 7
  },
  
  // URLs calculadas
  urls: {
    api: process.env.API_URL || `https://${getMainIP()}:8000/api`,
    base: process.env.BASE_URL || `https://${getMainIP()}:8000`,
    public: process.env.PUBLIC_URL || `https://${getMainIP()}:8080`,
    local: `https://localhost:${process.env.PORT || 8000}`,
    network: `https://${getMainIP()}:${process.env.PORT || 8000}`
  },
  
  // Info del sistema
  system: {
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    nodeVersion: process.version,
    uptime: process.uptime
  }
};

// ===== VALIDACIONES SEGÚN ENTORNO =====
if (config.environment === 'production') {
  // Validaciones críticas para producción
  if (config.security.jwtSecret === 'fallback-secret-key') {
    console.warn('⚠️ WARNING: Usando JWT secret por defecto en producción');
  }
  
  if (!config.ssl.enabled) {
    console.warn('⚠️ WARNING: SSL deshabilitado en producción');
  }
  
  if (config.database.password === '0824') {
    console.warn('⚠️ WARNING: Usando contraseña de desarrollo en producción');
  }
}

// ===== LOGGING DE CONFIGURACIÓN =====
console.log(`🔧 Configuración cargada:`);
console.log(`   Entorno: ${config.environment}`);
console.log(`   Puerto: ${config.port}`);
console.log(`   Base URL: ${config.baseUrl}`);
console.log(`   SSL: ${config.ssl.enabled ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   Pool DB: ${config.database.pool.min}-${config.database.pool.max} conexiones`);

if (config.environment === 'development') {
  console.log(`   DB Host: ${config.database.host}`);
  console.log(`   API URL: ${config.apiUrl}`);
  console.log(`   Public URL: ${config.publicUrl}`);
}

// ✅ LOGGING SEGURO PARA PRODUCCIÓN - SIN DATOS SENSIBLES
if (config.environment === 'production') {
  console.log(`💾 Pool de DB configurado:`);
  console.log(`   Conexiones: ${config.database.pool.min}-${config.database.pool.max}`);
  console.log(`   Timeout: ${config.database.pool.connectionTimeoutMillis}ms`);
  console.log(`   Host: ${config.database.host}:${config.database.port}`);
  console.log(`   SSL: ${config.ssl.enabled ? 'Habilitado' : 'Deshabilitado'}`);
  console.log(`   Database: ${config.database.database}`);
  console.log(`   User: ${config.database.user}`);
  console.log(`   Logging: Queries=${config.logging.queries}, Errors=${config.logging.errors}`);
  
  // 🔒 LOGGING SEGURO: Status en lugar de paths sensibles
  console.log(`🔒 [PROD-DEBUG] Error logging: ${config.logging.errors ? 'ENABLED' : 'DISABLED'}`);
  console.log(`🔒 [PROD-DEBUG] SSL status: ${config.ssl.enabled ? 'CONFIGURED' : 'DISABLED'}`);
  console.log(`🔒 [PROD-DEBUG] SSL certificates: ${(config.ssl.certPath && config.ssl.keyPath) ? 'PRESENT' : 'MISSING'}`);
  console.log(`🔒 [PROD-DEBUG] Security config: JWT=${config.security.jwtSecret !== 'fallback-secret-key' ? 'CUSTOM' : 'DEFAULT'}`);
}

module.exports = config;