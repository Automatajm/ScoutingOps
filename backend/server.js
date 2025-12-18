const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const https = require('https');
const http = require('http');
const fs = require('fs');
const url = require('url');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const db = require('./db');
const path = require('path');

// ✅ Cookie-parser y jsonwebtoken
const cookieParser = require('cookie-parser');
const jwt = require('jsonwebtoken');

// ===== CONFIGURACIÓN DE TIEMPOS DE SESIÓN =====
const isProduction = config.flavor === 'production';
const isStaging = config.flavor === 'staging';
const isDevelopment = config.flavor === 'development';

// ✅ Configuración de tiempos por entorno
const SESSION_DURATION = isProduction ? '30m' : (isStaging ? '1h' : '2h');
const SESSION_MS = isProduction ? 30 * 60 * 1000 : (isStaging ? 60 * 60 * 1000 : 2 * 60 * 60 * 1000);
const RENEWAL_THRESHOLD = 15 * 60; // Renovar si quedan menos de 15 minutos

console.log(`⏱️  Sesión configurada: ${SESSION_DURATION} para entorno ${config.flavor}`);

// ===== OVERRIDE GLOBAL DE CONSOLE SEGÚN ENTORNO =====
const originalConsole = {
  log: console.log,
  info: console.info,
  warn: console.warn,
  error: console.error,
  debug: console.debug
};

const generateErrorRef = () => `REF-${Date.now()}`;

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

console.log(`🎯 Server.js detectó FLAVOR: ${config.flavor} para cliente ${config.client.name}`);
console.log(`🔍 Configuración de logs: development=${isDevelopment}, staging=${isStaging}, production=${isProduction}`);

if (isProduction) {
  console.log = () => {};
  console.info = () => {};
  console.debug = () => {};
  
  console.warn = (message, ...args) => {
    const ref = generateErrorRef();
    originalConsole.warn(`⚠️ ${ref}`);
  };
  
  console.error = (message, ...args) => {
    const ref = generateErrorRef();
    const messageStr = String(message || '');
    
    const isFrameworkError = 
      messageStr.includes('Flutter') || 
      messageStr.includes('dart:') ||
      messageStr.includes('framework') ||
      messageStr.includes('DioException') ||
      messageStr.includes('RenderFlex') ||
      messageStr.includes('rendering');
    
    const isSecurityError = 
      messageStr.toLowerCase().includes('security') ||
      messageStr.toLowerCase().includes('unauthorized') ||
      messageStr.toLowerCase().includes('forbidden') ||
      messageStr.toLowerCase().includes('cors');
    
    if (isFrameworkError) {
      const cleanMessage = sanitizeMessage(messageStr);
      originalConsole.error(`❌ FRAMEWORK: ${cleanMessage.substring(0, 100)}`);
    } else if (isSecurityError) {
      originalConsole.error(`🔒 SECURITY: ${ref}`);
    } else {
      originalConsole.error(`❌ ERROR: ${ref}`);
    }
  };
  
} else if (isStaging) {
  console.log = () => {};
  console.debug = () => {};
  
  console.info = (message, ...args) => {
    const cleanMessage = sanitizeMessage(String(message || ''));
    originalConsole.info(`ℹ️ [STAG]`, cleanMessage, ...args.slice(0, 2));
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [STAG]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [STAG]`, message, ...args);
  };
  
  console.table = function(data) {
    originalConsole.table(data);
  };
  
} else {
  const envLabel = getEnvLabel();
  
  console.log = (message, ...args) => {
    originalConsole.log(`🐛 [${envLabel}]`, message, ...args);
  };
  
  console.info = (message, ...args) => {
    originalConsole.info(`ℹ️ [${envLabel}]`, message, ...args);
  };
  
  console.warn = (message, ...args) => {
    originalConsole.warn(`⚠️ [${envLabel}]`, message, ...args);
  };
  
  console.error = (message, ...args) => {
    originalConsole.error(`❌ [${envLabel}]`, message, ...args);
  };
  
  console.debug = (message, ...args) => {
    originalConsole.debug(`🔍 [${envLabel}]`, message, ...args);
  };
}

function getEnvLabel() {
  if (isProduction) return 'PROD';
  if (isStaging) return 'STAG';
  const hostname = require('os').hostname().toLowerCase();
  if (hostname === 'localhost' || hostname === '127.0.0.1') return 'LOCAL';
  if (hostname.includes('192.168')) return 'LAN';
  if (hostname.includes('10.0.0')) return 'WIFI';
  if (hostname.includes('ngrok')) return 'NGROK';
  return 'DEV';
}

const Logger = {
  critical: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🚨 CRITICAL: ${ref}`);
    } else {
      originalConsole.error(`🚨 CRITICAL [${config.client.name}]: ${message} [${ref}]`, data);
    }
  },
  
  startup: (message) => {
    originalConsole.log(`🚀 STARTUP [${config.client.name}]: ${message}`);
  },
  
  security: (message, data = null) => {
    const ref = generateErrorRef();
    if (isProduction) {
      originalConsole.error(`🔒 SECURITY: ${ref}`);
    } else {
      originalConsole.error(`🔒 SECURITY [${config.client.name}]: ${message} [${ref}]`, data);
    }
  },

  auth: (action, user = null) => {
    if (isProduction) {
      originalConsole.info(`🔐 AUTH: [USER_ACTION]`);
    } else {
      originalConsole.info(`🔐 AUTH [${config.client.name}]: ${action}`, user ? { username: user, timestamp: new Date().toISOString() } : '');
    }
  },

  database: (action, details = null) => {
    if (isProduction) {
      // En producción no logear actividad de DB por seguridad
    } else {
      originalConsole.info(`💾 DB [${config.client.name}]: ${action}`, details);
    }
  },

  api: (method, path, origin = null) => {
    if (isProduction) {
      // En producción no logear cada API call
    } else if (isStaging) {
      originalConsole.info(`📡 [STAGING-${config.client.name}] API: ${method}`);
    } else {
      originalConsole.info(`📡 API [${config.client.name}]: ${method} ${path}`, { origin, timestamp: new Date().toISOString() });
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
      originalConsole.warn(`🚫 RATE_LIMIT [${config.client.name}]: ${limitType}`, {
        ip: clientIP,
        path: req.path,
        userAgent: req.get('User-Agent'),
        timestamp: new Date().toISOString()
      });
    }
  }
};

