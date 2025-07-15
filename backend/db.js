// ===== db.js ACTUALIZADO - CON CONTROL SSL =====
const { Pool } = require('pg');
const config = require('./config');

// ===== CONFIGURACIÓN DEL POOL SEGÚN ENTORNO =====
const poolConfig = {
  host: config.database.host,
  port: config.database.port,
  database: config.database.database,
  user: config.database.user,
  password: config.database.password,
  
  // Configuración del pool (ahora desde config)
  max: config.database.pool.max,
  min: config.database.pool.min,
  idleTimeoutMillis: config.database.pool.idleTimeoutMillis,
  connectionTimeoutMillis: config.database.pool.connectionTimeoutMillis,
  statement_timeout: config.database.pool.statementTimeout,
  query_timeout: config.database.pool.queryTimeout,
  
  // 🔧 ARREGLO SSL: Solo habilitar SSL cuando se especifique explícitamente
  ...(config.environment === 'production' && 
      config.database.host !== 'localhost' && 
      process.env.DB_SSL === 'true' && {
    ssl: { rejectUnauthorized: false },
    keepAlive: true,
    keepAliveInitialDelayMillis: 10000
  })
};

// ===== CREAR POOL =====
const pool = new Pool(poolConfig);

// ===== LOGGING DE CONEXIÓN =====
const originalConsole = {
  log: console.log,
  info: console.info,
  warn: console.warn,
  error: console.error
};

const Logger = {
  database: (action, details = null) => {
    if (config.environment === 'production') {
      originalConsole.info(`💾 DB: [QUERY_EXECUTED]`);
    } else {
      originalConsole.info(`💾 DB: ${action}`, details);
    }
  },
  
  critical: (message, data = null) => {
    const ref = `REF-${Date.now()}`;
    if (config.environment === 'production') {
      // TEMPORAL: Mostrar errores en production para debug
      originalConsole.error(`🚨 CRITICAL: ${message} [${ref}]`, data);
    } else {
      originalConsole.error(`🚨 CRITICAL: ${message} [${ref}]`, data);
    }
  }
};

// ===== EVENTOS DEL POOL =====
pool.on('connect', (client) => {
  if (config.logging.queries) {
    Logger.database('Nueva conexión establecida', {
      processID: client.processID,
      timestamp: new Date().toISOString()
    });
  }
});

pool.on('acquire', (client) => {
  if (config.logging.queries) {
    Logger.database('Cliente adquirido del pool', {
      processID: client.processID
    });
  }
});

pool.on('error', (err, client) => {
  Logger.critical('Error en el pool de conexiones', {
    error: err.message,
    processID: client?.processID
  });
});

pool.on('remove', (client) => {
  if (config.logging.queries) {
    Logger.database('Cliente removido del pool', {
      processID: client.processID
    });
  }
});

// ===== FUNCIÓN DE QUERY CON LOGGING =====
const query = async (text, params) => {
  const start = Date.now();
  
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    
    // Log según configuración
    if (config.logging.queries && config.environment === 'development') {
      originalConsole.log(`🐛 [DEV] Consulta ejecutada:`, {
        text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
        params: params?.length > 0 ? `[${params.length} params]` : 'sin parámetros',
        duration,
        rows: result.rowCount
      });
    } else if (config.logging.queries) {
      Logger.database('Query ejecutado', `Duration: ${duration}ms, Rows: ${result.rowCount}`);
    }
    
    return result;
  } catch (error) {
    const duration = Date.now() - start;
    
    Logger.critical('Error en consulta SQL', {
      error: error.message,
      query: text.substring(0, 100),
      duration,
      code: error.code
    });
    
    throw error;
  }
};

// ===== FUNCIÓN PARA OBTENER ESTADÍSTICAS DEL POOL =====
const getPoolStats = () => {
  return {
    totalCount: pool.totalCount,
    idleCount: pool.idleCount,
    waitingCount: pool.waitingCount,
    pendingCount: pool.pendingCount || 0,
    maxConnections: config.database.pool.max,
    minConnections: config.database.pool.min,
    connectionTimeoutMs: config.database.pool.connectionTimeoutMillis,
    idleTimeoutMs: config.database.pool.idleTimeoutMillis
  };
};

// ===== FUNCIÓN DE HEALTH CHECK =====
const healthCheck = async () => {
  try {
    const start = Date.now();
    const result = await query('SELECT NOW() as current_time, version() as db_version');
    const responseTime = Date.now() - start;
    
    return {
      status: 'healthy',
      responseTimeMs: responseTime,
      serverTime: result.rows[0]?.current_time,
      version: result.rows[0]?.db_version?.split(' ')[0] || 'unknown',
      poolStats: getPoolStats()
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message,
      poolStats: getPoolStats()
    };
  }
};

// ===== FUNCIÓN PARA CERRAR CONEXIONES =====
const end = async () => {
  try {
    await pool.end();
    Logger.database('Pool de conexiones cerrado correctamente');
  } catch (error) {
    Logger.critical('Error al cerrar pool', error.message);
    throw error;
  }
};

// ===== LOGGING INICIAL =====
console.log(`💾 Pool de DB configurado:`);
console.log(`   Conexiones: ${config.database.pool.min}-${config.database.pool.max}`);
console.log(`   Timeout: ${config.database.pool.connectionTimeoutMillis}ms`);
console.log(`   Host: ${config.database.host}:${config.database.port}`);
console.log(`   SSL: ${process.env.DB_SSL === 'true' ? 'Habilitado' : 'Deshabilitado'}`);

if (config.environment === 'development') {
  console.log(`   Database: ${config.database.database}`);
  console.log(`   User: ${config.database.user}`);
  console.log(`   Logging: Queries=${config.logging.queries}, Errors=${config.logging.errors}`);
}

// ===== EXPORTAR =====
module.exports = {
  pool,
  query,
  getPoolStats,
  healthCheck,
  end
};