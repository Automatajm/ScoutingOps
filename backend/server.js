const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const https = require('https');
const fs = require('fs');
const rateLimit = require('express-rate-limit'); // 🔒 NUEVO: Rate limiting
const config = require('./config');
const db = require('./db');
const path = require('path');

// ===== OVERRIDE GLOBAL DE CONSOLE SEGÚN ENTORNO =====
const originalConsole = {
  log: console.log,
  info: console.info,
  warn: console.warn,
  error: console.error,
  debug: console.debug
};

// Función para generar referencia de error
const generateErrorRef = () => `REF-${Date.now()}`;

// Función para limpiar datos sensibles
const sanitizeMessage = (message) => {
  if (typeof message !== 'string') return '[SANITIZED_DATA]';
  
  return message
    .replace(/usuario[:\s]+[\w\-]+/gi, 'usuario: [HIDDEN]')
    .replace(/password[:\s]+[\w\-]+/gi, 'password: [HIDDEN]')
    .replace(/lote[:\s]+[\w\-]+/gi, 'lote: [HIDDEN]')
    .replace(/codigo[:\s]+[\w\-]+/gi, 'codigo: [HIDDEN]')
    .replace(/ip[:\s]+[\d\.]+/gi, 'ip: [HIDDEN]')
    .replace(/jwt[:\s]+[\w\.\-]+/gi, 'jwt: [HIDDEN]')
    .replace(/token[:\s]+[\w\.\-]+/gi, 'token: [HIDDEN]')
    .replace(/\b\d{6,12}\b/g, '[LOTE_CODE]')
    .replace(/SELECT.*FROM/gi, 'SELECT [QUERY] FROM')
    .replace(/WHERE.*=/gi, 'WHERE [CONDITION]');
};

// Detectar entorno
const isDevelopment = process.env.ENVIRONMENT === 'development';
const isStaging = process.env.ENVIRONMENT === 'staging';
const isProduction = process.env.ENVIRONMENT === 'production';

if (isProduction) {
  // 🚫 PRODUCCIÓN: Solo errores críticos, sin datos sensibles
  console.log = () => {}; // Silencio total
  console.info = () => {}; // Silencio total
  console.debug = () => {}; // Silencio total
  
  console.warn = (message, ...args) => {
    const ref = generateErrorRef();
    originalConsole.warn(`⚠️ WARNING: ${ref}`);
  };
  
  console.error = (message, ...args) => {
    const ref = generateErrorRef();
    originalConsole.error(`❌ ERROR: ${ref}`);
    
    // Log interno limpio para archivos (opcional)
    if (message && typeof message === 'string') {
      const cleanMessage = sanitizeMessage(message);
      // Opcional: fs.appendFileSync('error.log', `${new Date().toISOString()} - ${ref}: ${cleanMessage}\n`);
    }
  };
  
} else if (isStaging) {
  // ⚠️ STAGING: Warnings y errores, logs limitados
  console.log = () => {}; // Silencio los logs normales
  console.debug = () => {}; // Silencio debug
  
  console.info = (message, ...args) => {
    const cleanMessage = typeof message === 'string' ? sanitizeMessage(message) : message;
    originalConsole.info(`ℹ️ [STAGING]`, cleanMessage, ...args);
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [STAGING]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [STAGING]`, message, ...args);
  };
  
} else {
  // 🐛 DEVELOPMENT: Todo normal con prefijos
  console.log = (message, ...args) => {
    originalConsole.log(`🐛 [DEV]`, message, ...args);
  };
  
  console.info = (message, ...args) => {
    originalConsole.info(`ℹ️ [DEV]`, message, ...args);
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [DEV]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [DEV]`, message, ...args);
  };
  
  console.debug = (message, ...args) => {
    originalConsole.debug(`🔍 [DEV]`, message, ...args);
  };
}

