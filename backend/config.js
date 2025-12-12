// ===== config.js CON PRIORIDAD CORREGIDA A .env Y RATE LIMITING INDUSTRIAL =====
const path = require('path');
const fs = require('fs');
const os = require('os');

// ===== FUNCIÓN PARA CARGAR Y DETECTAR FLAVOR CORRECTAMENTE =====
function loadEnvironmentAndDetectFlavor() {
  // 🎯 PASO 1: CARGAR .env ACTUAL PRIMERO (más alta prioridad)
  const envPath = path.resolve(__dirname, '.env');
  let envFlavor = null;
  
  if (fs.existsSync(envPath)) {
    // Cargar .env con override para sobrescribir variables del sistema
    require('dotenv').config({ path: envPath, override: true });
    
    // Leer FLAVOR del archivo .env cargado
    envFlavor = process.env.FLAVOR;
    if (envFlavor && ['development', 'staging', 'production'].includes(envFlavor.toLowerCase())) {
      console.log(`🥇 PRIORIDAD 1: FLAVOR desde .env actual: ${envFlavor}`);
      return envFlavor.toLowerCase();
    }
  }
  
  // 🎯 PASO 2: Variables de entorno del sistema (fallback)
  const sysFlavor = process.env.NODE_ENV || process.env.ENVIRONMENT;
  if (sysFlavor && ['development', 'staging', 'production'].includes(sysFlavor.toLowerCase())) {
    console.log(`🥈 PRIORIDAD 2: FLAVOR desde variables sistema: ${sysFlavor}`);
    return sysFlavor.toLowerCase();
  }
  
  // 🎯 PASO 3: Argumentos de línea de comandos
  const argFlavor = process.argv.find(arg => arg.startsWith('--flavor='))?.split('=')[1] ||
                    process.argv.find(arg => arg.startsWith('--env='))?.split('=')[1];
  if (argFlavor && ['development', 'staging', 'production'].includes(argFlavor.toLowerCase())) {
    console.log(`🥉 PRIORIDAD 3: FLAVOR desde argumentos CLI: ${argFlavor}`);
    return argFlavor.toLowerCase();
  }
  
  // 🎯 PASO 4: Auto-detección desde frontend (último recurso)
  const frontendFlavor = autoDetectFlavorFromFrontend();
  if (frontendFlavor && ['development', 'staging', 'production'].includes(frontendFlavor)) {
    console.log(`🔄 PRIORIDAD 4: FLAVOR desde frontend build: ${frontendFlavor}`);
    return frontendFlavor;
  }
  
  // 🎯 DEFAULT: development
  console.log(`🎯 DEFAULT: FLAVOR por defecto: development`);
  return 'development';
}

// ===== FUNCIÓN PARA AUTO-DETECTAR FLAVOR DEL FRONTEND (FALLBACK) =====
function autoDetectFlavorFromFrontend() {
  try {
    // Buscar archivos de build del frontend que indiquen el flavor
    const frontendBuildPaths = [
      '../frontend/build/web/assets/.env',
      '../frontend/build/web/main.dart.js',
      '../frontend/.flutter-plugins',
      '../frontend/build/web/flutter_service_worker.js'
    ];
    
    for (const buildPath of frontendBuildPaths) {
      const fullPath = path.resolve(__dirname, buildPath);
      if (fs.existsSync(fullPath)) {
        const content = fs.readFileSync(fullPath, 'utf8');
        
        // Buscar indicadores de flavor en el contenido
        if (content.includes('production') || content.includes('PRODUCTION')) {
          return 'production';
        }
        if (content.includes('staging') || content.includes('STAGING')) {
          return 'staging';
        }
      }
    }
  } catch (error) {
    // Silencioso, continuar con otras detecciones
  }
  
  return null;
}

// ===== CARGAR CONFIGURACIÓN DE ENTORNO CON LÓGICA CORREGIDA =====
const currentFlavor = loadEnvironmentAndDetectFlavor();

// ===== LOGGING MEJORADO DE CONFIGURACIÓN =====
console.log(`🎯 Configuración de entorno cargada:`);
console.log(`   Flavor detectado: ${currentFlavor}`);
console.log(`   Archivo .env: ${fs.existsSync(path.resolve(__dirname, '.env')) ? 'encontrado' : 'no encontrado'}`);
console.log(`   Variables de entorno: NODE_ENV=${process.env.NODE_ENV || 'no definido'}, ENVIRONMENT=${process.env.ENVIRONMENT || 'no definido'}`);

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

