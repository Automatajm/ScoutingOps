const express = require('express');
const router = express.Router();

// Función auxiliar para loguear errores de consulta
const logQueryError = (error, query, params) => {
  console.error('🚨 CRITICAL: Error en consulta SQL [REF-' + Date.now() + ']', {
    error: error.message,
    query: query,
    params: params,
    duration: error.duration,
    code: error.code
  });
  
  // Si hay detalles adicionales del error, loguearlos
  if (error.severity || error.code || error.detail) {
    console.error('Detalles del error:', {
      severity: error.severity,
      code: error.code,
      detail: error.detail,
      hint: error.hint,
      where: error.where,
      position: error.position
    });
  }
};

// GET - Obtener todas las unidades de cultivo con filtros opcionales usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de unidades de cultivo con stored procedure');
    const { busqueda, estatus, ubicacion } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? parseInt(estatus) : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      busqueda: busqueda || null,
      estatus: estatusParam,
      ubicacion: ubicacion || null
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_unidades_cultivo($1, $2, $3)',
        [
          busqueda || null, 
          estatusParam,
          ubicacion || null
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_unidades_cultivo($1, $2, $3)', 
        [busqueda || null, estatusParam, ubicacion || null]);
      throw queryError;
    }
    
    console.log(`Unidades de cultivo obtenidas: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener unidades de cultivo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener las unidades de cultivo',
        error: err.message
      });
    }
  }
});

// GET - Obtener ubicaciones únicas
router.get('/ubicaciones', async (req, res) => {
  try {
    console.log('Obteniendo ubicaciones únicas de unidades de cultivo');
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_ubicaciones_unidades()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_ubicaciones_unidades()', []);
      throw queryError;
    }
    
    // Extraer solo los valores de ubicación
    const ubicaciones = result.rows.map(row => row.ubicacion).filter(ubicacion => ubicacion);
    
    console.log(`Ubicaciones encontradas: ${ubicaciones.length}`);
    res.json({
      success: true,
      data: ubicaciones
    });
  } catch (err) {
    console.error('Error al obtener ubicaciones:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener las ubicaciones',
        error: err.message
      });
    }
  }
});

// GET - Obtener una unidad de cultivo por secuencia usando stored procedure
router.get('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    console.log(`Obteniendo unidad de cultivo con secuencia: ${parsedSecuencia}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_unidad_cultivo_by_id($1)',
        [parsedSecuencia]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_unidad_cultivo_by_id($1)', [parsedSecuencia]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Unidad de cultivo con secuencia ${parsedSecuencia} no encontrada`);
      return res.status(404).json({
        success: false,
        message: 'Unidad de cultivo no encontrada'
      });
    }
    
    console.log(`Unidad de cultivo con secuencia ${parsedSecuencia} obtenida exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener unidad de cultivo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener la unidad de cultivo',
        error: err.message
      });
    }
  }
});

// POST - Crear una nueva unidad de cultivo usando stored procedure (CORREGIDO)
router.post('/', async (req, res) => {
  try {
    const { 
      codigo, 
      cantero, 
      id,
      estatus, 
      ubicacion,
      creadopor
    } = req.body;
    
    console.log(`Iniciando creación de unidad de cultivo: ${codigo} - ${cantero} usando stored procedure`);
    
    // Validaciones básicas
    if (!codigo || !cantero) {
      return res.status(400).json({
        success: false,
        message: 'Los campos código y cantero son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedId = id !== undefined ? parseInt(id) : 0;
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedCreadoPor = creadopor ? parseInt(creadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // ⭐ PARÁMETROS EN EL ORDEN CORRECTO DEL SP
    console.log('Parámetros de creación:', {
      codigo,
      cantero,
      id: parsedId,
      estatus: parsedEstatus,
      ubicacion: ubicacion || null,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure con el ORDEN CORRECTO
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_unidad_cultivo($1, $2, $3, $4, $5, $6)',
        [
          codigo,                    // $1 - p_codigo TEXT
          cantero,                   // $2 - p_cantero TEXT
          parsedId,                  // $3 - p_id INTEGER
          parsedEstatus,             // $4 - p_estatus INTEGER
          ubicacion || null,         // $5 - p_ubicacion TEXT
          parsedCreadoPor            // $6 - p_creadopor INTEGER
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_unidad_cultivo($1, $2, $3, $4, $5, $6)', 
        [codigo, cantero, parsedId, parsedEstatus, ubicacion || null, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear la unidad de cultivo'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, secuencia } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear unidad de cultivo: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Unidad de cultivo creada exitosamente con secuencia: ${secuencia}`);
    res.status(201).json({
      success: true,
      message: message,
      data: { secuencia: secuencia }
    });
  } catch (err) {
    console.error('Error al crear unidad de cultivo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear la unidad de cultivo',
        error: err.message
      });
    }
  }
});

