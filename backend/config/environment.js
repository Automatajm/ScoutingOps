// =====================================================
// ENVIRONMENT.JS - DETECCIÓN Y CONFIGURACIÓN DE ENTORNO
// =====================================================
// Maneja la detección automática de entorno y configuración específica

require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

// ===== DETECCIÓN DE ENTORNO =====

/**
 * Detecta el flavor/entorno de ejecución
 * Prioridad:
 * 1. Variable de entorno FLAVOR (forzado por script npm)
 * 2. Variable de entorno NODE_ENV
 * 3. Auto-detección basada en indicadores
 * 4. Fallback a 'development'
 */
function detectFlavor() {
  // 1. FLAVOR explícito (mayor prioridad)
  if (process.env.FLAVOR) {
    console.log(`🥇 FLAVOR desde .env: ${process.env.FLAVOR}`);
    return process.env.FLAVOR.toLowerCase();
  }

  // 2. NODE_ENV como segundo criterio
  if (process.env.NODE_ENV) {
    console.log(`🥈 FLAVOR desde NODE_ENV: ${process.env.NODE_ENV}`);
    return process.env.NODE_ENV.toLowerCase();
  }

  // 3. Auto-detección
  const autoDetected = autoDetectEnvironment();
  console.log(`🤖 FLAVOR auto-detectado: ${autoDetected}`);
  return autoDetected;
}

/**
 * Auto-detecta el entorno basado en múltiples indicadores
 */
function autoDetectEnvironment() {
  // Detectar Docker
  if (isDocker()) {
    return 'production';
  }

  // Detectar CI/CD
  if (process.env.CI || process.env.CONTINUOUS_INTEGRATION) {
    return 'staging';
  }

  // Detectar por puerto (80/443 = production)
  const port = parseInt(process.env.BACKEND_PORT || process.env.PORT || 8000);
  if (port === 80 || port === 443) {
    return 'production';
  }

  // Detectar por hostname
  const hostname = require('os').hostname().toLowerCase();
  if (hostname.includes('prod') || hostname.includes('production')) {
    return 'production';
  }
  if (hostname.includes('staging') || hostname.includes('stg')) {
    return 'staging';
  }

  // Default: development (más seguro)
  return 'development';
}

/**
 * Detecta si estamos corriendo en Docker
 */
function isDocker() {
  const fs = require('fs');
  
  // Método 1: Verificar archivo .dockerenv
  if (fs.existsSync('/.dockerenv')) {
    return true;
  }
  
  // Método 2: Verificar cgroup
  try {
    const cgroup = fs.readFileSync('/proc/1/cgroup', 'utf8');
    if (cgroup.includes('docker') || cgroup.includes('kubepods')) {
      return true;
    }
  } catch (err) {
    // Archivo no existe (probablemente Windows o Mac)
  }
  
  // Método 3: Variable de entorno
  if (process.env.DOCKER_CONTAINER === 'true') {
    return true;
  }
  
  // Método 4: Hostname típico de Docker
  const hostname = require('os').hostname();
  if (hostname.length === 12 && /^[a-f0-9]{12}$/.test(hostname)) {
    return true;
  }
  
  return false;
}

// ===== CONFIGURACIÓN DEL ENTORNO =====

const flavor = detectFlavor();
const isDevelopment = flavor === 'development';
const isStaging = flavor === 'staging';
const isProduction = flavor === 'production';
const isDockerEnv = isDocker();

console.log(`🎯 Entorno configurado: ${flavor}`);
console.log(`🐳 Docker: ${isDockerEnv ? 'SÍ' : 'NO'}`);

// ===== MODO DEBUG EN PRODUCCIÓN =====
// Permite habilitar logs en producción para debugging
const enableLogsInProduction = process.env.ENABLE_LOGS === 'true' || process.env.DEBUG_MODE === 'true';

if (isProduction && enableLogsInProduction) {
  console.log(`\n⚠️  MODO DEBUG EN PRODUCCIÓN HABILITADO`);
  console.log(`⚠️  Los logs estarán visibles. Deshabilita en producción real.\n`);
}

// ===== CONFIGURACIÓN DE BASE DE DATOS =====

/**
 * Retorna la configuración de base de datos según el entorno
 */