// ===== CONFIGURACIÓN PRINCIPAL BASADA EN FLAVOR =====
const config = {
  // Básicos (usando FLAVOR como fuente principal)
  environment: process.env.FLAVOR || currentFlavor,
  flavor: process.env.FLAVOR || currentFlavor,
  version: process.env.VERSION || '1.0.0',
  port: parseInt(process.env.PORT) || 8000,
  host: process.env.HOST || '0.0.0.0',
  
  // URLs basadas en FLAVOR
  apiUrl: process.env.API_BASE_URL || 
          (currentFlavor === 'production' ? process.env.PRODUCTION_API_URL : 
           currentFlavor === 'staging' ? process.env.STAGING_API_URL :
           process.env.LOCAL_API_URL) ||
          `https://${getMainIP()}:${process.env.PORT || 8000}/api`,
  
  baseUrl: process.env.BACKEND_URL || `https://${getMainIP()}:${process.env.PORT || 8000}`,
  publicUrl: process.env.PUBLIC_URL || `https://${getMainIP()}:${parseInt(process.env.PORT || 8000) + 80}`,
  
  // Base de datos
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || 'Pest_Control',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '0824',
    
    pool: {
      max: parseInt(process.env.DB_POOL_MAX) || (currentFlavor === 'production' ? 20 : currentFlavor === 'staging' ? 15 : 10),
      min: parseInt(process.env.DB_POOL_MIN) || (currentFlavor === 'production' ? 5 : currentFlavor === 'staging' ? 3 : 2),
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 10000,
      connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 5000,
      statementTimeout: parseInt(process.env.DB_STATEMENT_TIMEOUT) || 15000,
      queryTimeout: parseInt(process.env.DB_QUERY_TIMEOUT) || 15000
    }
  },
  
  // Logging basado en FLAVOR
  logging: {
    queries: process.env.LOG_API_CALLS === 'true',
    errors: process.env.LOG_ERRORS !== 'false',
    requests: process.env.LOG_API_CALLS === 'true',
    pretty: currentFlavor === 'development',
    level: process.env.LOG_LEVEL || (currentFlavor === 'production' ? 'error' : currentFlavor === 'staging' ? 'info' : 'debug')
  },
  
  // Seguridad basada en FLAVOR
  security: {
    saltRounds: parseInt(process.env.SALT_ROUNDS) || (currentFlavor === 'production' ? 12 : currentFlavor === 'staging' ? 11 : 10),
    jwtSecret: process.env.JWT_SECRET || process.env.JWT_STORAGE_KEY || 'fallback-secret-key',
    tokenExpiration: process.env.TOKEN_EXPIRATION || (currentFlavor === 'production' ? '1h' : currentFlavor === 'staging' ? '4h' : '24h'),
    helmetEnabled: process.env.HELMET_ENABLED === 'true' || currentFlavor === 'production',
    sessionSecure: process.env.SESSION_SECURE === 'true' || currentFlavor === 'production',
    cookieSecure: process.env.COOKIE_SECURE === 'true' || currentFlavor === 'production'
  },
  
  // SSL basado en FLAVOR
  ssl: {
    enabled: process.env.SSL_ENABLED === 'true' || process.env.VERIFY_SSL === 'true' || currentFlavor === 'production',
    certPath: process.env.SSL_CERT_PATH || path.join(__dirname, '..', 'cert.pem'),
    keyPath: process.env.SSL_KEY_PATH || path.join(__dirname, '..', 'key.pem'),
    verifySSL: process.env.VERIFY_SSL === 'true',
    allowSelfSigned: process.env.ALLOW_SELF_SIGNED_CERTS === 'true'
  },
  
  // ✅ Rate Limiting basado en FLAVOR - VALORES AMPLIADOS PARA USO INDUSTRIAL
  rateLimit: {
    windowMs: (parseInt(process.env.RATE_LIMIT_WINDOW) || 15) * 60 * 1000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 
                 (currentFlavor === 'production' ? 1000 : // ✅ AMPLIADO DE 100 A 1000
                  currentFlavor === 'staging' ? 800 :     // ✅ AMPLIADO DE 150 A 800
                  500),                                   // ✅ AMPLIADO DE 200 A 500
    authMaxRequests: parseInt(process.env.AUTH_RATE_LIMIT_MAX) ||
                     (currentFlavor === 'production' ? 25 : // ✅ AMPLIADO DE 5 A 25
                      currentFlavor === 'staging' ? 35 :    // ✅ AMPLIADO DE 10 A 35
                      50)                                   // ✅ AMPLIADO DE 20 A 50
  },
  
  // ✅ CORS basado en FLAVOR - SOLO CAMBIO PARA DRPESTCONTROL
  cors: {
    origins: (() => {
      if (process.env.ALLOWED_ORIGINS) {
        return process.env.ALLOWED_ORIGINS === '*' 
          ? ['*'] 
          : process.env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim());
      }
      
      // Configuración por defecto basada en flavor
      switch (currentFlavor) {
        case 'production':
          return [
            'https://drpestcontrol:8000',    // ✅ AGREGADO
            'https://drpestcontrol:8080',    // ✅ AGREGADO
            'https://app.pestcontrol.com',
            'https://192.168.137.177:8080'
          ];
        case 'staging':
          return [
            'https://drpestcontrol:8000',    // ✅ AGREGADO
            'https://drpestcontrol:8080',    // ✅ AGREGADO
            'https://staging.pestcontrol.com'
          ];
        case 'development':
        default:
          return ['*']; // Wildcard solo en development
      }
    })(),
    credentials: process.env.CORS_CREDENTIALS === 'true' || process.env.CORS_ENABLED === 'true'
  },
  
  // Timeouts basados en FLAVOR
  timeouts: {
    request: parseInt(process.env.REQUEST_TIMEOUT) || 
             (currentFlavor === 'production' ? 20000 : 
              currentFlavor === 'staging' ? 25000 : 30000),
    connect: parseInt(process.env.CONNECT_TIMEOUT) || 
             (currentFlavor === 'production' ? 5000 : 
              currentFlavor === 'staging' ? 8000 : 10000),
    server: parseInt(process.env.SERVER_TIMEOUT) || 30000
  },
  
  // Debug basado en FLAVOR
  debug: {
    enabled: process.env.DEBUG_MODE === 'true' || currentFlavor === 'development',
    analytics: process.env.ANALYTICS_ENABLED === 'true',
    errorReporting: process.env.ERROR_REPORTING === 'true'
  },
  
  // URLs calculadas
  urls: {
    api: process.env.API_BASE_URL,
    base: process.env.BACKEND_URL,
    public: process.env.PUBLIC_URL,
    websocket: process.env.WS_URL,
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

// ===== VALIDACIONES SEGÚN FLAVOR =====
if (config.flavor === 'production') {
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

// ===== LOGGING DE CONFIGURACIÓN SEGÚN FLAVOR =====
console.log(`🔧 Configuración cargada:`);
console.log(`   Flavor: ${config.flavor}`);
console.log(`   Entorno: ${config.environment}`);
console.log(`   Puerto: ${config.port}`);
console.log(`   Base URL: ${config.baseUrl}`);
console.log(`   SSL: ${config.ssl.enabled ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   Pool DB: ${config.database.pool.min}-${config.database.pool.max} conexiones`);
console.log(`   Debug Mode: ${config.debug.enabled ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   ✅ Rate Limit General: ${config.rateLimit.maxRequests} req/15min (AMPLIADO para uso industrial)`);
console.log(`   ✅ Rate Limit Auth: ${config.rateLimit.authMaxRequests} attempts/15min (AMPLIADO para uso industrial)`);

// Solo mostrar detalles en development/staging
if (config.flavor !== 'production') {
  console.log(`   DB Host: ${config.database.host}`);
  console.log(`   API URL: ${config.apiUrl}`);
  console.log(`   Public URL: ${config.publicUrl}`);
  console.log(`   WebSocket URL: ${config.urls.websocket}`);
  console.log(`   CORS Origins: ${Array.isArray(config.cors.origins) ? config.cors.origins.join(', ') : config.cors.origins}`);
} else {
  // Logging seguro para producción
  console.log(`🔒 [PROD] Error logging: ${config.logging.errors ? 'ENABLED' : 'DISABLED'}`);
  console.log(`🔒 [PROD] SSL status: ${config.ssl.enabled ? 'CONFIGURED' : 'DISABLED'}`);
  console.log(`🔒 [PROD] Security level: ${config.security.jwtSecret !== 'fallback-secret-key' ? 'CUSTOM' : 'DEFAULT'}`);
}

module.exports = config;