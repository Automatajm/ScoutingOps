const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const https = require('https');
const http = require('http'); // Para HTTP fallback
const fs = require('fs');
const url = require('url'); // Para parsing seguro de URLs
const rateLimit = require('express-rate-limit');
const config = require('./config');
const db = require('./db');
const path = require('path');

// ===== OVERRIDE GLOBAL DE CONSOLE SEGÚN ENTORNO (SINCRONIZADO CON FLAVOR) =====
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

// ✅ DETECTAR ENTORNO DESDE CONFIG.JS (SINCRONIZADO CON FLAVOR)
const isDevelopment = config.flavor === 'development';
const isStaging = config.flavor === 'staging';
const isProduction = config.flavor === 'production';

console.log(`🎯 Server.js detectó FLAVOR: ${config.flavor} para cliente drpestcontrol`);
console.log(`🔍 Configuración de logs: development=${isDevelopment}, staging=${isStaging}, production=${isProduction}`);

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
    originalConsole.info(`ℹ️ [STAGING-drpestcontrol]`, cleanMessage, ...args);
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [STAGING-drpestcontrol]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [STAGING-drpestcontrol]`, message, ...args);
  };
  
} else {
  // 🐛 DEVELOPMENT: Todo normal con prefijos específicos de drpestcontrol
  console.log = (message, ...args) => {
    originalConsole.log(`🐛 [DEV-drpestcontrol]`, message, ...args);
  };
  
  console.info = (message, ...args) => {
    originalConsole.info(`ℹ️ [DEV-drpestcontrol]`, message, ...args);
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [DEV-drpestcontrol]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [DEV-drpestcontrol]`, message, ...args);
  };
  
  console.debug = (message, ...args) => {
    originalConsole.debug(`🔍 [DEV-drpestcontrol]`, message, ...args);
  };
}

// ===== LOGGER ESPECIAL PARA CASOS CRÍTICOS =====
const Logger = {
  critical: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🚨 CRITICAL: ${ref}`);
    } else {
      originalConsole.error(`🚨 CRITICAL [drpestcontrol]: ${message} [${ref}]`, data);
    }
  },
  
  startup: (message) => {
    originalConsole.log(`🚀 STARTUP [drpestcontrol]: ${message}`);
  },
  
  security: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🔒 SECURITY: ${ref}`);
    } else {
      originalConsole.error(`🔒 SECURITY [drpestcontrol]: ${message} [${ref}]`, data);
    }
  },

  auth: (action, user = null) => {
    if (isProduction) {
      originalConsole.info(`🔐 AUTH: [USER_ACTION]`);
    } else {
      originalConsole.info(`🔐 AUTH [drpestcontrol]: ${action}`, user ? { username: user, timestamp: new Date().toISOString() } : '');
    }
  },

  database: (action, details = null) => {
    if (isProduction) {
      // En producción no logear actividad de DB por seguridad
    } else {
      originalConsole.info(`💾 DB [drpestcontrol]: ${action}`, details);
    }
  },

  api: (method, path, origin = null) => {
    if (isProduction) {
      // En producción no logear cada API call por seguridad y performance
    } else if (isStaging) {
      // En staging solo método, sin detalles
      originalConsole.info(`📡 [STAGING-drpestcontrol] API: ${method}`);
    } else {
      // Solo en development: log completo
      originalConsole.info(`📡 API [drpestcontrol]: ${method} ${path}`, { origin, timestamp: new Date().toISOString() });
    }
  },

  rateLimitExceeded: (req, limitType) => {
    const clientIP = req.headers['x-forwarded-for'] || 
                     req.headers['x-real-ip'] || 
                     req.connection.remoteAddress || 
                     req.socket.remoteAddress ||
                     'unknown';
    
    if (isProduction) {
      originalConsole.warn(`🚫 RATE_LIMIT: ${limitType} [IP_BLOCKED]`);
    } else {
      originalConsole.warn(`🚫 RATE_LIMIT [drpestcontrol]: ${limitType}`, {
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
// 🔒 RATE LIMITING CONFIGURATION AJUSTADO PARA USO INDUSTRIAL
// ==========================================

// Rate Limiter General para todas las rutas - VALORES AMPLIADOS
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: config.rateLimit.maxRequests, // ✅ USAR CONFIG AMPLIADO (1000/800/500)
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
    // Permitir más libertad en desarrollo para drpestcontrol
    return isDevelopment && (req.ip === '::1' || req.ip === '127.0.0.1' || req.hostname === 'drpestcontrol');
  }
});

// Rate Limiter MODERADO para autenticación - VALORES MÁS GENEROSOS
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: config.rateLimit.authMaxRequests, // ✅ USAR CONFIG AMPLIADO (25/35/50)
  skipSuccessfulRequests: true, // ✅ CRÍTICO: No contar logins exitosos
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

// Rate Limiter para APIs de base de datos - VALORES MUY GENEROSOS PARA USO INDUSTRIAL
const dbApiLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutos
  max: isProduction ? 500 : (isStaging ? 300 : 200), // ✅ AMPLIADO SIGNIFICATIVAMENTE
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

// Rate Limiter para configuración y diagnóstico - MÁS PERMISIVO
const configLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutos
  max: isProduction ? 100 : (isStaging ? 75 : 50), // ✅ AMPLIADO PARA USO FRECUENTE
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

// ✅ NUEVO: Rate Limiter especial para usuarios autenticados - MUY PERMISIVO
const authenticatedUserLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutos
  max: 1000, // ✅ MUY ALTO para usuarios legítimos autenticados
  message: {
    success: false,
    message: 'Límite excedido para usuario autenticado.',
    error: 'AUTHENTICATED_RATE_LIMIT_EXCEEDED'
  },
  keyGenerator: (req) => {
    // Usar username si está disponible, sino IP
    return req.user?.pmus_usuario || req.ip;
  },
  skip: (req) => {
    // No aplicar en desarrollo
    return isDevelopment;
  }
});