function getDatabaseConfig() {
  // Si estamos en Docker, usar variables _DOCKER
  // Si estamos en local, usar variables _LOCAL
  const useDocker = isDockerEnv;
  
  const config = {
    host: useDocker 
      ? (process.env.DB_HOST_DOCKER || 'postgres')
      : (process.env.DB_HOST_LOCAL || process.env.DB_HOST || 'localhost'),
    port: parseInt(process.env.DB_PORT || 5432),
    database: useDocker
      ? (process.env.DB_NAME_DOCKER || 'pest_control')
      : (process.env.DB_NAME_LOCAL || process.env.DB_NAME || 'Pest_Control'),
    user: useDocker
      ? (process.env.DB_USER_DOCKER || 'pestuser')
      : (process.env.DB_USER_LOCAL || process.env.DB_USER || 'postgres'),
    password: useDocker
      ? (process.env.DB_PASSWORD_DOCKER || 'pestpass123')
      : (process.env.DB_PASSWORD_LOCAL || process.env.DB_PASSWORD || '0824'),
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    pool: {
      max: isProduction ? 20 : (isStaging ? 10 : 10),
      min: isProduction ? 5 : (isStaging ? 2 : 2),
      idleTimeoutMillis: 10000,
      connectionTimeoutMillis: isProduction ? 5000 : 10000,
      statementTimeout: isProduction ? 15000 : 30000,
      queryTimeout: isProduction ? 15000 : 30000
    }
  };

  return config;
}

// ===== CONFIGURACIÓN DE SEGURIDAD =====

function getSecurityConfig() {
  const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key';
  
  // Advertencias de seguridad
  if (isProduction) {
    const warnings = [];
    
    if (jwtSecret === 'fallback-secret-key') {
      warnings.push('JWT_SECRET no configurado en producción');
    }
    
    const dbPassword = isDockerEnv ? process.env.DB_PASSWORD_DOCKER : process.env.DB_PASSWORD_LOCAL;
    if (dbPassword === '0824' || dbPassword === 'pestpass123') {
      warnings.push('Password de desarrollo en producción');
    }
    
    if (process.env.DEBUG_MODE === 'true') {
      warnings.push('DEBUG_MODE habilitado en producción');
    }
    
    if (warnings.length > 0) {
      console.log('\n⚠️  ADVERTENCIAS DE CONFIGURACIÓN:');
      warnings.forEach(w => console.log(`⚠️  ${w}`));
      console.log('');
    }
  }

  return {
    jwtSecret: jwtSecret,
    jwtExpiration: process.env.JWT_EXPIRATION || '24h',
    saltRounds: isProduction ? 12 : 10,
    sessionSecret: process.env.SESSION_SECRET || 'session-secret',
    corsEnabled: process.env.CORS_ENABLED !== 'false'
  };
}

// ===== CONFIGURACIÓN DE SSL =====

function getSSLConfig() {
  // SSL puede ser forzado por variable de entorno
  const sslForced = process.env.SSL_ENABLED === 'true';
  
  return {
    enabled: sslForced || isProduction || process.env.SSL_ENABLED !== 'false',
    keyPath: process.env.SSL_KEY_PATH || '../key.pem',
    certPath: process.env.SSL_CERT_PATH || '../cert.pem',
    rejectUnauthorized: isProduction
  };
}

// ===== CONFIGURACIÓN DE RATE LIMITING =====

function getRateLimitConfig() {
  // Valores específicos por entorno
  const configs = {
    production: {
      maxRequests: 1000,
      authMaxRequests: 25
    },
    staging: {
      maxRequests: 800,
      authMaxRequests: 35
    },
    development: {
      maxRequests: 500,
      authMaxRequests: 50
    }
  };

  const config = configs[flavor] || configs.development;

  // Permitir override por variables de entorno
  return {
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || config.maxRequests),
    authMaxRequests: parseInt(process.env.AUTH_RATE_LIMIT_MAX || config.authMaxRequests),
    windowMs: 15 * 60 * 1000 // 15 minutos
  };
}

// ===== CONFIGURACIÓN DE TIMEOUTS =====

function getTimeoutsConfig() {
  return {
    request: isProduction ? 30000 : 60000,
    database: isProduction ? 15000 : 30000,
    upload: 120000
  };
}

// ===== CONFIGURACIÓN DE LOGGING =====

function getLoggingConfig() {
  // En producción, logs deshabilitados UNLESS enableLogsInProduction
  const logsEnabled = !isProduction || enableLogsInProduction;
  
  return {
    level: isDevelopment ? 'debug' : (isStaging ? 'info' : 'error'),
    console: logsEnabled,
    file: isProduction,
    requests: logsEnabled && isDevelopment, // Solo en dev
    errors: true, // Siempre logear errores
    database: logsEnabled && !isProduction,
    auth: logsEnabled
  };
}

// ===== CONFIGURACIÓN DE DEBUG =====

function getDebugConfig() {
  return {
    enabled: isDevelopment || process.env.DEBUG_MODE === 'true',
    verbose: process.env.DEBUG === '*',
    analytics: process.env.DEBUG_ANALYTICS === 'true'
  };
}

// ===== EXPORTAR =====

module.exports = {
  // Flavor
  flavor,
  isDevelopment,
  isStaging,
  isProduction,
  isDocker: isDockerEnv,
  
  // Configuraciones
  getDatabaseConfig,
  getSecurityConfig,
  getSSLConfig,
  getRateLimitConfig,
  getTimeoutsConfig,
  getLoggingConfig,
  getDebugConfig,
  
  // Flags especiales
  enableLogsInProduction
};