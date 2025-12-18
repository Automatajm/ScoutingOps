// ===== BARCODE SCANNER CON OCR MEJORADO - CAPTURA INSTANTÁNEA =====
// Tesseract.js OCR para leer etiquetas como "L 000016004" 
// Captura instantánea + Solo número útil

let barcodeScanner = {
  isActive: false,
  videoStream: null,
  overlay: null,
  callback: null,
  worker: null,
  isProcessing: false,
  capturedImage: null
};

// ✅ CONFIGURAR CALLBACK DE FLUTTER
window.setBarcodeCallback = function(callback) {
  console.log('✅ Callback de Flutter registrado');
  barcodeScanner.callback = callback;
};

// ✅ INICIAR ESCÁNER OCR DIRECTO
window.startWebBarcodeScanner = function() {
  console.log('🚀 Iniciando escáner OCR mejorado...');
  
  if (barcodeScanner.isActive) {
    console.log('⚠️ Escáner ya activo, cerrando anterior...');
    cleanupBarcodeScanner();
  }

  createScannerUI();
  startCamera();
};

// ✅ CREAR INTERFAZ DE ESCÁNER MEJORADA
function createScannerUI() {
  barcodeScanner.overlay = document.createElement('div');
  barcodeScanner.overlay.className = 'modal-overlay';
  barcodeScanner.overlay.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.9);
    z-index: 20000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
    box-sizing: border-box;
  `;
  
  barcodeScanner.overlay.innerHTML = `
    <div style="
      background: white;
      border-radius: 16px;
      padding: 20px;
      max-width: 500px;
      width: 100%;
      max-height: 90vh;
      overflow-y: auto;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
      margin: auto;
    ">
      <!-- Header -->
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h3 style="margin: 0; color: #333; font-size: 18px;">📷 Escáner de Códigos</h3>
        <button onclick="cleanupBarcodeScanner()" style="
          background: #f44336;
          color: white;
          border: none;
          border-radius: 50%;
          width: 32px;
          height: 32px;
          cursor: pointer;
          font-size: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
        ">✕</button>
      </div>
      
      <!-- Video container -->
      <div style="position: relative; background: #000; border-radius: 12px; overflow: hidden; margin-bottom: 20px;">
        <video id="scannerVideo" style="width: 100%; height: 300px; object-fit: cover; border-radius: 12px;"></video>
        
        <!-- Guía de escaneo -->
        <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                    width: 80%; height: 100px; border: 3px solid #4CAF50; border-radius: 8px;
                    display: flex; align-items: center; justify-content: center;">
          <span style="background: rgba(0,0,0,0.7); color: white; padding: 5px 10px; border-radius: 15px; font-size: 12px;">
            Posicione la etiqueta aquí
          </span>
        </div>
        
        <!-- Estado -->
        <div id="scannerStatus" style="position: absolute; top: 10px; left: 10px; right: 10px;
                                      background: rgba(0,0,0,0.8); color: white; padding: 8px 12px; 
                                      border-radius: 15px; text-align: center; font-size: 14px;">
          🔍 Iniciando cámara...
        </div>
        
        <!-- Flash para indicar captura -->
        <div id="captureFlash" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                                     background: white; opacity: 0; pointer-events: none;
                                     border-radius: 12px; transition: opacity 0.1s;"></div>
      </div>
      
      <!-- Controles mejorados -->
      <div style="display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; margin-bottom: 15px;">
        <button onclick="captureAndProcess()" id="captureBtn" style="
          background: #4CAF50;
          color: white;
          border: none;
          border-radius: 25px;
          padding: 12px 20px;
          cursor: pointer;
          font-weight: bold;
          font-size: 14px;
        ">📸 Capturar y Leer</button>
        
        <button onclick="showManualEntry()" style="
          background: #2196F3;
          color: white;
          border: none;
          border-radius: 25px;
          padding: 12px 20px;
          cursor: pointer;
          font-size: 14px;
        ">⌨️ Entrada Manual</button>
        
        <button onclick="cleanupBarcodeScanner()" style="
          background: #666;
          color: white;
          border: none;
          border-radius: 25px;
          padding: 12px 20px;
          cursor: pointer;
          font-size: 14px;
        ">❌ Cancelar</button>
      </div>
      
      <!-- Resultado detectado -->
      <div id="detectedResult" style="margin-bottom: 15px; text-align: center;"></div>
      
      <!-- Info mejorada -->
      <div style="padding: 15px; background: #e3f2fd; border-radius: 12px; text-align: center;">
        <small style="color: #1976d2; line-height: 1.4;">
          💡 <strong>Paso 1:</strong> Posicione la etiqueta en el marco verde<br>
          📸 <strong>Paso 2:</strong> Presione "Capturar y Leer" para tomar la foto<br>
          🎯 <strong>Paso 3:</strong> El sistema procesará automáticamente
        </small>
      </div>
    </div>
  `;
  
  document.body.appendChild(barcodeScanner.overlay);
  barcodeScanner.isActive = true;
}

// ✅ INICIAR CÁMARA
async function startCamera() {
  try {
    updateStatus('📷 Solicitando acceso a cámara...');
    
    const stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: 'environment', // Cámara trasera preferida
        width: { ideal: 1280 },
        height: { ideal: 720 }
      }
    });
    
    barcodeScanner.videoStream = stream;
    const video = document.getElementById('scannerVideo');
    
    if (video) {
      video.srcObject = stream;
      await video.play();
      
      updateStatus('✅ Cámara lista - Presione "Capturar y Leer"');
      console.log('✅ Cámara iniciada correctamente');
    }
    
  } catch (error) {
    console.error('❌ Error acceso cámara:', error);
    updateStatus('❌ Error: No se pudo acceder a la cámara');
    
    setTimeout(() => {
      showManualEntry();
    }, 2000);
  }
}

// ✅ CAPTURAR IMAGEN INSTANTÁNEA Y PROCESAR
async function captureAndProcess() {
  if (barcodeScanner.isProcessing) {
    console.log('⚠️ Ya procesando, ignorando...');
    return;
  }
  
  const video = document.getElementById('scannerVideo');
  if (!video || video.videoWidth === 0) {
    console.log('❌ Video no disponible');
    updateStatus('❌ Cámara no disponible');
    return;
  }
  
  // Deshabilitar botón durante procesamiento
  const captureBtn = document.getElementById('captureBtn');
  if (captureBtn) {
    captureBtn.disabled = true;
    captureBtn.textContent = '⏳ Procesando...';
  }
  
  barcodeScanner.isProcessing = true;
  
  try {
    // ✅ PASO 1: CAPTURA INSTANTÁNEA CON EFECTO FLASH
    updateStatus('📸 Capturando imagen...');
    
    // Efecto flash para indicar captura
    const flash = document.getElementById('captureFlash');
    if (flash) {
      flash.style.opacity = '0.8';
      setTimeout(() => {
        flash.style.opacity = '0';
      }, 150);
    }
    
    // Crear canvas y capturar imagen INMEDIATAMENTE
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0);
    
    // Guardar imagen capturada
    barcodeScanner.capturedImage = canvas;
    
    console.log('✅ Imagen capturada exitosamente');
    
    // ✅ PASO 2: PROCESAR LA IMAGEN CAPTURADA
    updateStatus('🤖 Analizando imagen con OCR...');
    
    // Mejorar imagen para OCR
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    enhanceImageForOCR(ctx, imageData);
    
    // Procesar con Tesseract OCR
    const result = await Tesseract.recognize(canvas, 'eng', {
      logger: m => {
        if (m.status === 'recognizing text') {
          updateStatus(`🔍 Procesando: ${Math.round(m.progress * 100)}%`);
        }
      }
    });
    
    console.log('📝 Texto OCR detectado:', result.data.text);
    
    // ✅ PASO 3: EXTRAER SOLO EL NÚMERO ÚTIL
    const finalNumber = extractUsefulNumber(result.data.text);
    
    if (finalNumber) {
      console.log('🎯 Número útil encontrado:', finalNumber);
      showDetectedResult(finalNumber);
    } else {
      updateStatus('⚠️ No se detectó un código válido');
      showRetryOptions();
    }
    
  } catch (error) {
    console.error('❌ Error en procesamiento:', error);
    updateStatus('❌ Error en análisis');
    showRetryOptions();
  } finally {
    // Rehabilitar botón
    if (captureBtn) {
      captureBtn.disabled = false;
      captureBtn.textContent = '📸 Capturar y Leer';
    }
    barcodeScanner.isProcessing = false;
  }
}

// ✅ MEJORAR IMAGEN PARA OCR
function enhanceImageForOCR(ctx, imageData) {
  const data = imageData.data;
  
  // Aumentar contraste y brillo para mejor reconocimiento
  for (let i = 0; i < data.length; i += 4) {
    // Convertir a escala de grises
    const gray = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
    
    // Aplicar umbralización para texto más claro
    const enhanced = gray > 120 ? 255 : 0;
    
    data[i] = enhanced;     // R
    data[i + 1] = enhanced; // G
    data[i + 2] = enhanced; // B
  }
  
  ctx.putImageData(imageData, 0, 0);
}

// ✅ EXTRAER SOLO EL NÚMERO ÚTIL (SIN CEROS INICIALES)
function extractUsefulNumber(text) {
  console.log('🔍 Analizando texto OCR:', text);
  
  // Buscar patrones específicos para etiquetas
  const patterns = [
    /L\s*(\d{9})/gi,           // "L 000016004"
    /(\d{9})/g,                // "000016004" directo
    /[^\d](\d{6,12})[^\d]/g,   // Números de 6-12 dígitos rodeados
    /^(\d{6,12})$/gm,          // Números solos en línea
  ];
  
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const number = match[1] || match[0];
      const cleaned = number.replace(/\D/g, ''); // Solo dígitos
      
      if (cleaned.length >= 6 && cleaned.length <= 12) {
        // ✅ PROCESAR: REMOVER CEROS INICIALES Y DEVOLVER SOLO EL ÚTIL
        const usefulNumber = cleaned.replace(/^0+/, '') || '0';
        
        // Validar que no sea un patrón obvio
        if (isValidLoteNumber(usefulNumber)) {
          console.log(`✅ Número útil procesado: ${cleaned} → ${usefulNumber}`);
          return usefulNumber;
        }
      }
    }
  }
  
  return null;
}

// ✅ VALIDAR QUE SEA UN NÚMERO DE LOTE VÁLIDO
function isValidLoteNumber(number) {
  // Rechazar patrones obvios
  const invalidPatterns = [
    /^(123|111|000|999)+$/,    // Patrones repetitivos
    /^12345/,                  // Secuencias obvias
    /^(\d)\1{4,}$/,           // Mismo dígito repetido
  ];
  
  return !invalidPatterns.some(pattern => pattern.test(number)) && number.length >= 3;
}

// ✅ MOSTRAR RESULTADO DETECTADO - SOLO EL NÚMERO ÚTIL
function showDetectedResult(number) {
  const container = document.getElementById('detectedResult');
  if (!container) return;
  
  updateStatus('🎯 ¡Código detectado exitosamente!');
  
  container.innerHTML = `
    <div style="background: #e8f5e8; padding: 20px; border-radius: 12px; border: 2px solid #4caf50;">
      <div style="margin-bottom: 15px;">
        <strong style="color: #2e7d32; font-size: 16px;">✅ Código detectado:</strong>
      </div>
      
      <div style="background: white; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
        <div style="font-size: 24px; font-weight: bold; color: #1976d2; text-align: center;">
          ${number}
        </div>
      </div>
      
      <div style="display: flex; gap: 10px; justify-content: center;">
        <button onclick="sendToFlutter('${number}')" 
                class="scanner-button btn-success" 
                style="padding: 12px 24px; font-size: 16px; font-weight: bold;">
          ✅ Usar este código
        </button>
        <button onclick="retryCapture()" 
                class="scanner-button btn-secondary" 
                style="padding: 12px 20px;">
          🔄 Capturar otra vez
        </button>
      </div>
    </div>
  `;
}

// ✅ MOSTRAR OPCIONES DE REINTENTO
function showRetryOptions() {
  const container = document.getElementById('detectedResult');
  if (!container) return;
  
  container.innerHTML = `
    <div style="background: #fff3cd; padding: 20px; border-radius: 12px; border: 2px solid #ffc107;">
      <div style="margin-bottom: 15px;">
        <strong style="color: #856404; font-size: 16px;">⚠️ No se detectó código</strong>
      </div>
      
      <div style="margin-bottom: 15px; color: #856404;">
        Asegúrese de que la etiqueta esté bien iluminada y enfocada
      </div>
      
      <div style="display: flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
        <button onclick="retryCapture()" 
                class="scanner-button btn-success" 
                style="padding: 10px 20px;">
          📸 Intentar otra vez
        </button>
        <button onclick="showManualEntry()" 
                class="scanner-button btn-manual" 
                style="padding: 10px 20px;">
          ⌨️ Entrada manual
        </button>
      </div>
    </div>
  `;
}

// ✅ REINTENTAR CAPTURA
function retryCapture() {
  const container = document.getElementById('detectedResult');
  if (container) {
    container.innerHTML = '';
  }
  updateStatus('✅ Cámara lista - Presione "Capturar y Leer"');
}

// ✅ ENVIAR A FLUTTER - DIRECTO SIN CONFIRMACIÓN
function sendToFlutter(code) {
  console.log(`📤 Enviando código a Flutter: ${code}`);
  
  if (barcodeScanner.callback) {
    try {
      // ENVÍO DIRECTO
      barcodeScanner.callback(code);
      console.log('✅ Código enviado a Flutter exitosamente');
      
      // Mostrar confirmación y cerrar
      updateStatus('✅ Código enviado correctamente');
      setTimeout(() => {
        cleanupBarcodeScanner();
      }, 1000);
      
    } catch (error) {
      console.error('❌ Error enviando a Flutter:', error);
      updateStatus('❌ Error enviando código');
    }
  } else {
    console.error('❌ No hay callback de Flutter registrado');
    updateStatus('❌ Error: No hay conexión con Flutter');
  }
}

// ✅ ENTRADA MANUAL SIN RESTRICCIONES
function showManualEntry() {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `
    <div class="modal-content" style="max-width: 400px;">
      <h3 style="margin-bottom: 20px;">⌨️ Entrada Manual</h3>
      
      <div style="margin-bottom: 20px;">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">
          Código del lote:
        </label>
        <input type="number" 
               id="manualCodeInput" 
               placeholder="Escriba el código exacto"
               style="width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 8px; 
                      font-size: 16px; text-align: center;"
               autofocus>
      </div>
      
      <div style="background: #e3f2fd; padding: 12px; border-radius: 8px; margin-bottom: 20px;">
        <small style="color: #1976d2;">
          💡 Escriba el código exactamente como aparece en la etiqueta
        </small>
      </div>
      
      <div style="display: flex; gap: 10px; justify-content: center;">
        <button onclick="sendManualCode()" class="scanner-button btn-success">
          ✅ Enviar
        </button>
        <button onclick="closeManualEntry()" class="scanner-button btn-secondary">
          ❌ Cancelar
        </button>
      </div>
    </div>
  `;
  
  document.body.appendChild(overlay);
  
  // Enviar al presionar Enter
  document.getElementById('manualCodeInput').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      sendManualCode();
    }
  });
}

// ✅ ENVIAR CÓDIGO MANUAL
function sendManualCode() {
  const input = document.getElementById('manualCodeInput');
  const code = input.value.trim();
  
  if (code) {
    console.log(`📝 Código manual ingresado: ${code}`);
    sendToFlutter(code);
    closeManualEntry();
  } else {
    input.focus();
    input.style.borderColor = '#f44336';
    setTimeout(() => {
      input.style.borderColor = '#ddd';
    }, 2000);
  }
}

// ✅ CERRAR ENTRADA MANUAL
function closeManualEntry() {
  const overlays = document.querySelectorAll('.modal-overlay');
  overlays.forEach(overlay => {
    if (overlay.querySelector('#manualCodeInput')) {
      document.body.removeChild(overlay);
    }
  });
}

// ✅ ACTUALIZAR ESTADO
function updateStatus(message) {
  const status = document.getElementById('scannerStatus');
  if (status) {
    status.textContent = message;
    console.log('📱 Estado:', message);
  }
}

// ✅ LIMPIAR ESCÁNER COMPLETAMENTE
window.cleanupBarcodeScanner = function() {
  console.log('🧹 Limpiando escáner...');
  
  barcodeScanner.isActive = false;
  barcodeScanner.isProcessing = false;
  barcodeScanner.capturedImage = null;
  
  // Detener stream de video
  if (barcodeScanner.videoStream) {
    barcodeScanner.videoStream.getTracks().forEach(track => {
      track.stop();
      console.log('📹 Track de video detenido');
    });
    barcodeScanner.videoStream = null;
  }
  
  // Remover overlay
  if (barcodeScanner.overlay && barcodeScanner.overlay.parentNode) {
    document.body.removeChild(barcodeScanner.overlay);
    barcodeScanner.overlay = null;
  }
  
  // Limpiar modales de entrada manual
  closeManualEntry();
  
  // Terminar worker de Tesseract
  if (barcodeScanner.worker) {
    barcodeScanner.worker.terminate();
    barcodeScanner.worker = null;
  }
  
  console.log('✅ Escáner limpiado completamente');
};

// ✅ FUNCIONES DE TEST
window.testBarcodeScanner = function() {
  console.log('🧪 Test del escáner mejorado:');
  console.log('📱 Scanner activo:', barcodeScanner.isActive);
  console.log('📷 Video stream:', !!barcodeScanner.videoStream);
  console.log('🔗 Callback registrado:', !!barcodeScanner.callback);
  return {
    active: barcodeScanner.isActive,
    hasStream: !!barcodeScanner.videoStream,
    hasCallback: !!barcodeScanner.callback
  };
};

window.simulateOCRSuccess = function(testCode = 'L 000016004') {
  console.log('🧪 Simulando detección OCR exitosa:', testCode);
  const number = extractUsefulNumber(testCode);
  if (number) {
    showDetectedResult(number);
  }
};

// ✅ Inicialización
console.log('✅ Barcode Scanner Mejorado con Captura Instantánea cargado');