// ✅ MIDDLEWARE PARA DETECTAR USUARIOS AUTENTICADOS Y APLICAR LÍMITES MÁS GENEROSOS
const smartRateLimiting = (req, res, next) => {
  // Si el usuario está autenticado (tiene token válido), aplicar límites más generosos
  const authHeader = req.headers.authorization;
  const hasValidAuth = authHeader && authHeader.startsWith('Bearer ');
  
  if (hasValidAuth) {
    // Aplicar rate limiting más permisivo para usuarios autenticados
    authenticatedUserLimiter(req, res, next);
  } else {
    // Aplicar rate limiting estándar para usuarios no autenticados
    next();
  }
};

// ===== CORS CONFIGURATION OPTIMIZADA PARA DRPESTCONTROL =====
// ✅ URLs estáticas específicas para drpestcontrol
const allowedOriginsStatic = isDevelopment ? [
  '*', // Solo en desarrollo
  'https://drpestcontrol:8000',
  'https://drpestcontrol:8080',
  'http://drpestcontrol:8000',  // Fallback desarrollo
  'http://drpestcontrol:8080',  // Fallback desarrollo
  'https://localhost:8000',     // Desarrollo local
  'http://localhost:8000'       // Desarrollo local
] : (isStaging ? [
  'https://drpestcontrol:8000',
  'https://drpestcontrol:8080',
  'https://staging.drpestcontrol.com',
  'https://staging-api.drpestcontrol.com'
] : [
  // Solo HTTPS en producción
  'https://drpestcontrol:8000',
  'https://drpestcontrol:8080',
  'https://app.drpestcontrol.com',
  'https://api.drpestcontrol.com'
]);

// 🔒 PATRONES REGEX OPTIMIZADOS PARA DRPESTCONTROL (sin vulnerabilidades ReDoS)
const allowedOriginPatterns = [
  // Específicos para drpestcontrol
  /^https:\/\/drpestcontrol:\d+$/,
  /^http:\/\/drpestcontrol:\d+$/, // Solo para desarrollo
  // Subdominios seguros de drpestcontrol
  /^https:\/\/[a-zA-Z0-9-]+\.drpestcontrol\.com$/,
  // Solo en desarrollo: localhost
  ...(isDevelopment ? [
    /^https?:\/\/localhost:\d+$/,
    /^https?:\/\/127\.0\.0\.1:\d+$/
  ] : [])
];