const app = express();

app.set('pool', db.pool);
app.set('db', db);

// ===== RATE LIMITING =====
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: config.rateLimit.maxRequests,
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
    return isDevelopment && (req.ip === '::1' || req.ip === '127.0.0.1' || req.hostname === config.client.name);
  }
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: config.rateLimit.authMaxRequests,
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

const dbApiLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: isProduction ? 500 : (isStaging ? 300 : 200),
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

const configLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: isProduction ? 100 : (isStaging ? 75 : 50),
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

const authenticatedUserLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 1000,
  message: {
    success: false,
    message: 'Límite excedido para usuario autenticado.',
    error: 'AUTHENTICATED_RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req, res) => {
    if (req.user?.pmus_usuario) {
      return `user:${req.user.pmus_usuario}`;
    }
    return undefined;
  },
  skip: (req) => {
    return isDevelopment;
  }
});

const smartRateLimiting = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const hasValidAuth = authHeader && authHeader.startsWith('Bearer ');
  
  if (hasValidAuth) {
    authenticatedUserLimiter(req, res, next);
  } else {
    next();
  }
};

// ===== CORS CONFIGURATION =====
const allowedOriginsStatic = isDevelopment ? [
  '*',
  `https://${config.client.name}:8000`,
  `https://${config.client.name}:8080`,
  `http://${config.client.name}:8000`,
  `http://${config.client.name}:8080`,
  'https://localhost:8000',
  'http://localhost:8000',
  'https://localhost:8080',
  'http://localhost:8080'
] : (isStaging ? [
  `https://${config.client.name}:8000`,
  `https://${config.client.name}:8080`,
  `https://staging.${config.client.name}.com`,
  `https://staging-api.${config.client.name}.com`
] : [
  `https://${config.client.name}:8000`,
  `https://${config.client.name}:8080`,
  `https://app.${config.client.name}.com`,
  `https://api.${config.client.name}.com`
]);