// ===== LOGGER ESPECIAL PARA CASOS CRÍTICOS =====
const Logger = {
  critical: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🚨 CRITICAL: ${ref}`);
    } else {
      originalConsole.error(`🚨 CRITICAL: ${message} [${ref}]`, data);
    }
  },
  
  startup: (message) => {
    originalConsole.log(`🚀 STARTUP: ${message}`);
  },
  
  security: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🔒 SECURITY: ${ref}`);
    } else {
      originalConsole.error(`🔒 SECURITY: ${message} [${ref}]`, data);
    }
  },

  auth: (action, user = null) => {
    if (isProduction) {
      originalConsole.info(`🔐 AUTH: [USER_ACTION]`);
    } else {
      originalConsole.info(`🔐 AUTH: ${action}`, user ? { username: user, timestamp: new Date().toISOString() } : '');
    }
  },

  database: (action, details = null) => {
    if (isProduction) {
      originalConsole.info(`💾 DB: [QUERY_EXECUTED]`);
    } else {
      originalConsole.info(`💾 DB: ${action}`, details);
    }
  },

  api: (method, path, origin = null) => {
    if (isProduction) {
      // Solo log básico sin detalles
      originalConsole.info(`📡 API: ${method} [ENDPOINT]`);
    } else {
      originalConsole.info(`📡 API: ${method} ${path}`, { origin, timestamp: new Date().toISOString() });
    }
  },

  // 🔒 NUEVO: Logger para rate limiting
  rateLimitExceeded: (req, limitType) => {
    const clientIP = req.headers['x-forwarded-for'] || 
                     req.headers['x-real-ip'] || 
                     req.connection.remoteAddress || 
                     req.socket.remoteAddress ||
                     'unknown';
    
    if (isProduction) {
      originalConsole.warn(`🚫 RATE_LIMIT: ${limitType} [IP_BLOCKED]`);
    } else {
      originalConsole.warn(`🚫 RATE_LIMIT: ${limitType}`, {
        ip: clientIP,
        path: req.path,
        userAgent: req.get('User-Agent'),
        timestamp: new Date().toISOString()
      });
    }
  }
};

const app = express();

// Compartir el pool y db
app.set('pool', db.pool);
app.set('db', db);

// ==========================================
// 🔒 RATE LIMITING CONFIGURATION
// ==========================================

// Rate Limiter General para todas las rutas
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: isProduction ? 100 : 200, // Más permisivo en desarrollo
  message: {
    success: false,
    message: 'Demasiadas solicitudes desde esta IP, intenta de nuevo en 15 minutos.',
    error: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    Logger.rateLimitExceeded(req, 'GENERAL');
    res.status(429).json({
      success: false,
      message: 'Demasiadas solicitudes. Intenta de nuevo más tarde.',
      retryAfter: Math.round(req.rateLimit.resetTime / 1000),
      resetTime: new Date(req.rateLimit.resetTime).toISOString()
    });
  },
  skip: (req) => {
    // Permitir más libertad en desarrollo
    return isDevelopment && (req.ip === '::1' || req.ip === '127.0.0.1');
  }
});

// Rate Limiter ESTRICTO para autenticación
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: isProduction ? 5 : 20, // Muy estricto en producción
  skipSuccessfulRequests: true,
  message: {
    success: false,
    message: 'Demasiados intentos de login. Cuenta bloqueada por 15 minutos.',
    error: 'AUTH_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    Logger.rateLimitExceeded(req, 'AUTH');
    Logger.security('Múltiples intentos de login fallidos', {
      username: req.body?.username || 'unknown',
      ip: req.headers['x-forwarded-for'] || req.connection.remoteAddress
    });
    res.status(429).json({
      success: false,
      message: 'Demasiados intentos de login. Cuenta bloqueada temporalmente.',
      retryAfter: Math.round(req.rateLimit.resetTime / 1000),
      blockedUntil: new Date(req.rateLimit.resetTime).toISOString()
    });
  }
});

// Rate Limiter para APIs de base de datos
const dbApiLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutos
  max: isProduction ? 50 : 100,
  message: {
    success: false,
    message: 'Límite de API excedido. Intenta de nuevo en 10 minutos.',
    error: 'API_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    Logger.rateLimitExceeded(req, 'DB_API');
    res.status(429).json({
      success: false,
      message: 'Límite de consultas a la base de datos excedido.',
      retryAfter: Math.round(req.rateLimit.resetTime / 1000)
    });
  }
});

// Rate Limiter para configuración y diagnóstico
const configLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutos
  max: isProduction ? 20 : 50,
  message: {
    success: false,
    message: 'Acceso a configuración limitado. Intenta de nuevo en 5 minutos.',
    error: 'CONFIG_RATE_LIMIT_EXCEEDED'
  },
  handler: (req, res) => {
    Logger.rateLimitExceeded(req, 'CONFIG');
    res.status(429).json({
      success: false,
      message: 'Límite de acceso a configuración excedido.',
      retryAfter: Math.round(req.rateLimit.resetTime / 1000)
    });
  }
});