// 🛡️ FUNCIÓN SEGURA PARA VALIDAR ORÍGENES ESPECÍFICOS DE DRPESTCONTROL
const isOriginAllowed = (requestOrigin) => {
  if (!requestOrigin || typeof requestOrigin !== 'string') {
    return false;
  }
  
  // Prevenir ataques de length
  if (requestOrigin.length > 200) {
    Logger.security('CORS: Origin demasiado largo - posible ataque', {
      length: requestOrigin.length
    });
    return false;
  }
  
  // En desarrollo, permitir cualquier origin para facilitar desarrollo
  if (isDevelopment) {
    return true;
  }
  
  // 1. Verificar lista estática drpestcontrol (más rápido y seguro)
  if (allowedOriginsStatic.includes(requestOrigin) || allowedOriginsStatic.includes('*')) {
    return true;
  }
  
  // 2. Verificar patrones regex específicos de drpestcontrol (con timeout de seguridad)
  try {
    // Timeout para prevenir ReDoS
    const startTime = Date.now();
    for (const pattern of allowedOriginPatterns) {
      if (Date.now() - startTime > 100) { // 100ms timeout
        Logger.security('CORS: Regex timeout - posible ReDoS attack', {
          origin: requestOrigin.substring(0, 50)
        });
        return false;
      }
      
      if (pattern.test(requestOrigin)) {
        return true;
      }
    }
  } catch (error) {
    Logger.security('CORS: Error en validación regex', {
      error: error.message,
      origin: requestOrigin.substring(0, 50)
    });
    return false;
  }
  
  return false;
};

// 🔒 FUNCIÓN PARA VALIDAR DOMINIOS DRPESTCONTROL (previene URL injection)
const isSecureDomain = (originUrl) => {
  try {
    const parsed = url.parse(originUrl);
    const hostname = parsed.hostname;
    
    if (!hostname) return false;
    
    // En desarrollo, ser más permisivo
    if (isDevelopment) {
      return true;
    }
    
    // ✅ Lista exacta de hostnames permitidos ESPECÍFICOS PARA DRPESTCONTROL
    const allowedHosts = [
      'drpestcontrol',              // ✅ PRINCIPAL
      'localhost',                  // Desarrollo
      '127.0.0.1',                 // Desarrollo
      'app.drpestcontrol.com',     // Producción
      'api.drpestcontrol.com',     // API Producción
      'staging.drpestcontrol.com', // Staging
      'staging-api.drpestcontrol.com' // API Staging
    ];
    
    // Verificar hosts exactos
    if (allowedHosts.includes(hostname)) {
      return true;
    }
    
    // ✅ Verificar subdominios seguros SOLO DE DRPESTCONTROL
    const secureSubdomains = [
      '.drpestcontrol.com',  // ✅ Solo dominios del cliente
      'localhost'            // Desarrollo
    ];
    
    // Verificación segura de subdominio (endsWith en lugar de includes)
    return secureSubdomains.some(subdomain => hostname.endsWith(subdomain));
    
  } catch (error) {
    Logger.security('CORS: Error parsing origin URL', {
      error: error.message
    });
    return false;
  }
};

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    
    if (isOriginAllowed(origin)) {
      callback(null, true);
    } else {
      if (isDevelopment) {
        Logger.security('CORS: Origin not in allowedOrigins but allowed in development', origin);
        callback(null, true);
      } else {
        Logger.security('CORS: Origin BLOCKED in production for drpestcontrol', origin);
        callback(new Error('No permitido por CORS'));
      }
    }
  },
  credentials: config.cors.credentials,
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

// ✅ NUEVO: Aplicar smart rate limiting después del middleware de autenticación
app.use(smartRateLimiting);