const allowedOriginPatterns = [
  /^https:\/\/drpestcontrol:\d+$/,
  /^http:\/\/drpestcontrol:\d+$/,
  /^https:\/\/[a-zA-Z0-9-]+\.drpestcontrol\.com$/,
  ...(isDevelopment ? [
    /^https?:\/\/localhost:\d+$/,
    /^https?:\/\/127\.0\.0\.1:\d+$/
  ] : [])
];

const isOriginAllowed = (requestOrigin) => {
  if (!requestOrigin || typeof requestOrigin !== 'string') {
    return false;
  }
  
  if (requestOrigin.length > 200) {
    Logger.security('CORS: Origin demasiado largo - posible ataque', {
      length: requestOrigin.length
    });
    return false;
  }
  
  if (isDevelopment) {
    return true;
  }
  
  if (allowedOriginsStatic.includes(requestOrigin) || allowedOriginsStatic.includes('*')) {
    return true;
  }
  
  try {
    const startTime = Date.now();
    for (const pattern of allowedOriginPatterns) {
      if (Date.now() - startTime > 100) {
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

const isSecureDomain = (originUrl) => {
  try {
    const parsed = url.parse(originUrl);
    const hostname = parsed.hostname;
    
    if (!hostname) return false;
    
    if (isDevelopment) {
      return true;
    }
    
    const allowedHosts = [
      config.client.name,
      'localhost',
      '127.0.0.1',
      `app.${config.client.name}.com`,
      `api.${config.client.name}.com`,
      `staging.${config.client.name}.com`,
      `staging-api.${config.client.name}.com`
    ];
    
    if (allowedHosts.includes(hostname)) {
      return true;
    }
    
    const secureSubdomains = [
      `.${config.client.name}.com`,
      'localhost'
    ];
    
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
        Logger.security(`CORS: Origin BLOCKED in production for ${config.client.name}`, origin);
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
    'Cookie',
    'ngrok-skip-browser-warning'
  ],
  exposedHeaders: ['Content-Length', 'Content-Type', 'Set-Cookie'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));

app.use(generalLimiter);
app.use(smartRateLimiting);

app.use((req, res, next) => {
  const requestOrigin = req.headers.origin;
  
  if (requestOrigin && isOriginAllowed(requestOrigin) && isSecureDomain(requestOrigin)) {
    if (allowedOriginsStatic.includes(requestOrigin) || allowedOriginsStatic.includes('*') || isDevelopment) {
      res.header('Access-Control-Allow-Origin', requestOrigin);
      res.header('Access-Control-Allow-Credentials', 'true');
    } else {
      if (!isProduction) {
        Logger.security(`CORS: Regex pattern matched but not setting dynamic origin for ${config.client.name}`, {
          origin: requestOrigin
        });
      }
    }
  } else if (isDevelopment && !requestOrigin) {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Credentials', 'false');
  }
  
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS,PATCH');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With, Accept, Origin, Cookie, ngrok-skip-browser-warning');
  res.header('Access-Control-Max-Age', '3600');
  
  if (req.method === 'OPTIONS') {
    if (requestOrigin && (allowedOriginsStatic.includes(requestOrigin) || isDevelopment)) {
      res.status(204).send();
    } else {
      res.status(403).json({
        success: false,
        message: `Origen no autorizado para ${config.client.name}`,
        error: 'CORS_FORBIDDEN'
      });
    }
    return;
  }
  
  next();
});

app.use((req, res, next) => {
  const origin = req.headers.origin;
  
  if (origin === 'null' && !isDevelopment) {
    Logger.security(`CORS: Origin null bloqueado para ${config.client.name}`, {
      ip: req.headers['x-forwarded-for'] || req.connection.remoteAddress,
      method: req.method,
      path: req.path
    });
    
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      return res.status(403).json({
        success: false,
        message: `Request bloqueado por políticas de seguridad ${config.client.name}`,
        error: 'NULL_ORIGIN_BLOCKED'
      });
    }
  }
  
  next();
});

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

app.use(cookieParser());

// ===== RENOVACIÓN AUTOMÁTICA DE SESIÓN (SLIDING EXPIRATION) =====
app.use(async (req, res, next) => {
  const token = req.cookies.auth_token;
  
  if (token) {
    try {
      const decoded = jwt.verify(token, config.security.jwtSecret || 'your-secret-key');
      const now = Math.floor(Date.now() / 1000);
      const timeRemaining = decoded.exp - now;
      
      // ✅ Si quedan menos de 15 minutos, renovar token
      if (timeRemaining > 0 && timeRemaining < RENEWAL_THRESHOLD) {
        console.log(`🔄 Renovando token - quedan ${Math.floor(timeRemaining / 60)} minutos`);
        
        const newToken = jwt.sign(
          { 
            userId: decoded.userId, 
            username: decoded.username,
            funcion: decoded.funcion 
          },
          config.security.jwtSecret || 'your-secret-key',
          { expiresIn: SESSION_DURATION }
        );
        
        const isHttps = req.protocol === 'https' || req.secure || req.get('x-forwarded-proto') === 'https';
        
        res.cookie('auth_token', newToken, {
          httpOnly: true,
          secure: isHttps,
          sameSite: 'lax',
          maxAge: SESSION_MS,
          path: '/'
        });
        
        Logger.auth('Token renovado por actividad', decoded.username);
      }
    } catch (err) {
      // Token inválido o expirado - no renovar
      if (err.name === 'TokenExpiredError') {
        console.log('⏱️  Token expirado - no renovar');
      }
    }
  }
  
  next();
});

app.use((req, res, next) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';
  
  if (!isProduction) {
    Logger.api(req.method, req.path, req.headers.origin);
  }
  
  if (req.rateLimit && isDevelopment) {
    console.debug(`Rate Limit Info: ${req.rateLimit.remaining}/${req.rateLimit.limit} remaining for ${clientIP}`);
  }
  
  next();
});

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

const requireAuth = async (req, res, next) => {
  try {
    const token = req.cookies.auth_token;
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Autenticación requerida'
      });
    }

    const decoded = jwt.verify(token, config.security.jwtSecret || 'your-secret-key');
    
    const result = await db.query(
      `SELECT pmus_id, pmus_usuario, pmus_funcion, pmus_estatus
       FROM pm_usuarios
       WHERE pmus_id = $1 AND pmus_estatus = 1`,
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      res.clearCookie('auth_token', { path: '/' });
      return res.status(401).json({
        success: false,
        message: 'Usuario no válido'
      });
    }

    req.user = result.rows[0];
    next();
    
  } catch (err) {
    Logger.security('Middleware auth falló', err.message);
    
    if (err.name === 'TokenExpiredError') {
      res.clearCookie('auth_token', { path: '/' });
      return res.status(401).json({
        success: false,
        message: 'Sesión expirada'
      });
    }
    
    if (err.name === 'JsonWebTokenError') {
      res.clearCookie('auth_token', { path: '/' });
      return res.status(401).json({
        success: false,
        message: 'Token inválido'
      });
    }
    
    res.status(401).json({
      success: false,
      message: 'Error de autenticación'
    });
  }
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
const pmPlanRoutes = require('./routes/pm_plan');
const catalogosSyncRoutes = require('./routes/catalogos-sync');