// ===== CORS CONFIGURATION =====
const allowedOrigins = [
  'http://localhost:8080',
  'http://127.0.0.1:8080',
  'https://localhost:8080',
  'https://127.0.0.1:8080',
  'http://172.24.16.1:8080',
  'https://172.24.16.1:8080',
  'http://10.0.0.19:8080',
  'https://10.0.0.19:8080',
  'http://192.168.1.100:8080',
  'http://192.168.0.100:8080',
  'https://192.168.1.100:8080',
  'https://192.168.0.100:8080',
  'https://165.227.219.173:8080',
  'https://www.autoinfoplus.com',
  'https://autoinfoplus.com',
  /https:\/\/.*\.ngrok\.io$/,
  /https:\/\/.*\.ngrok-free\.app$/,
  /https:\/\/.*\.ngrok\.app$/,
  /https:\/\/.*\.loca\.lt$/,
  /https:\/\/.*\.github\.io$/,
  /https:\/\/.*\.githubusercontent\.com$/,
  /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}:8080$/,
  /^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}:8080$/,
  /^http:\/\/172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}:8080$/,
  /^https:\/\/192\.168\.\d{1,3}\.\d{1,3}:8080$/,
  /^https:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}:8080$/,
  /^https:\/\/172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}:8080$/
];

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    
    const isAllowed = allowedOrigins.some(allowedOrigin => {
      if (typeof allowedOrigin === 'string') {
        return origin === allowedOrigin;
      } else if (allowedOrigin instanceof RegExp) {
        return allowedOrigin.test(origin);
      }
      return false;
    });
    
    if (isAllowed) {
      callback(null, true);
    } else {
      if (isDevelopment) {
        Logger.security('CORS: Origin not in allowedOrigins but allowed in development', origin);
        callback(null, true);
      } else {
        Logger.security('CORS: Origin BLOCKED in production', origin);
        callback(new Error('No permitido por CORS'));
      }
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH', 'HEAD'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'X-Requested-With',
    'Accept',
    'Origin',
    'Access-Control-Request-Method',
    'Access-Control-Request-Headers',
    'ngrok-skip-browser-warning'
  ],
  exposedHeaders: ['Content-Length', 'Content-Type'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));

// ===== APLICAR RATE LIMITERS =====
// 🔒 Rate limiter general ANTES de otros middlewares
app.use(generalLimiter);

// ===== MIDDLEWARE ADICIONAL =====
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.header('Access-Control-Allow-Credentials', 'true');
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS,PATCH');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With, Accept, Origin, ngrok-skip-browser-warning');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send();
    return;
  }
  
  next();
});

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Middleware para log de peticiones con seguridad
app.use((req, res, next) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';
  
  Logger.api(req.method, req.path, req.headers.origin);
  
  // 🔒 NUEVO: Log rate limit info si está disponible
  if (req.rateLimit && !isProduction) {
    console.debug(`Rate Limit Info: ${req.rateLimit.remaining}/${req.rateLimit.limit} remaining for ${clientIP}`);
  }
  
  next();
});

// Middleware de timeout
app.use((req, res, next) => {
  const longTimeoutRoutes = ['/api/usuarios/roles/lista', '/api/reportes', '/api/diagnostico'];
  const excludedRoutes = ['/api/uploads'];
  
  const shouldExclude = excludedRoutes.some(route => req.url.startsWith(route));
  const needsLongTimeout = longTimeoutRoutes.some(route => req.url.includes(route));
  
  if (!shouldExclude) {
    const timeoutDuration = needsLongTimeout ? 60000 : 30000;
    
    const timeout = setTimeout(() => {
      if (!res.headersSent) {
        Logger.critical('Timeout en petición', { method: req.method, url: req.originalUrl || req.url });
        res.status(503).json({
          success: false,
          message: 'La petición excedió el tiempo límite'
        });
      }
    }, timeoutDuration);

    res.on('finish', () => {
      clearTimeout(timeout);
    });
  }

  next();
});

// Middleware para verificación de roles
const checkRole = (roles) => {
  return (req, res, next) => {
    const userRole = req.user ? req.user.pmus_funcion : null;
    
    if (!userRole) {
      Logger.security('Acceso no autorizado - sin autenticación');
      return res.status(401).json({
        success: false,
        message: 'No autorizado - Se requiere autenticación'
      });
    }
    
    if (roles.includes(userRole)) {
      next();
    } else {
      Logger.security('Acceso prohibido - permisos insuficientes', { userRole, requiredRoles: roles });
      return res.status(403).json({
        success: false,
        message: 'Acceso prohibido - No tienes permisos suficientes'
      });
    }
  };
};

