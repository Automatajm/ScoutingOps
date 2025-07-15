/**
 * PEST CONTROL - PUENTE WEB-FLUTTER HÍBRIDO
 * Detecta automáticamente la IP y la pasa al ConfigurationScreen existente
 * ========================================================================
 */

class NetworkBridge {
  constructor() {
    this.detectedConfig = null;
    this.detectionCompleted = false;
    this.listeners = [];
  }

  /**
   * Detecta automáticamente las IPs disponibles usando WebRTC
   */
  async detectLocalIPs() {
    return new Promise((resolve) => {
      const ips = [];
      
      try {
        const rtc = new RTCPeerConnection({
          iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
        });

        rtc.createDataChannel('');
        
        rtc.onicecandidate = (event) => {
          if (event.candidate) {
            const candidate = event.candidate.candidate;
            const ipMatch = candidate.match(/(\d+\.\d+\.\d+\.\d+)/);
            
            if (ipMatch && ipMatch[1]) {
              const ip = ipMatch[1];
              if (this.isValidLocalIP(ip) && !ips.includes(ip)) {
                ips.push(ip);
                console.log(`🔍 IP detectada: ${ip}`);
              }
            }
          }
        };

        rtc.createOffer()
          .then(offer => rtc.setLocalDescription(offer))
          .catch(() => {});

        // Resolver después de 2 segundos
        setTimeout(() => {
          rtc.close();
          
          // Ordenar IPs por prioridad (redes privadas primero)
          ips.sort((a, b) => {
            // Priorizar 10.x.x.x sobre 192.168.x.x
            if (a.startsWith('10.') && !b.startsWith('10.')) return -1;
            if (!a.startsWith('10.') && b.startsWith('10.')) return 1;
            return 0;
          });
          
          // Agregar fallbacks si no se detectó nada
          if (ips.length === 0) {
            ips.push('localhost', '127.0.0.1');
          }
          
          resolve(ips);
        }, 2000);
      } catch (error) {
        console.warn('Error en detección WebRTC:', error);
        resolve(['localhost', '127.0.0.1']);
      }
    });
  }

  /**
   * Valida si una IP es una IP local válida
   */
  isValidLocalIP(ip) {
    const privateRanges = [
      /^10\./,                    // 10.0.0.0/8
      /^172\.(1[6-9]|2[0-9]|3[0-1])\./, // 172.16.0.0/12
      /^192\.168\./               // 192.168.0.0/16
    ];

    return privateRanges.some(range => range.test(ip)) && 
           ip !== '127.0.0.1' && 
           ip !== '0.0.0.0';
  }

  /**
   * Prueba conectividad con una IP específica
   */
  async testConnection(ip, port = 8000) {
    const protocols = ['https', 'http']; // HTTPS prioritario
    
    for (const protocol of protocols) {
      const url = `${protocol}://${ip}:${port}`;
      
      try {
        console.log(`🔄 Probando ${url}/health...`);
        
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 3000);
        
        const response = await fetch(`${url}/health`, {
          method: 'GET',
          signal: controller.signal,
          headers: {
            'Content-Type': 'application/json',
          }
        });
        
        clearTimeout(timeoutId);
        
        if (response.ok) {
          console.log(`✅ Conexión exitosa: ${url}`);
          return { ip, port, protocol, success: true, url };
        }
      } catch (error) {
        // Silencioso - esperamos algunos errores
      }
    }
    