app.use((req, res, next) => {
  req.config = config;
  next();
});

app.use('/api/usuarios', dbApiLimiter, usuariosRoutes);
app.use('/api/roles', dbApiLimiter, rolesRoutes);
app.use('/api/variedades', dbApiLimiter, variedadesRoutes);
app.use('/api/unidadesCultivo', dbApiLimiter, unidadesCultivoRoutes);
app.use('/api/plagas', dbApiLimiter, plagasRoutes);
app.use('/api/nivelesinfestacion', dbApiLimiter, nivelesInfestacionRoutes);
app.use('/api/lotes', dbApiLimiter, lotesRoutes);
app.use('/api/monitoreo', dbApiLimiter, monitoreoRoutes);
app.use('/api/pm-plan', dbApiLimiter, pmPlanRoutes);
app.use('/api/catalogos-sync', catalogosSyncRoutes);

// ===== RUTA RAÍZ =====
app.get('/', (req, res) => {
  const clientIP = req.headers['x-forwarded-for'] || 
                   req.headers['x-real-ip'] || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   'unknown';

  if (!isProduction) {
    const poolStatus = {
      total: db.pool ? db.pool.totalCount : 0,
      idle: db.pool ? db.pool.idleCount : 0,
      waiting: db.pool ? db.pool.waitingCount : 0,
      pending: db.pool ? db.pool.pendingCount : 0
    };

    console.log(`Estado del pool ${config.client.name} - total: ${poolStatus.total}, inactivos: ${poolStatus.idle}, en espera: ${poolStatus.waiting}, operaciones pendientes: ${poolStatus.pending}`);
  }

  res.json({ 
    success: true,
    message: `API Pest Control para ${config.client.name} funcionando correctamente`,
    client: config.client.name,
    environment: config.environment,
    flavor: config.flavor,
    version: config.version,
    timestamp: new Date().toISOString(),
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
        specificClient: config.client.name
      },
      rateLimitInfo: req.rateLimit ? {
        remaining: req.rateLimit.remaining,
        total: req.rateLimit.limit,
        resetTime: new Date(req.rateLimit.resetTime).toISOString()
      } : null
    })
  });
});