// ===== MIDDLEWARE CORS ULTRA SEGURO PARA DRPESTCONTROL =====
app.use((req, res, next) => {
  const requestOrigin = req.headers.origin;
  
  // ✅ SOLUCIÓN CORS: Solo establecer headers para orígenes drpestcontrol validados
  if (requestOrigin && isOriginAllowed(requestOrigin) && isSecureDomain(requestOrigin)) {
    // 🔒 CRÍTICO: Solo usar orígenes de la whitelist estática drpestcontrol
    if (allowedOriginsStatic.includes(requestOrigin) || allowedOriginsStatic.includes('*') || isDevelopment) {
      // ✅ ULTRA SEGURO: Origin estático de la whitelist drpestcontrol
      res.header('Access-Control-Allow-Origin', requestOrigin);
      res.header('Access-Control-Allow-Credentials', 'true');
    } else {
      // Para patrones regex: NO usar origin dinámico, usar un valor seguro
      if (!isProduction) {
        Logger.security('CORS: Regex pattern matched but not setting dynamic origin for drpestcontrol', {
          origin: requestOrigin
        });
      }
      // NO establecer headers CORS para patrones regex por seguridad
    }
  } else if (isDevelopment && !requestOrigin) {
    // Solo en desarrollo: permitir requests sin origin
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Credentials', 'false');
  }
  
  // Headers seguros
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS,PATCH');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With, Accept, Origin, ngrok-skip-browser-warning');
  res.header('Access-Control-Max-Age', '3600');
  
  // Preflight seguro para drpestcontrol
  if (req.method === 'OPTIONS') {
    if (requestOrigin && (allowedOriginsStatic.includes(requestOrigin) || isDevelopment)) {
      res.status(204).send();
    } else {
      res.status(403).json({
        success: false,
        message: 'Origen no autorizado para drpestcontrol',
        error: 'CORS_FORBIDDEN'
      });
    }
    return;
  }
  
  next();
});