    return { ip, port, success: false };
  }

  /**
   * Encuentra la mejor IP disponible
   */
  async findBestIP() {
    console.log('🚀 Iniciando detección automática para ConfigurationScreen...');
    
    const ips = await this.detectLocalIPs();
    console.log(`📊 IPs detectadas: ${ips.join(', ')}`);
    
    // Probar todas las IPs detectadas
    for (const ip of ips) {
      const result = await this.testConnection(ip);
      if (result.success) {
        return result;
      }
    }
    
    console.log('⚠️ No se encontró backend activo');
    return null;
  }

  /**
   * Genera configuración para Flutter
   */
  generateFlutterConfig(detectedResult) {
    const config = {
      timestamp: Date.now(),
      detected: !!detectedResult,
    };

    if (detectedResult) {
      config.recommendedUrl = detectedResult.url;
      config.detectedIP = detectedResult.ip;
      config.detectedProtocol = detectedResult.protocol;
      config.detectedPort = detectedResult.port;
      
      // Generar URLs sugeridas inteligentes
      config.suggestedUrls = this.generateSuggestedUrls(detectedResult.ip);
    } else {
      // Configuración de fallback
      config.recommendedUrl = 'https://localhost:8000';
      config.detectedIP = 'localhost';
      config.detectedProtocol = 'https';
      config.detectedPort = 8000;
      config.suggestedUrls = [
        'https://localhost:8000',
        'https://127.0.0.1:8000',
        'http://localhost:8000',
        'http://127.0.0.1:8000'
      ];
    }

    return config;
  }

  /**
   * Genera URLs sugeridas basadas en la IP detectada
   */
  generateSuggestedUrls(detectedIP) {
    const suggestions = [];
    
    // URL detectada con ambos protocolos
    suggestions.push(`https://${detectedIP}:8000`);
    suggestions.push(`http://${detectedIP}:8000`);
    
    // URLs comunes
    suggestions.push('https://localhost:8000');
    suggestions.push('http://localhost:8000');
    suggestions.push('https://127.0.0.1:8000');
    
    // Si la IP detectada es de una red específica, agregar otras IPs comunes de esa red
    if (detectedIP.startsWith('192.168.')) {
      const baseNetwork = detectedIP.substring(0, detectedIP.lastIndexOf('.'));
      suggestions.push(`https://${baseNetwork}.1:8000`);
      suggestions.push(`https://${baseNetwork}.100:8000`);
    } else if (detectedIP.startsWith('10.')) {
      suggestions.push('https://10.0.0.1:8000');
      suggestions.push('https://10.0.0.100:8000');
    }
    
    // Servicios externos
    suggestions.push('https://xxx.ngrok-free.app');
    suggestions.push('https://xxx.ngrok.io');
    suggestions.push('https://xxx.loca.lt');
    
    // Remover duplicados y retornar
    return [...new Set(suggestions)];
  }

  /**
   * Notifica a Flutter sobre la configuración detectada
   */
  notifyFlutter(config) {
    // Guardar en window para acceso desde Flutter
    window.flutterNetworkConfig = config;
    
    // Notificar a todos los listeners
    this.listeners.forEach(callback => {
      try {
        callback(config);
      } catch (error) {
        console.warn('Error notificando listener:', error);
      }
    });
    
    // Disparar evento personalizado
    window.dispatchEvent(new CustomEvent('networkConfigReady', {
      detail: config
    }));
    
    console.log('✅ Configuración disponible para Flutter:', config);
  }

  /**
   * Permite a Flutter suscribirse a actualizaciones
   */
  onConfigReady(callback) {
    if (this.detectionCompleted && this.detectedConfig) {
      // Si ya tenemos configuración, llamar inmediatamente
      callback(this.detectedConfig);
    } else {
      // Agregar a la lista de espera
      this.listeners.push(callback);
    }
  }

  /**
   * Inicialización principal
   */
  async initialize() {
    try {
      console.log('🌐 NetworkBridge: Iniciando detección para ConfigurationScreen...');
      
      const detectedResult = await this.findBestIP();
      const config = this.generateFlutterConfig(detectedResult);
      
      // Marcar como completado
      this.detectionCompleted = true;
      this.detectedConfig = config;
      
      // Notificar a Flutter
      this.notifyFlutter(config);
      
      console.log('✅ NetworkBridge: Detección completada');
      return config;
      
    } catch (error) {
      console.error('❌ NetworkBridge: Error en detección:', error);
      
      // Configuración de emergencia
      const fallbackConfig = this.generateFlutterConfig(null);
      this.detectionCompleted = true;
      this.detectedConfig = fallbackConfig;
      this.notifyFlutter(fallbackConfig);
      
      return fallbackConfig;
    }
  }
}

// ========================================================================
// INICIALIZACIÓN AUTOMÁTICA
// ========================================================================

// Crear instancia global
window.networkBridge = new NetworkBridge();

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', async function() {
  console.log('🔗 NetworkBridge: Iniciando...');
  await window.networkBridge.initialize();
});

// ========================================================================
// API PARA FLUTTER
// ========================================================================

/**
 * Función para que Flutter obtenga la configuración detectada
 */
window.getFlutterNetworkConfig = function() {
  return window.flutterNetworkConfig || null;
};

/**
 * Función para que Flutter se suscriba a actualizaciones
 */
window.onFlutterNetworkConfigReady = function(callback) {
  window.networkBridge.onConfigReady(callback);
};

/**
 * Función para re-detectar la red (para botón de refresh en Flutter)
 */
window.redetectNetworkForFlutter = async function() {
  console.log('🔄 Re-detectando red por solicitud de Flutter...');
  return await window.networkBridge.initialize();
};

/**
 * Función para testing manual desde Flutter
 */
window.testNetworkConnection = async function(ip, port = 8000) {
  console.log(`🧪 Probando conexión manual: ${ip}:${port}`);
  return await window.networkBridge.testConnection(ip, port);
};

// ========================================================================
// EVENTOS Y DEBUGGING
// ========================================================================

// Logging para debugging
window.showNetworkBridgeInfo = function() {
  console.log('📊 NETWORK BRIDGE INFO:');
  console.log('- Estado:', window.networkBridge.detectionCompleted ? 'Completado' : 'En progreso');
  console.log('- Configuración:', window.networkBridge.detectedConfig);
  console.log('- Listeners:', window.networkBridge.listeners.length);
  console.log('- Config disponible para Flutter:', window.flutterNetworkConfig);
};

// Exportar para uso en módulos
if (typeof module !== 'undefined' && module.exports) {
  module.exports = NetworkBridge;
}