// ===== ENDPOINT DE LOGIN CON TIEMPO REDUCIDO =====
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

    const isPasswordValid = await bcrypt.compare(password, user.pmus_password);

    if (!isPasswordValid) {
      Logger.security('Contraseña incorrecta', username);
      return res.status(401).json({
         success: false,
         message: 'Contraseña incorrecta'
       });
    }

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

    // ✅ JWT con tiempo reducido
    const token = jwt.sign(
      { 
        userId: user.pmus_id, 
        username: user.pmus_usuario,
        funcion: user.pmus_funcion 
      },
      config.security.jwtSecret || 'your-secret-key',
      { expiresIn: SESSION_DURATION }  // ✅ 30 min prod, 1h staging, 2h dev
    );

    const isHttps = req.protocol === 'https' || req.secure || req.get('x-forwarded-proto') === 'https';
    
    // ✅ Cookie con tiempo reducido
    res.cookie('auth_token', token, {
      httpOnly: true,
      secure: isHttps,
      sameSite: 'lax',
      maxAge: SESSION_MS,  // ✅ 30 min prod, 1h staging, 2h dev
      path: '/'
    });

    const { pmus_password, ...userWithoutPassword } = user;
    const userWithRoles = {
      ...userWithoutPassword,
      roles: roles
    };

    Logger.auth('Login exitoso', {
      usuario: username,
      funcion: user.pmus_funcion,
      rol: user.rol_descripcion,
      cookieSet: true,
      secure: isHttps,
      sessionDuration: SESSION_DURATION
    });

    res.json({
      success: true,
      user: userWithRoles,
      sessionDuration: SESSION_DURATION,  // ✅ Informar al frontend
      config: {
        client: config.client.name,
        version: config.version,
        environment: config.environment,
        flavor: config.flavor,
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

// ===== ENDPOINT PARA VERIFICAR SESIÓN =====
app.get('/api/auth/me', async (req, res) => {
  try {
    const token = req.cookies.auth_token;
    
    if (!token) {
      Logger.security('Auth/me: Sin cookie de autenticación');
      return res.status(401).json({
        success: false,
        message: 'No autenticado'
      });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, config.security.jwtSecret || 'your-secret-key');
    } catch (err) {
      Logger.security('Auth/me: Token inválido', err.message);
      
      res.clearCookie('auth_token', { 
        path: '/',
        httpOnly: true,
        secure: req.protocol === 'https' || req.secure,
        sameSite: 'lax'
      });
      
      return res.status(401).json({
        success: false,
        message: 'Token inválido o expirado'
      });
    }

    const result = await db.query(
      `SELECT 
          u.pmus_id, u.pmus_codigo, u.pmus_usuario,
          u.pmus_funcion, u.pmus_estatus,
          u.pmus_correo, r.pmrl_descripcion as rol_descripcion
       FROM pm_usuarios u
       LEFT JOIN pm_rol r ON u.pmus_funcion = r.pmrl_id
       WHERE u.pmus_id = $1 
         AND u.pmus_estatus = 1`,
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      Logger.security('Auth/me: Usuario no encontrado o inactivo', decoded.userId);
      
      res.clearCookie('auth_token', { 
        path: '/',
        httpOnly: true,
        secure: req.protocol === 'https' || req.secure,
        sameSite: 'lax'
      });
      
      return res.status(401).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }

    const user = result.rows[0];

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

    const userWithRoles = {
      ...user,
      roles: roles
    };

    Logger.auth('Sesión verificada', user.pmus_usuario);

    res.json({
      success: true,
      user: userWithRoles
    });
    
  } catch (err) {
    Logger.critical('Error en /auth/me', err.message);
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: isDevelopment ? err.message : 'Error interno'
    });
  }
});