// Importar rutas
const usuariosRoutes = require('./routes/usuarios');
const rolesRoutes = require('./routes/roles');
const variedadesRoutes = require('./routes/variedades');
const unidadesCultivoRoutes = require('./routes/unidad_cultivo');
const plagasRoutes = require('./routes/plaga');
const nivelesInfestacionRoutes = require('./routes/nivel_infestacion');
const lotesRoutes = require('./routes/lotes');
const monitoreoRoutes = require('./routes/monitoreo');

// Middleware para compartir configuración
app.use((req, res, next) => {
  req.config = config;
  next();
});

// 🔒 Configurar rutas con rate limiting específico
app.use('/api/usuarios', dbApiLimiter, usuariosRoutes);
app.use('/api/roles', dbApiLimiter, rolesRoutes);
app.use('/api/variedades', dbApiLimiter, variedadesRoutes);
app.use('/api/unidadesCultivo', dbApiLimiter, unidadesCultivoRoutes);
app.use('/api/plagas', dbApiLimiter, plagasRoutes);
app.use('/api/nivelesinfestacion', dbApiLimiter, nivelesInfestacionRoutes);
app.use('/api/lotes', dbApiLimiter, lotesRoutes);
app.use('/api/monitoreo', dbApiLimiter, monitoreoRoutes);

// ===== RUTA RAÍZ =====
app.get('/', (req, res) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';

  // Pool status con seguridad
  const poolStatus = {
    total: db.pool ? db.pool.totalCount : 0,
    idle: db.pool ? db.pool.idleCount : 0,
    waiting: db.pool ? db.pool.waitingCount : 0,
    pending: db.pool ? db.pool.pendingCount : 0
  };

  console.log(`Estado del pool - total: ${poolStatus.total}, inactivos: ${poolStatus.idle}, en espera: ${poolStatus.waiting}, operaciones pendientes: ${poolStatus.pending}`);

  res.json({ 
    success: true,
    message: 'API Pest Control funcionando correctamente',
    environment: config.environment,
    version: config.version,
    timestamp: new Date().toISOString(),
    // En producción, información limitada
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      urls: config.urls,
      systemInfo: config.system,
      connectionInfo: {
        clientIP: clientIP,
        userAgent: req.headers['user-agent'],
        origin: req.headers.origin,
        host: req.headers.host
      },
      corsInfo: {
        allowedOrigins: allowedOrigins.length,
        currentOrigin: req.headers.origin || 'No origin'
      },
      // 🔒 NUEVO: Rate limit info
      rateLimitInfo: req.rateLimit ? {
        remaining: req.rateLimit.remaining,
        total: req.rateLimit.limit,
        resetTime: new Date(req.rateLimit.resetTime).toISOString()
      } : null
    })
  });
});

// ===== RUTA DE LOGIN SEGURA CON RATE LIMITING =====
app.post('/api/auth/login', authLimiter, async (req, res) => {
  const { username, password } = req.body;
  
  try {
    Logger.auth('Intento de login', username);
    
    const result = await db.query(
      `SELECT 
          u.pmus_id, u.pmus_codigo, u.pmus_usuario,
          u.pmus_funcion, u.pmus_estatus, u.pmus_password,
          u.pmus_correo, r.pmrl_descripcion as rol_descripcion
       FROM pm_usuarios u
       LEFT JOIN pm_rol r ON u.pmus_funcion = r.pmrl_id
       WHERE u.pmus_usuario = $1 
         AND u.pmus_estatus = 1`,
      [username]
    );

    Logger.database('Consulta de usuario ejecutada', `Resultados: ${result.rows.length}`);

    if (result.rows.length === 0) {
      Logger.security('Usuario no encontrado', username);
      return res.status(401).json({
         success: false,
         message: 'Usuario no encontrado'
       });
    }

    const user = result.rows[0];

    // Verificar contraseña
    const isPasswordValid = await bcrypt.compare(password, user.pmus_password);

    if (!isPasswordValid) {
      Logger.security('Contraseña incorrecta', username);
      return res.status(401).json({
         success: false,
         message: 'Contraseña incorrecta'
       });
    }

    // Determinar roles
    let roles = [];
    if (user.pmus_funcion === 1) {
      roles = ['admin'];
    } else if (user.pmus_funcion === 2) {
      roles = ['monitoreador'];
    } else if (user.pmus_funcion === 4) {
      roles = ['monitoreador'];
    } else {
      roles = ['usuario'];
    }

    // Preparar respuesta sin contraseña
    const { pmus_password, ...userWithoutPassword } = user;
    const userWithRoles = {
      ...userWithoutPassword,
      roles: roles
    };

    Logger.auth('Login exitoso', {
      usuario: username,
      funcion: user.pmus_funcion,
      rol: user.rol_descripcion
    });

    res.json({
      success: true,
      user: userWithRoles,
      config: {
        version: config.version,
        environment: config.environment,
        // En producción, información limitada
        ...(isProduction ? {} : {
          apiUrl: config.apiUrl,
          urls: config.urls,
          systemInfo: config.system
        })
      }
    });
  } catch (err) {
    Logger.critical('Error en login', err.message);
    res.status(500).json({
       success: false,
       message: 'Error del servidor',
      error: isDevelopment ? err.message : 'Error interno'
     });
  }
});