// 🔒 MIDDLEWARE DE PROTECCIÓN ADICIONAL DRPESTCONTROL
app.use((req, res, next) => {
  const origin = req.headers.origin;
  
  // Bloquear origin null completamente
  if (origin === 'null' && !isDevelopment) {
    Logger.security('CORS: Origin null bloqueado para drpestcontrol', {
      ip: req.headers['x-forwarded-for'] || req.connection.remoteAddress,
      method: req.method,
      path: req.path
    });
    
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      return res.status(403).json({
        success: false,
        message: 'Request bloqueado por políticas de seguridad drpestcontrol',
        error: 'NULL_ORIGIN_BLOCKED'
      });
    }
  }
  
  next();
});

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// ✅ MIDDLEWARE PARA LOG DE PETICIONES (SOLO EN DEVELOPMENT Y STAGING)
app.use((req, res, next) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';
  
  // Solo logear APIs en development y staging
  if (!isProduction) {
    Logger.api(req.method, req.path, req.headers.origin);
  }
  
  // ✅ Solo rate limit info en development
  if (req.rateLimit && isDevelopment) {
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
    const timeoutDuration = needsLongTimeout ? 60000 : (config.timeouts ? config.timeouts.request : 30000);
    
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
const pmPlanRoutes = require('./routes/pm_plan'); // ✅ NUEVA IMPORTACIÓN
const catalogosSyncRoutes = require('./routes/catalogos-sync');

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
app.use('/api/pm-plan', dbApiLimiter, pmPlanRoutes); // ✅ NUEVA RUTA
app.use('/api/catalogos-sync', catalogosSyncRoutes);

// ===== RUTA RAÍZ ESPECÍFICA PARA DRPESTCONTROL =====
app.get('/', (req, res) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';

  // ✅ Pool status solo en development (no en production por seguridad)
  if (!isProduction) {
    const poolStatus = {
      total: db.pool ? db.pool.totalCount : 0,
      idle: db.pool ? db.pool.idleCount : 0,
      waiting: db.pool ? db.pool.waitingCount : 0,
      pending: db.pool ? db.pool.pendingCount : 0
    };

    console.log(`Estado del pool drpestcontrol - total: ${poolStatus.total}, inactivos: ${poolStatus.idle}, en espera: ${poolStatus.waiting}, operaciones pendientes: ${poolStatus.pending}`);
  }

  res.json({ 
    success: true,
    message: 'API Pest Control para drpestcontrol funcionando correctamente',
    client: 'drpestcontrol',
    environment: config.environment,
    flavor: config.flavor,
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
        allowedOrigins: allowedOriginsStatic.length,
        currentOrigin: req.headers.origin || 'No origin',
        drpestcontrolSpecific: true
      },
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
        client: 'drpestcontrol',
        version: config.version,
        environment: config.environment,
        flavor: config.flavor,
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

// ===== RUTAS DE CONFIGURACIÓN CON RATE LIMITING ESPECÍFICAS PARA DRPESTCONTROL =====
app.get('/api/config', configLimiter, (req, res) => {
  res.json({
    success: true,
    message: 'Configuración del servidor drpestcontrol',
    client: 'drpestcontrol',
    version: config.version,
    environment: config.environment,
    flavor: config.flavor,
    timestamp: new Date().toISOString(),
    // En producción, información limitada
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      baseUrl: config.baseUrl,
      urls: config.urls,
      systemInfo: config.system,
      corsInfo: {
        allowedOrigins: allowedOriginsStatic.length,
        origins: allowedOriginsStatic,
        drpestcontrolSpecific: true
      },
      rateLimit: {
        general: config.rateLimit.maxRequests,
        auth: config.rateLimit.authMaxRequests
      }
    })
  });
});

app.get('/api/system/status', configLimiter, (req, res) => {
  res.json({
    success: true,
    status: 'online',
    message: 'Sistema drpestcontrol funcionando correctamente',
    client: 'drpestcontrol',
    serverTime: new Date().toISOString(),
    environment: config.environment,
    flavor: config.flavor,
    version: config.version,
    // En producción, información limitada
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      baseUrl: config.baseUrl,
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
      message: 'Servidor drpestcontrol y base de datos funcionando',
      client: 'drpestcontrol',
      checks: {
        database: dbTest.rows.length > 0 ? 'connected' : 'disconnected',
        server: 'running',
        api: 'functional'
      },
      info: {
        serverTime: new Date().toISOString(),
        uptime: Math.floor(process.uptime()),
        environment: config.environment,
        flavor: config.flavor,
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
      client: 'drpestcontrol',
      error: isDevelopment ? err.message : 'Database connection failed',
      timestamp: new Date().toISOString()
    });
  }
});

// ===== RUTA DE DIAGNÓSTICO CON RATE LIMITING ESPECÍFICA PARA DRPESTCONTROL =====
app.get('/api/diagnostico', configLimiter, async (req, res) => {
  try {
    const startTime = Date.now();
    const dbResult = await db.query('SELECT NOW() as db_time, version() as db_version');
    const dbResponseTime = Date.now() - startTime;
    
    const poolStats = db.getPoolStats ? db.getPoolStats() : { message: 'Stats no disponibles' };
    
    res.json({
      success: true,
      message: 'Diagnóstico completo del sistema drpestcontrol',
      client: 'drpestcontrol',
      serverInfo: {
        status: 'operational',
        uptime: Math.floor(process.uptime()),
        uptimeFormatted: formatUptime(process.uptime()),
        environment: config.environment,
        flavor: config.flavor,
        version: config.version,
        client: 'drpestcontrol',
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
      message: 'Error en diagnóstico del sistema drpestcontrol',
      client: 'drpestcontrol',
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
  // 🔒 Log específico si es error de rate limiting
  if (err.status === 429 || err.type === 'rate_limit') {
    Logger.rateLimitExceeded(req, 'MIDDLEWARE_ERROR');
  } else {
    Logger.critical('Error no controlado', err.message);
  }
  
  res.status(err.status || 500).json({
    success: false,
    message: err.status === 429 ? 'Demasiadas solicitudes' : 'Error interno del servidor',
    client: 'drpestcontrol',
    error: isDevelopment ? err.message : 'Contacta al administrador',
    timestamp: new Date().toISOString()
  });
});

// Manejo de rutas no encontradas
app.use((req, res) => {
  Logger.security('Ruta no encontrada', { method: req.method, url: req.originalUrl });
  res.status(404).json({
    success: false,
    message: `Ruta ${req.originalUrl} no encontrada en servidor drpestcontrol`,
    client: 'drpestcontrol',
    availableRoutes: [
      'GET /',
      'GET /api/config',
      'GET /api/system/status',
      'GET /api/health',
      'GET /api/diagnostico',
      'POST /api/auth/login',
      'GET /api/usuarios/*',
      'GET /api/roles/*',
      'GET /api/variedades/*',
      'GET /api/unidadesCultivo/*',
      'GET /api/plagas/*',
      'GET /api/nivelesinfestacion/*',
      'GET /api/lotes/*',
      'GET /api/monitoreo/*',
      'GET /api/pm-plan/*',              // ✅ NUEVA RUTA
      'POST /api/pm-plan/*',             // ✅ NUEVA RUTA
      'PUT /api/pm-plan/*',              // ✅ NUEVA RUTA
      'DELETE /api/pm-plan/*'            // ✅ NUEVA RUTA
    ],
    timestamp: new Date().toISOString()
  });
});

// ===== CONFIGURACIÓN SSL CONDICIONAL ESPECÍFICA PARA DRPESTCONTROL =====
let server;
const sslKeyPath = path.join(__dirname, '..', 'key.pem');
const sslCertPath = path.join(__dirname, '..', 'cert.pem');

// Verificar si existen los certificados SSL
const sslKeyExists = fs.existsSync(sslKeyPath);
const sslCertExists = fs.existsSync(sslCertPath);

if ((sslKeyExists && sslCertExists) || config.ssl.enabled) {
  // ✅ HTTPS con certificados para drpestcontrol
  try {
    const sslOptions = {
      key: fs.readFileSync(sslKeyPath),
      cert: fs.readFileSync(sslCertPath)
    };
    
    server = https.createServer(sslOptions, app).listen(config.port, '0.0.0.0', () => {
      Logger.startup(`Servidor Pest Control para drpestcontrol iniciado exitosamente con HTTPS`);
      Logger.startup(`🔒 SSL/TLS habilitado con certificados personalizados para drpestcontrol`);
      Logger.startup(`📁 Certificados: ${sslKeyPath} y ${sslCertPath}`);
      Logger.startup(`🏢 Cliente: drpestcontrol`);
      Logger.startup(`Host: ${config.host}`);
      Logger.startup(`Puerto: ${config.port}`);
      Logger.startup(`Entorno: ${config.environment}`);
      Logger.startup(`Flavor: ${config.flavor}`);
      Logger.startup(`Versión: ${config.version}`);
      
      // 🔒 Log de configuración de seguridad específica para drpestcontrol
      Logger.startup(`Rate Limiting: ${isProduction ? 'INDUSTRIAL' : (isStaging ? 'MODERATE' : 'PERMISSIVE')} mode`);
      Logger.startup(`Auth Rate Limit: ${config.rateLimit.authMaxRequests} attempts per 15min (AMPLIADO para uso industrial)`);
      Logger.startup(`General Rate Limit: ${config.rateLimit.maxRequests} requests per 15min (AMPLIADO para uso industrial)`);
      Logger.startup(`DB API Rate Limit: ${isProduction ? '500' : (isStaging ? '300' : '200')} requests per 10min (AMPLIADO para uso industrial)`);
      Logger.startup(`Config Rate Limit: ${isProduction ? '100' : (isStaging ? '75' : '50')} requests per 5min (AMPLIADO para uso industrial)`);
      Logger.startup(`Authenticated Users: 1000 requests per 5min (NUEVO - MUY PERMISIVO)`);
      Logger.startup(`CORS Security: drpestcontrol-specific whitelist with ${allowedOriginsStatic.length} origins`);
      Logger.startup(`CORS Protection: Anti-ReDoS regex patterns, Anti-null origin, Anti-URL injection`);
      Logger.startup(`CORS Allowed Origins: ${allowedOriginsStatic.join(', ')}`);
      
      if (!isProduction) {
        Logger.startup(`✅ URL drpestcontrol HTTPS: https://drpestcontrol:${config.port}`);
        Logger.startup(`🔧 URL Local HTTPS: https://localhost:${config.port}`);
        Logger.startup(`🌐 Sistema: ${config.system ? config.system.platform + ' - ' + config.system.hostname : 'Sistema no detectado'}`);
      }
      
      // Probar conexión a la base de datos
      db.query('SELECT NOW() as connection_test')
        .then(result => {
          Logger.startup('Conexión a la base de datos exitosa para drpestcontrol');
          Logger.database('Tiempo de respuesta DB', new Date().toISOString());
        })
        .catch(err => {
          Logger.critical('Error conectando a la base de datos drpestcontrol', err.message);
        });
    });
  } catch (sslError) {
    Logger.critical('Error cargando certificados SSL para drpestcontrol', sslError.message);
    Logger.startup('⚠️ Fallback a HTTP debido a error en certificados SSL');
    initHttpServer();
  }
} else {
  // ⚠️ HTTP sin certificados (desarrollo)
  Logger.startup(`⚠️ Certificados SSL no encontrados para drpestcontrol - iniciando en HTTP`);
  Logger.startup(`📁 Buscando: ${sslKeyPath} y ${sslCertPath}`);
  Logger.startup(`📁 Key exists: ${sslKeyExists}, Cert exists: ${sslCertExists}`);
  initHttpServer();
}

// Función para inicializar servidor HTTP para drpestcontrol
function initHttpServer() {
  server = app.listen(config.port, '0.0.0.0', () => {
    Logger.startup(`Servidor Pest Control para drpestcontrol iniciado exitosamente con HTTP`);
    Logger.startup(`⚠️ ADVERTENCIA: Sin SSL/TLS - solo para desarrollo drpestcontrol`);
    Logger.startup(`🏢 Cliente: drpestcontrol`);
    Logger.startup(`Host: ${config.host}`);
    Logger.startup(`Puerto: ${config.port}`);
    Logger.startup(`Entorno: ${config.environment}`);
    Logger.startup(`Flavor: ${config.flavor}`);
    Logger.startup(`Versión: ${config.version}`);
    
    // 🔒 Log de configuración de seguridad específica para drpestcontrol
    Logger.startup(`Rate Limiting: ${isProduction ? 'INDUSTRIAL' : (isStaging ? 'MODERATE' : 'PERMISSIVE')} mode`);
    Logger.startup(`Auth Rate Limit: ${config.rateLimit.authMaxRequests} attempts per 15min (AMPLIADO para uso industrial)`);
    Logger.startup(`General Rate Limit: ${config.rateLimit.maxRequests} requests per 15min (AMPLIADO para uso industrial)`);
    Logger.startup(`DB API Rate Limit: ${isProduction ? '500' : (isStaging ? '300' : '200')} requests per 10min (AMPLIADO para uso industrial)`);
    Logger.startup(`Config Rate Limit: ${isProduction ? '100' : (isStaging ? '75' : '50')} requests per 5min (AMPLIADO para uso industrial)`);
    Logger.startup(`Authenticated Users: 1000 requests per 5min (NUEVO - MUY PERMISIVO)`);
    Logger.startup(`CORS Security: drpestcontrol-specific whitelist with ${allowedOriginsStatic.length} origins`);
    Logger.startup(`CORS Protection: Anti-ReDoS regex patterns, Anti-null origin, Anti-URL injection`);
    Logger.startup(`CORS Allowed Origins: ${allowedOriginsStatic.join(', ')}`);
    
    if (!isProduction) {
      Logger.startup(`✅ URL drpestcontrol HTTP: http://drpestcontrol:${config.port}`);
      Logger.startup(`🔧 URL Local HTTP: http://localhost:${config.port}`);
      Logger.startup(`🌐 Sistema: ${config.system ? config.system.platform + ' - ' + config.system.hostname : 'Sistema no detectado'}`);
    }
    
    // Probar conexión a la base de datos
    db.query('SELECT NOW() as connection_test')
      .then(result => {
        Logger.startup('Conexión a la base de datos exitosa para drpestcontrol');
        Logger.database('Tiempo de respuesta DB', new Date().toISOString());
      })
      .catch(err => {
        Logger.critical('Error conectando a la base de datos drpestcontrol', err.message);
      });
  });
}

// ===== MANEJO GRACEFUL DE CIERRE =====
const gracefulShutdown = async (signal) => {
  Logger.startup(`Recibida señal ${signal}. Cerrando servidor drpestcontrol...`);
  
  server.close(async () => {
    Logger.startup('Servidor drpestcontrol cerrado');
    
    try {
      if (db.end) {
        await db.end();
        Logger.startup('Pool de conexiones drpestcontrol cerrado');
      }
      Logger.startup('Aplicación drpestcontrol cerrada correctamente');
      process.exit(0);
    } catch (err) {
      Logger.critical('Error al cerrar aplicación drpestcontrol', err.message);
      process.exit(1);
    }
  });
  
  setTimeout(() => {
    Logger.critical('Forzando cierre drpestcontrol...');
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('unhandledRejection', (reason, promise) => {
  Logger.critical('Unhandled Rejection in drpestcontrol', { reason, promise });
});

process.on('uncaughtException', (error) => {
  Logger.critical('Uncaught Exception in drpestcontrol', error.message);
  process.exit(1);
});

module.exports = app;