// POST - Crear múltiples unidades de cultivo de forma masiva
router.post('/masivo', async (req, res) => {
  try {
    const { unidades, limpiarAntes = false, ubicacionLimpiar = null } = req.body;
    
    console.log('Iniciando creación masiva de unidades de cultivo');
    console.log(`Total unidades a procesar: ${unidades ? unidades.length : 0}`);
    console.log(`Limpiar antes: ${limpiarAntes}, Ubicación a limpiar: ${ubicacionLimpiar}`);
    
    // Validaciones básicas
    if (!unidades || !Array.isArray(unidades) || unidades.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Se requiere un array de unidades no vacío'
      });
    }

    // Validar estructura de cada unidad
    const unidadesValidas = [];
    const erroresValidacion = [];

    for (let i = 0; i < unidades.length; i++) {
      const unidad = unidades[i];
      
      if (!unidad.codigo || !unidad.cantero) {
        erroresValidacion.push({
          indice: i,
          error: 'Código y cantero son obligatorios',
          unidad: unidad
        });
        continue;
      }

      // Normalizar y validar datos
      const unidadNormalizada = {
        codigo: String(unidad.codigo).trim(),
        cantero: String(unidad.cantero).trim(),
        id: parseInt(unidad.id) || 0,
        estatus: parseInt(unidad.estatus) || 1,
        ubicacion: unidad.ubicacion ? String(unidad.ubicacion).trim() : null,
        creadopor: parseInt(unidad.creadopor) || 1
      };

      unidadesValidas.push(unidadNormalizada);
    }

    // Si hay errores de validación, reportarlos
    if (erroresValidacion.length > 0) {
      console.log(`Errores de validación encontrados: ${erroresValidacion.length}`);
      return res.status(400).json({
        success: false,
        message: `Se encontraron ${erroresValidacion.length} errores de validación`,
        errores: erroresValidacion,
        unidades_validas: unidadesValidas.length
      });
    }

    // Usar el módulo db compartido
    const db = req.app.get('db');

    // Paso 1: Limpiar datos existentes si se solicita
    if (limpiarAntes) {
      console.log(`Limpiando datos existentes para ubicación: ${ubicacionLimpiar || 'todas'}`);
      
      try {
        const cleanupResult = await db.query(
          'SELECT * FROM sp_cleanup_unidades_by_ubicacion($1, $2)',
          [ubicacionLimpiar, false] // false = limpiar todos, no solo inactivos
        );
        
        console.log('Resultado de limpieza:', cleanupResult.rows[0]);
        
        if (!cleanupResult.rows[0]?.success) {
          console.error('Error en limpieza:', cleanupResult.rows[0]?.message);
          return res.status(500).json({
            success: false,
            message: 'Error al limpiar datos existentes: ' + cleanupResult.rows[0]?.message
          });
        }
      } catch (cleanupError) {
        console.error('Error al ejecutar limpieza:', cleanupError);
        return res.status(500).json({
          success: false,
          message: 'Error al limpiar datos existentes',
          error: cleanupError.message
        });
      }
    }

    // Paso 2: Crear/actualizar unidades masivamente
    console.log(`Procesando ${unidadesValidas.length} unidades válidas`);
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_unidades_masivo($1)',
        [JSON.stringify(unidadesValidas)]
      );
    } catch (queryError) {
      console.error('Error en stored procedure:', queryError);
      return res.status(500).json({
        success: false,
        message: 'Error al procesar unidades masivamente',
        error: queryError.message
      });
    }

    // Verificar resultado del stored procedure
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno: no se obtuvieron resultados del procesamiento'
      });
    }

    const spResult = result.rows[0];
    console.log('Resultado del stored procedure:', spResult);

    if (!spResult.success) {
      console.log(`Error en procesamiento masivo: ${spResult.message}`);
      return res.status(400).json({
        success: false,
        message: spResult.message,
        total_procesadas: spResult.total_procesadas || 0,
        total_creadas: spResult.total_creadas || 0,
        total_actualizadas: spResult.total_actualizadas || 0,
        detalles: spResult.detalles || []
      });
    }

    // Éxito - devolver resultados completos
    console.log(`Procesamiento masivo exitoso: ${spResult.total_procesadas} procesadas, ${spResult.total_creadas} creadas, ${spResult.total_actualizadas} actualizadas`);
    
    res.status(201).json({
      success: true,
      message: spResult.message,
      total_procesadas: spResult.total_procesadas,
      total_creadas: spResult.total_creadas,
      total_actualizadas: spResult.total_actualizadas,
      detalles: spResult.detalles,
      limpieza_previa: limpiarAntes ? `Ubicación: ${ubicacionLimpiar || 'todas'}` : 'No aplicada'
    });

  } catch (err) {
    console.error('Error general en creación masiva:', err);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor en creación masiva',
      error: err.message
    });
  }
});

