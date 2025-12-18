// =====================================================
// config.js - REFACTORIZADO SIN HARDCODING
// =====================================================
// Este archivo ahora delega toda la configuración a /config/
// Mantiene la misma interfaz para compatibilidad con código existente

const config = require('./config/');

// Re-exportar toda la configuración
module.exports = config;