// ===== ENDPOINT DE LOGOUT CORREGIDO =====
app.post('/api/auth/logout', (req, res) => {
  try {
    const token = req.cookies.auth_token;
    
    if (token) {
      Logger.auth('Logout - Cookie encontrada');
    } else {
      Logger.auth('Logout - Sin cookie');
    }
    
    // ✅ CRÍTICO: Opciones deben coincidir con las del login
    const isHttps = req.protocol === 'https' || req.secure || req.get('x-forwarded-proto') === 'https';
    
    res.clearCookie('auth_token', {
      path: '/',
      httpOnly: true,
      secure: isHttps,
      sameSite: 'lax'
    });

    Logger.auth('Logout exitoso - Cookie borrada');

    res.json({
      success: true,
      message: 'Sesión cerrada exitosamente'
    });
  } catch (err) {
    Logger.critical('Error en logout', err.message);
    res.status(500).json({
      success: false,
      message: 'Error al cerrar sesión',
      error: isDevelopment ? err.message : 'Error interno'
    });
  }
});

// ===== OTRAS RUTAS =====
app.get('/api/config', configLimiter, (req, res) => {
  res.json({
    success: true,
    message: `Configuración del servidor ${config.client.name}`,
    client: config.client.name,
    version: config.version,
    environment: config.environment,
    flavor: config.flavor,
    timestamp: new Date().toISOString(),
    ...(isProduction ? {} : {
      apiUrl: config.apiUrl,
      baseUrl: config.baseUrl,
      urls: config.urls,
      systemInfo: config.system,
      corsInfo: {
        allowedOrigins: allowedOriginsStatic.length,
        origins: allowedOriginsStatic,
        specificClient: config.client.name
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
    message: `Sistema ${config.client.name} funcionando correctamente`,
    client: config.client.name,
    serverTime: new Date().toISOString(),
    environment: config.environment,
    flavor: config.flavor,
    version: config.version,
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
      message: `Servidor ${config.client.name} y base de datos funcionando`,
      client: config.client.name,
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
      client: config.client.name,
      error: isDevelopment ? err.message : 'Database connection failed',
      timestamp: new Date().toISOString()
    });
  }
});

app.get('/api/diagnostico', configLimiter, async (req, res) => {
  try {
    const startTime = Date.now();
    const dbResult = await db.query('SELECT NOW() as db_time, version() as db_version');
    const dbResponseTime = Date.now() - startTime;
    
    const poolStats = db.getPoolStats ? db.getPoolStats() : { message: 'Stats no disponibles' };
    
    res.json({
      success: true,
      message: `Diagnóstico completo del sistema ${config.client.name}`,
      client: config.client.name,
      serverInfo: {
        status: 'operational',
        uptime: Math.floor(process.uptime()),
        uptimeFormatted: formatUptime(process.uptime()),
        environment: config.environment,
        flavor: config.flavor,
        version: config.version,
        client: config.client.name,
        ...(isProduction ? {} : {
          memoryUsage: process.memoryUsage(),
          nodeVersion: process.version,
          platform: process.platform
        })
      },
      databaseInfo: {
        status: 'connected',
        responseTimeMs: dbResponseTime,
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
      message: `Error en diagnóstico del sistema ${config.client.name}`,
      client: config.client.name,
      error: isDevelopment ? err.message : 'Error interno',
      timestamp: new Date().toISOString()
    });
  }
});

function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  return `${days}d ${hours}h ${minutes}m ${secs}s`;
}

app.use((err, req, res, next) => {
  if (err.status === 429 || err.type === 'rate_limit') {
    Logger.rateLimitExceeded(req, 'MIDDLEWARE_ERROR');
  } else {
    Logger.critical('Error no controlado', err.message);
  }
  
  res.status(err.status || 500).json({
    success: false,
    message: err.status === 429 ? 'Demasiadas solicitudes' : 'Error interno del servidor',
    client: config.client.name,
    error: isDevelopment ? err.message : 'Contacta al administrador',
    timestamp: new Date().toISOString()
  });
});

app.use((req, res) => {
  Logger.security('Ruta no encontrada', { method: req.method, url: req.originalUrl });
  res.status(404).json({
    success: false,
    message: `Ruta ${req.originalUrl} no encontrada en servidor ${config.client.name}`,
    client: config.client.name,
    availableRoutes: [
      'GET /',
      'GET /api/config',
      'GET /api/system/status',
      'GET /api/health',
      'GET /api/diagnostico',
      'POST /api/auth/login',
      'GET /api/auth/me',
      'POST /api/auth/logout',
      'GET /api/usuarios/*',
      'GET /api/roles/*',
      'GET /api/variedades/*',
      'GET /api/unidadesCultivo/*',
      'GET /api/plagas/*',
      'GET /api/nivelesinfestacion/*',
      'GET /api/lotes/*',
      'GET /api/monitoreo/*',
      'GET /api/pm-plan/*'
    ],
    timestamp: new Date().toISOString()
  });
});

// ===== CONFIGURACIÓN SSL =====
let server;
const sslKeyPath = path.join(__dirname, '..', 'key.pem');
const sslCertPath = path.join(__dirname, '..', 'cert.pem');

const sslKeyExists = fs.existsSync(sslKeyPath);
const sslCertExists = fs.existsSync(sslCertPath);

if ((sslKeyExists && sslCertExists) || config.ssl.enabled) {
  try {
    const sslOptions = {
      key: fs.readFileSync(sslKeyPath),
      cert: fs.readFileSync(sslCertPath)
    };
    
    server = https.createServer(sslOptions, app).listen(config.port, '0.0.0.0', () => {
      Logger.startup(`Servidor Pest Control para ${config.client.name} iniciado exitosamente con HTTPS`);
      Logger.startup(`🔒 SSL/TLS habilitado con certificados personalizados para ${config.client.name}`);
      Logger.startup(`📁 Certificados: ${sslKeyPath} y ${sslCertPath}`);
      Logger.startup(`🏢 Cliente: ${config.client.name}`);
      Logger.startup(`Host: ${config.host}`);
      Logger.startup(`Puerto: ${config.port}`);
      Logger.startup(`Entorno: ${config.environment}`);
      Logger.startup(`Flavor: ${config.flavor}`);
      Logger.startup(`Versión: ${config.version}`);
      Logger.startup(`⏱️  Sesión: ${SESSION_DURATION} (renovación automática activada)`);
      Logger.startup(`✅ HttpOnly Cookies: HABILITADO (secure=true)`);
      Logger.startup(`✅ CORS Credentials: HABILITADO`);
      Logger.startup(`✅ JWT Auth: HABILITADO`);
      Logger.startup(`✅ Sliding Expiration: HABILITADO (renueva cada 15 min)`);
      
      Logger.startup(`Rate Limiting: ${isProduction ? 'INDUSTRIAL' : (isStaging ? 'MODERATE' : 'PERMISSIVE')} mode`);
      Logger.startup(`Auth Rate Limit: ${config.rateLimit.authMaxRequests} attempts per 15min`);
      Logger.startup(`CORS Allowed Origins: ${allowedOriginsStatic.length} origins`);
      
      if (!isProduction) {
        Logger.startup(`✅ URL HTTPS: https://${config.client.name}:${config.port}`);
        Logger.startup(`🔧 URL Local HTTPS: https://localhost:${config.port}`);
      }
      
      db.query('SELECT NOW() as connection_test')
        .then(result => {
          Logger.startup(`Conexión a la base de datos exitosa para ${config.client.name}`);
        })
        .catch(err => {
          Logger.critical(`Error conectando a la base de datos ${config.client.name}`, err.message);
        });
    });
  } catch (sslError) {
    Logger.critical(`Error cargando certificados SSL para ${config.client.name}`, sslError.message);
    Logger.startup('⚠️ Fallback a HTTP debido a error en certificados SSL');
    initHttpServer();
  }
} else {
  Logger.startup(`⚠️ Certificados SSL no encontrados para ${config.client.name} - iniciando en HTTP`);
  initHttpServer();
}

function initHttpServer() {
  server = app.listen(config.port, '0.0.0.0', () => {
    Logger.startup(`Servidor Pest Control para ${config.client.name} iniciado exitosamente con HTTP`);
    Logger.startup(`⚠️ ADVERTENCIA: Sin SSL/TLS - solo para desarrollo ${config.client.name}`);
    Logger.startup(`🏢 Cliente: ${config.client.name}`);
    Logger.startup(`Host: ${config.host}`);
    Logger.startup(`Puerto: ${config.port}`);
    Logger.startup(`Entorno: ${config.environment}`);
    Logger.startup(`Flavor: ${config.flavor}`);
    Logger.startup(`Versión: ${config.version}`);
    Logger.startup(`⏱️  Sesión: ${SESSION_DURATION} (renovación automática activada)`);
    Logger.startup(`✅ HttpOnly Cookies: HABILITADO (secure=false para HTTP)`);
    Logger.startup(`✅ CORS Credentials: HABILITADO`);
    Logger.startup(`✅ JWT Auth: HABILITADO`);
    Logger.startup(`✅ Sliding Expiration: HABILITADO (renueva cada 15 min)`);
    
    if (!isProduction) {
      Logger.startup(`✅ URL HTTP: http://${config.client.name}:${config.port}`);
      Logger.startup(`🔧 URL Local HTTP: http://localhost:${config.port}`);
    }
    
    db.query('SELECT NOW() as connection_test')
      .then(result => {
        Logger.startup(`Conexión a la base de datos exitosa para ${config.client.name}`);
      })
      .catch(err => {
        Logger.critical(`Error conectando a la base de datos ${config.client.name}`, err.message);
      });
  });
}

const gracefulShutdown = async (signal) => {
  Logger.startup(`Recibida señal ${signal}. Cerrando servidor ${config.client.name}...`);
  
  server.close(async () => {
    Logger.startup(`Servidor ${config.client.name} cerrado`);
    
    try {
      if (db.end) {
        await db.end();
        Logger.startup(`Pool de conexiones ${config.client.name} cerrado`);
      }
      Logger.startup(`Aplicación ${config.client.name} cerrada correctamente`);
      process.exit(0);
    } catch (err) {
      Logger.critical(`Error al cerrar aplicación ${config.client.name}`, err.message);
      process.exit(1);
    }
  });
  
  setTimeout(() => {
    Logger.critical(`Forzando cierre ${config.client.name}...`);
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('unhandledRejection', (reason, promise) => {
  Logger.critical(`Unhandled Rejection in ${config.client.name}`, { reason, promise });
});

process.on('uncaughtException', (error) => {
  Logger.critical(`Uncaught Exception in ${config.client.name}`, error.message);
  process.exit(1);
});

module.exports = app;