// POST - Limpiar unidades por ubicación (endpoint independiente)
router.post('/limpiar', async (req, res) => {
  try {
    const { ubicacion, solo_inactivos = false } = req.body;
    
    console.log(`Limpiando unidades para ubicación: ${ubicacion || 'todas'}, solo_inactivos: ${solo_inactivos}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_cleanup_unidades_by_ubicacion($1, $2)',
        [ubicacion || null, solo_inactivos]
      );
    } catch (queryError) {
      console.error('Error en stored procedure de limpieza:', queryError);
      return res.status(500).json({
        success: false,
        message: 'Error al ejecutar limpieza',
        error: queryError.message
      });
    }

    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure de limpieza no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno: no se obtuvieron resultados de la limpieza'
      });
    }

    const spResult = result.rows[0];
    console.log('Resultado de limpieza:', spResult);

    if (!spResult.success) {
      console.log(`Error en limpieza: ${spResult.message}`);
      return res.status(400).json({
        success: false,
        message: spResult.message,
        total_eliminadas: spResult.total_eliminadas || 0
      });
    }

    console.log(`Limpieza exitosa: ${spResult.total_eliminadas} unidades marcadas como inactivas`);
    
    res.json({
      success: true,
      message: spResult.message,
      total_eliminadas: spResult.total_eliminadas,
      ubicacion_procesada: ubicacion || 'todas',
      solo_inactivos: solo_inactivos
    });

  } catch (err) {
    console.error('Error general en limpieza:', err);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor en limpieza',
      error: err.message
    });
  }
});

// PUT - Actualizar una unidad de cultivo usando stored procedure (CORREGIDO)
router.put('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    const { 
      codigo, 
      cantero, 
      id,
      estatus, 
      ubicacion,
      modificadopor
    } = req.body;
    
    console.log(`Iniciando actualización de unidad de cultivo con secuencia: ${parsedSecuencia} usando stored procedure`);
    
    // Validaciones básicas
    if (!codigo || !cantero) {
      return res.status(400).json({
        success: false,
        message: 'Los campos código y cantero son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedId = id !== undefined ? parseInt(id) : null;
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : null;
    const parsedModificadoPor = modificadopor ? parseInt(modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // ⭐ PARÁMETROS EN EL ORDEN CORRECTO DEL SP
    console.log('Parámetros de actualización:', {
      secuencia: parsedSecuencia,
      codigo,
      cantero,
      id: parsedId,
      estatus: parsedEstatus,
      ubicacion: ubicacion || null,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure con el ORDEN CORRECTO
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_unidad_cultivo($1, $2, $3, $4, $5, $6, $7)',
        [
          parsedSecuencia,           // $1 - p_secuencia INTEGER
          codigo,                    // $2 - p_codigo TEXT
          cantero,                   // $3 - p_cantero TEXT
          parsedId,                  // $4 - p_id INTEGER
          parsedEstatus,             // $5 - p_estatus INTEGER
          ubicacion || null,         // $6 - p_ubicacion TEXT
          parsedModificadoPor        // $7 - p_modificadopor INTEGER
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_unidad_cultivo($1, $2, $3, $4, $5, $6, $7)', 
        [parsedSecuencia, codigo, cantero, parsedId, parsedEstatus, ubicacion || null, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar la unidad de cultivo'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar unidad de cultivo: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Unidad de cultivo con secuencia ${parsedSecuencia} actualizada exitosamente`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al actualizar unidad de cultivo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar la unidad de cultivo',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar una unidad de cultivo (baja lógica) usando stored procedure
router.delete('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    console.log(`Iniciando eliminación lógica de la unidad de cultivo con secuencia: ${parsedSecuencia} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar unidad de cultivo con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_unidad_cultivo($1)',
        [parsedSecuencia]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_unidad_cultivo($1)', [parsedSecuencia]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar la unidad de cultivo'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrada')) {
        console.log(`Unidad de cultivo con secuencia ${parsedSecuencia} no encontrada`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar unidad de cultivo: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Unidad de cultivo con secuencia ${parsedSecuencia} eliminada lógicamente con éxito`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar unidad de cultivo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar la unidad de cultivo',
        error: err.message
      });
    }
  }
});

module.exports = router;