// ===== RUTAS DE CONFIGURACIÓN CON RATE LIMITING =====
app.get('/api/config', configLimiter, (req, res) => {
  res.json({
    success: true,
    message: 'Configuración del servidor',
    version: config.version,
    environment: config.environment,
    timestamp: new Date().toISOString(),
    // En producción, información limitada
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      baseUrl: config.apiUrl.replace('/api', ''),
      urls: config.urls,
      systemInfo: config.system,
      corsInfo: {
        allowedOrigins: allowedOrigins.length
      }
    })
  });
});

app.get('/api/system/status', configLimiter, (req, res) => {
  res.json({
    success: true,
    status: 'online',
    message: 'Sistema funcionando correctamente',
    serverTime: new Date().toISOString(),
    environment: config.environment,
    version: config.version,
    // En producción, información limitada
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      baseUrl: config.apiUrl.replace('/api', ''),
      urls: config.urls,
      systemInfo: config.system,
      serverStatus: {
        databaseConnected: true,
        uptime: Math.floor(process.uptime()),
        memoryUsage: process.memoryUsage(),
        nodeVersion: process.version
      }
    })
  });
});

app.get('/api/health', async (req, res) => {
  try {
    const dbTest = await db.query('SELECT NOW() as current_time, 1 as test');
    
    res.json({
      success: true,
      status: 'healthy',
      message: 'Servidor y base de datos funcionando',
      checks: {
        database: dbTest.rows.length > 0 ? 'connected' : 'disconnected',
        server: 'running',
        api: 'functional'
      },
      info: {
        serverTime: new Date().toISOString(),
        uptime: Math.floor(process.uptime()),
        // En producción, información limitada
        ...(isProduction ? {} : {
          dbResponseTime: dbTest.rows[0]?.current_time,
          memory: process.memoryUsage()
        })
      }
    });
  } catch (err) {
    Logger.critical('Health check failed', err.message);
    res.status(503).json({
      success: false,
      status: 'unhealthy',
      error: isDevelopment ? err.message : 'Database connection failed',
      timestamp: new Date().toISOString()
    });
  }
});

