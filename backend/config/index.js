// =====================================================
// CONFIGURACIÓN CENTRALIZADA - PUNTO DE ENTRADA ÚNICO
// =====================================================
// Este es el ÚNICO archivo que debes importar en tu código:
// const config = require('./config');

const environmentConfig = require('./environment');
const clientConfig = require('./client.config');

// Obtener puertos
const backendPort = parseInt(process.env.BACKEND_PORT || process.env.PORT || 8000);
const frontendPort = parseInt(process.env.FRONTEND_PORT || 8080);

// Obtener configuración del cliente
const clientInfo = clientConfig.getConfig(
  environmentConfig.flavor,
  backendPort,
  frontendPort
);

// Construir configuración unificada
const config = {
  // ===== INFORMACIÓN BÁSICA =====
  environment: environmentConfig.flavor,
  flavor: environmentConfig.flavor,
  version: process.env.VERSION || '1.0.0',
  appName: process.env.APP_NAME || 'PestControl',

  // ===== CLIENTE =====
  client: clientInfo.client,

  // ===== PUERTOS Y HOST =====
  port: backendPort,
  host: process.env.BACKEND_HOST || '0.0.0.0',

  // ===== URLS =====
  urls: clientInfo.urls,
  apiUrl: clientInfo.urls.apiUrl,
  baseUrl: clientInfo.urls.baseUrl,
  publicUrl: clientInfo.urls.publicUrl,

  // ===== BASE DE DATOS =====
  database: environmentConfig.getDatabaseConfig(),

  // ===== SEGURIDAD =====
  security: environmentConfig.getSecurityConfig(),

  // ===== SSL =====
  ssl: environmentConfig.getSSLConfig(),

  // ===== RATE LIMITING =====
  rateLimit: environmentConfig.getRateLimitConfig(),

  // ===== CORS =====
  cors: clientInfo.cors,

  // ===== TIMEOUTS =====
  timeouts: environmentConfig.getTimeoutsConfig(),

  // ===== LOGGING =====
  logging: environmentConfig.getLoggingConfig(),

  // ===== DEBUG =====
  debug: environmentConfig.getDebugConfig(),

  // ===== INFORMACIÓN DEL SISTEMA =====
  system: clientConfig.getSystemInfo(),

  // ===== HELPERS =====
  isDevelopment: environmentConfig.isDevelopment,
  isStaging: environmentConfig.isStaging,
  isProduction: environmentConfig.isProduction,
  isDocker: environmentConfig.isDocker,
};

// ===== LOGGING DE CONFIGURACIÓN =====
console.log('\n╔════════════════════════════════════════════════════╗');
console.log('║     CONFIGURACIÓN PEST CONTROL CARGADA            ║');
console.log('╚════════════════════════════════════════════════════╝\n');

console.log(`🏢 Cliente: ${config.client.name}`);
console.log(`🎯 Entorno: ${config.flavor}`);
console.log(`🐳 Docker: ${config.isDocker ? 'SÍ' : 'NO'}`);
console.log(`📡 Puerto: ${config.port}`);
console.log(`🌐 IP: ${config.client.ip}`);
console.log(`🖥️  Hostname: ${config.client.hostname}`);
console.log(`\n📋 URLs:`);
console.log(`   API: ${config.apiUrl}`);
console.log(`   Base: ${config.baseUrl}`);
console.log(`   Local: ${config.urls.local}`);
console.log(`   Red: ${config.urls.network}`);

console.log(`\n🗄️  Base de Datos:`);
console.log(`   Host: ${config.database.host}`);
console.log(`   DB: ${config.database.database}`);
console.log(`   User: ${config.database.user}`);
console.log(`   Pool: ${config.database.pool.min}-${config.database.pool.max} conexiones`);

console.log(`\n🔐 Seguridad:`);
console.log(`   SSL: ${config.ssl.enabled ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   JWT: ${config.security.jwtSecret !== 'fallback-secret-key' ? 'Configurado' : 'Por defecto'}`);
console.log(`   Salt Rounds: ${config.security.saltRounds}`);

console.log(`\n🚦 Rate Limiting:`);
console.log(`   General: ${config.rateLimit.maxRequests} req/15min`);
console.log(`   Auth: ${config.rateLimit.authMaxRequests} attempts/15min`);

console.log(`\n🎭 CORS:`);
console.log(`   Orígenes permitidos: ${config.cors.origins.length}`);
if (!config.isProduction) {
  console.log(`   Orígenes: ${config.cors.origins.slice(0, 3).join(', ')}...`);
}

console.log(`\n📝 Logging:`);
console.log(`   Nivel: ${config.logging.level}`);
console.log(`   API Calls: ${config.logging.requests ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   Errores: ${config.logging.errors ? 'Habilitado' : 'Deshabilitado'}`);

console.log(`\n🔧 Debug:`);
console.log(`   Mode: ${config.debug.enabled ? 'Habilitado' : 'Deshabilitado'}`);
console.log(`   Analytics: ${config.debug.analytics ? 'Habilitado' : 'Deshabilitado'}`);

console.log('\n════════════════════════════════════════════════════\n');

// Exportar configuración
module.exports = config;