// ===== RUTA DE DIAGNÓSTICO CON RATE LIMITING =====
app.get('/api/diagnostico', configLimiter, async (req, res) => {
  try {
    const startTime = Date.now();
    const dbResult = await db.query('SELECT NOW() as db_time, version() as db_version');
    const dbResponseTime = Date.now() - startTime;
    
    const poolStats = db.getPoolStats ? db.getPoolStats() : { message: 'Stats no disponibles' };
    
    res.json({
      success: true,
      message: 'Diagnóstico completo del sistema',
      serverInfo: {
        status: 'operational',
        uptime: Math.floor(process.uptime()),
        uptimeFormatted: formatUptime(process.uptime()),
        environment: config.environment,
        version: config.version,
        // En producción, información limitada
        ...(isProduction ? {} : {
          memoryUsage: process.memoryUsage(),
          nodeVersion: process.version,
          platform: process.platform
        })
      },
      databaseInfo: {
        status: 'connected',
        responseTimeMs: dbResponseTime,
        // En producción, información limitada
        ...(isProduction ? {} : {
          serverTime: dbResult.rows[0]?.db_time,
          version: dbResult.rows[0]?.db_version,
          pool: poolStats
        })
      },
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    Logger.critical('Error en diagnóstico', err.message);
    res.status(500).json({
      success: false,
      message: 'Error en diagnóstico del sistema',
      error: isDevelopment ? err.message : 'Error interno',
      timestamp: new Date().toISOString()
    });
  }
});

// Función auxiliar para formatear uptime
function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  return `${days}d ${hours}h ${minutes}m ${secs}s`;
}

// ===== MANEJO DE ERRORES =====
app.use((err, req, res, next) => {
  // 🔒 NUEVO: Log específico si es error de rate limiting
  if (err.status === 429 || err.type === 'rate_limit') {
    Logger.rateLimitExceeded(req, 'MIDDLEWARE_ERROR');
  } else {
    Logger.critical('Error no controlado', err.message);
  }
  
  res.status(err.status || 500).json({
    success: false,
    message: err.status === 429 ? 'Demasiadas solicitudes' : 'Error interno del servidor',
    error: isDevelopment ? err.message : 'Contacta al administrador',
    timestamp: new Date().toISOString()
  });
});

// Manejo de rutas no encontradas
app.use((req, res) => {
  Logger.security('Ruta no encontrada', { method: req.method, url: req.originalUrl });
  res.status(404).json({
    success: false,
    message: `Ruta ${req.originalUrl} no encontrada`,
    availableRoutes: [
      'GET /',
      'GET /api/config',
      'GET /api/system/status',
      'GET /api/health',
      'GET /api/diagnostico',
      'POST /api/auth/login',
      'GET /api/variedades/*',
      'GET /api/nivelesinfestacion/*',
      'GET /api/monitoreo/*'
    ],
    timestamp: new Date().toISOString()
  });
});

// ===== CONFIGURACIÓN SSL =====
const sslOptions = {
  key: fs.readFileSync('../key.pem'),
  cert: fs.readFileSync('../cert.pem')
};

// ===== INICIALIZACIÓN DEL SERVIDOR =====
const server = https.createServer(sslOptions, app).listen(config.port, '0.0.0.0', () => {
  Logger.startup(`Servidor Pest Control iniciado exitosamente con HTTPS`);
  Logger.startup(`Host: ${config.host}`);
  Logger.startup(`Puerto: ${config.port}`);
  Logger.startup(`Entorno: ${config.environment}`);
  Logger.startup(`Versión: ${config.version}`);
  
  // 🔒 NUEVO: Log de configuración de rate limiting
  Logger.startup(`Rate Limiting: ${isProduction ? 'STRICT' : 'PERMISSIVE'} mode`);
  Logger.startup(`Auth Rate Limit: ${isProduction ? '5' : '20'} attempts per 15min`);
  Logger.startup(`General Rate Limit: ${isProduction ? '100' : '200'} requests per 15min`);
  Logger.startup(`DB API Rate Limit: ${isProduction ? '50' : '100'} requests per 10min`);
  Logger.startup(`Config Rate Limit: ${isProduction ? '20' : '50'} requests per 5min`);
  
  if (!isProduction) {
    Logger.startup(`URL Local HTTPS: https://localhost:${config.port}`);
    Logger.startup(`URL Red HTTPS: https://10.0.0.19:${config.port}`);
    Logger.startup(`Sistema: ${config.system.platform} - ${config.system.hostname}`);
    Logger.startup(`CORS: Configurado para ${allowedOrigins.length} orígenes`);
  }
  
  // Probar conexión a la base de datos
  db.query('SELECT NOW() as connection_test')
    .then(result => {
      Logger.startup('Conexión a la base de datos exitosa');
      Logger.database('Tiempo de respuesta DB', new Date().toISOString());
    })
    .catch(err => {
      Logger.critical('Error conectando a la base de datos', err.message);
    });
});

// ===== MANEJO GRACEFUL DE CIERRE =====
const gracefulShutdown = async (signal) => {
  Logger.startup(`Recibida señal ${signal}. Cerrando servidor...`);
  
  server.close(async () => {
    Logger.startup('Servidor HTTPS cerrado');
    
    try {
      if (db.end) {
        await db.end();
        Logger.startup('Pool de conexiones cerrado');
      }
      Logger.startup('Aplicación cerrada correctamente');
      process.exit(0);
    } catch (err) {
      Logger.critical('Error al cerrar', err.message);
      process.exit(1);
    }
  });
  
  setTimeout(() => {
    Logger.critical('Forzando cierre...');
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('unhandledRejection', (reason, promise) => {
  Logger.critical('Unhandled Rejection', { reason, promise });
});

process.on('uncaughtException', (error) => {
  Logger.critical('Uncaught Exception', error.message);
  process.exit(1);
});

module.exports = app;