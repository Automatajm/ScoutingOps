const express = require('express');
const router = express.Router();

// Función auxiliar para loguear errores de consulta
const logQueryError = (error, query, params) => {
  console.error('Error en consulta:', {
    query: query,
    params: params,
    error: error.message
  });
  
  if (error.detail) {
    console.error('Detalles adicionales:', {
      severity: error.severity,
      code: error.code,
      detail: error.detail,
      hint: error.hint
    });
  }
};

// GET - Obtener todos los monitoreos con filtros opcionales
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de monitoreos con stored procedure');
    const { 
      lote, 
      plaga, 
      estatus, 
      fechaInicio, 
      fechaFin,
      casa,
      cantero,
      variedad
    } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? parseInt(estatus) : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      lote: lote || null,
      plaga: plaga || null,
      estatus: estatusParam,
      fechaInicio: fechaInicio || null,
      fechaFin: fechaFin || null,
      casa: casa || null,
      cantero: cantero || null,
      variedad: variedad || null
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_monitoreos($1, $2, $3, $4, $5, $6, $7, $8)',
        [
          lote || null, 
          plaga || null,
          estatusParam,
          fechaInicio || null,
          fechaFin || null,
          casa || null,
          cantero || null,
          variedad || null
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreos', 
        [lote, plaga, estatusParam, fechaInicio, fechaFin, casa, cantero, variedad]);
      throw queryError;
    }
    
    console.log(`Monitoreos obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar monitoreos:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar monitoreos',
        error: err.message
      });
    }
  }
});

// GET - Obtener un monitoreo específico por ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo monitoreo con ID: ${parsedId} usando stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_monitoreo_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreo_by_id', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: `No se encontró el monitoreo con ID ${id}` 
      });
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al consultar monitoreo por ID:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al consultar monitoreo con ID ${req.params.id}`,
        error: err.message
      });
    }
  }
});

// POST - Crear un nuevo monitoreo (CON IDEMPOTENCIA)
router.post('/', async (req, res) => {
  try {
    const {
      pmlt_codigo,
      pmmo_casa,
      pmmo_cantero,
      pmmo_variedad,
      pmni_nombrecomun,
      pmmo_cantidad,
      pmmo_canteros,
      pmmo_idvariedad,
      pmmo_grower,
      pmmo_cant_botada,
      pmmo_comentarios,
      pmmo_fecha,
      pmmo_automatico,
      pmmo_estatus,
      pmmo_creadopor,
      pmmo_nivmuestram1,
      pmmo_nivmuestram2,
      pmmo_nivmuestram3,
      pmmo_nivmuestraa1,
      pmmo_nivmuestraa2,
      pmmo_nivmuestraa3,
      pmmo_muestra1,
      pmmo_muestra2,
      pmmo_muestra3,
      pmmo_contenedor,
      idempotency_key  // NUEVO
    } = req.body;
    
    if (!pmlt_codigo || !pmmo_casa || !pmmo_cantero || !pmmo_variedad || !pmni_nombrecomun || pmmo_cantidad === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Faltan campos obligatorios: código de lote, casa, cantero, variedad, plaga y cantidad son obligatorios'
      });
    }
    
    console.log('Creando monitoreo mediante stored procedure');
    if (idempotency_key) {
      console.log(`Idempotency key: ${idempotency_key}`);
    }
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_monitoreo($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)',
        [
          pmlt_codigo,
          pmmo_casa,
          pmmo_cantero,
          pmmo_variedad,
          pmni_nombrecomun,
          pmmo_cantidad,
          pmmo_canteros || null,
          pmmo_idvariedad || null,
          pmmo_grower || null,
          pmmo_cant_botada || null,
          pmmo_comentarios || null,
          pmmo_fecha || null,
          pmmo_automatico !== undefined ? pmmo_automatico : true,
          pmmo_estatus !== undefined ? pmmo_estatus : 1,
          pmmo_creadopor || 1,
          pmmo_nivmuestram1 || null,
          pmmo_nivmuestram2 || null,
          pmmo_nivmuestram3 || null,
          pmmo_nivmuestraa1 || null,
          pmmo_nivmuestraa2 || null,
          pmmo_nivmuestraa3 || null,
          pmmo_muestra1 || null,
          pmmo_muestra2 || null,
          pmmo_muestra3 || null,
          pmmo_contenedor || 'CONT_GENERAL',
          idempotency_key || null  // NUEVO - parámetro 26
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_create_monitoreo', [pmlt_codigo, pmmo_casa, pmmo_cantero]);
      throw queryError;
    }
    
    if (!result.rows || result.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el monitoreo'
      });
    }
    
    const { success, message, monitoreo_id } = result.rows[0];
    
    if (!success) {
      if (message.includes('Ya existe un monitoreo')) {
        return res.status(409).json({
          success: false,
          message: message,
          existing_id: monitoreo_id
        });
      }
      return res.status(400).json({ success: false, message: message });
    }
    
    let monitoreoResult;
    try {
      monitoreoResult = await db.query('SELECT * FROM sp_get_monitoreo_by_id($1)', [monitoreo_id]);
    } catch (queryError) {
      return res.status(201).json({
        success: true,
        message: message,
        data: { pmmo_secuencia: monitoreo_id }
      });
    }
    
    const isIdempotent = message.includes('idempotente');
    const statusCode = isIdempotent ? 200 : 201;
    
    console.log(`Monitoreo ${isIdempotent ? 'retornado (idempotente)' : 'creado'} con ID: ${monitoreo_id}`);
    
    res.status(statusCode).json({
      success: true,
      message: message,
      data: monitoreoResult.rows[0] || { pmmo_secuencia: monitoreo_id },
      idempotent: isIdempotent
    });
  } catch (err) {
    console.error('Error al crear monitoreo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear monitoreo',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar un monitoreo existente (CON CONTROL DE VERSIÓN)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const {
      pmlt_codigo,
      pmmo_casa,
      pmmo_cantero,
      pmmo_canteros,
      pmmo_variedad,
      pmmo_idvariedad,
      pmmo_grower,
      pmni_nombrecomun,
      pmmo_cantidad,
      pmmo_cant_botada,
      pmmo_comentarios,
      pmmo_fecha,
      pmmo_automatico,
      pmmo_estatus,
      pmmo_modificadopor,
      pmmo_nivmuestram1,
      pmmo_nivmuestram2,
      pmmo_nivmuestram3,
      pmmo_nivmuestraa1,
      pmmo_nivmuestraa2,
      pmmo_nivmuestraa3,
      pmmo_muestra1,
      pmmo_muestra2,
      pmmo_muestra3,
      pmmo_contenedor,
      expected_version  // NUEVO
    } = req.body;
    
    console.log(`Actualizando monitoreo ID: ${parsedId}`);
    if (expected_version !== undefined) {
      console.log(`Versión esperada: ${expected_version}`);
    }
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_monitoreo($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27)',
        [
          parsedId,
          pmlt_codigo || null,
          pmmo_casa || null,
          pmmo_cantero || null,
          pmmo_canteros || null,
          pmmo_variedad || null,
          pmmo_idvariedad || null,
          pmmo_grower || null,
          pmni_nombrecomun || null,
          pmmo_cantidad !== undefined ? pmmo_cantidad : null,
          pmmo_cant_botada !== undefined ? pmmo_cant_botada : null,
          pmmo_comentarios || null,
          pmmo_fecha || null,
          pmmo_automatico !== undefined ? pmmo_automatico : null,
          pmmo_estatus !== undefined ? pmmo_estatus : null,
          pmmo_modificadopor || 1,
          pmmo_nivmuestram1 !== undefined ? pmmo_nivmuestram1 : null,
          pmmo_nivmuestram2 !== undefined ? pmmo_nivmuestram2 : null,
          pmmo_nivmuestram3 !== undefined ? pmmo_nivmuestram3 : null,
          pmmo_nivmuestraa1 !== undefined ? pmmo_nivmuestraa1 : null,
          pmmo_nivmuestraa2 !== undefined ? pmmo_nivmuestraa2 : null,
          pmmo_nivmuestraa3 !== undefined ? pmmo_nivmuestraa3 : null,
          pmmo_muestra1 !== undefined ? pmmo_muestra1 : null,
          pmmo_muestra2 !== undefined ? pmmo_muestra2 : null,
          pmmo_muestra3 !== undefined ? pmmo_muestra3 : null,
          pmmo_contenedor || null,
          expected_version !== undefined ? parseInt(expected_version) : null  // NUEVO - parámetro 27
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_update_monitoreo', [parsedId]);
      throw queryError;
    }
    
    if (!result.rows || result.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el monitoreo'
      });
    }
    
    const { success, message, id: monitoreo_id, new_version } = result.rows[0];
    
    if (!success) {
      if (message.includes('Conflicto')) {
        return res.status(409).json({
          success: false,
          message: message,
          conflict: true,
          current_version: new_version
        });
      }
      return res.status(400).json({ success: false, message: message });
    }
    
    let monitoreoResult;
    try {
      monitoreoResult = await db.query('SELECT * FROM sp_get_monitoreo_by_id($1)', [monitoreo_id]);
    } catch (queryError) {
      return res.json({
        success: true,
        message: message,
        new_version: new_version
      });
    }
    
    console.log(`Monitoreo actualizado ID: ${parsedId}, versión: ${new_version}`);
    
    res.json({
      success: true,
      message: message,
      data: monitoreoResult.rows[0] || { pmmo_secuencia: monitoreo_id },
      new_version: new_version
    });
  } catch (err) {
    console.error('Error al actualizar monitoreo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al actualizar monitoreo con ID ${req.params.id}`,
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar un monitoreo (eliminación lógica)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Eliminando monitoreo con ID: ${parsedId} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_monitoreo($1, $2)',
        [parsedId, 1] // 1 = usuario por defecto
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_delete_monitoreo', [parsedId, 1]);
      throw queryError;
    }
    
    if (!result.rows || result.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar el monitoreo'
      });
    }
    
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontró')) {
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Monitoreo eliminado exitosamente ID: ${parsedId}`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar monitoreo:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al eliminar monitoreo con ID ${req.params.id}`,
        error: err.message
      });
    }
  }
});

// GET - Verificar idempotency key
router.get('/check-idempotency/:key', async (req, res) => {
  try {
    const { key } = req.params;
    
    if (!key) {
      return res.status(400).json({ success: false, message: 'Se requiere idempotency_key' });
    }
    
    const db = req.app.get('db');
    const result = await db.query('SELECT * FROM sp_check_idempotency($1)', [key]);
    
    if (result.rows.length === 0 || !result.rows[0].exists_flag) {
      return res.json({ success: true, exists: false });
    }
    
    const { monitoreo_id, created_at } = result.rows[0];
    res.json({
      success: true,
      exists: true,
      monitoreo_id: monitoreo_id,
      created_at: created_at
    });
  } catch (err) {
    console.error('Error al verificar idempotency:', err);
    res.status(500).json({ success: false, message: 'Error al verificar', error: err.message });
  }
});

// POST - Sincronización en batch
router.post('/sync-batch', async (req, res) => {
  const db = req.app.get('db');
  const client = await db.getClient();
  
  try {
    const { monitoreos } = req.body;
    
    if (!monitoreos || !Array.isArray(monitoreos) || monitoreos.length === 0) {
      return res.status(400).json({ success: false, message: 'Debe proporcionar un array de monitoreos' });
    }
    
    console.log(`Sincronización batch: ${monitoreos.length} monitoreos`);
    
    await client.query('BEGIN');
    
    const resultados = [];
    let creados = 0, idempotentes = 0, fallidos = 0;
    
    for (const m of monitoreos) {
      try {
        if (!m.pmlt_codigo || !m.pmmo_casa || !m.pmmo_cantero || !m.pmmo_variedad || !m.pmni_nombrecomun || m.pmmo_cantidad === undefined) {
          resultados.push({ success: false, message: 'Faltan campos', temp_id: m.temp_id, idempotency_key: m.idempotency_key });
          fallidos++;
          continue;
        }
        
        const result = await client.query(
          'SELECT * FROM sp_create_monitoreo($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26)',
          [
            m.pmlt_codigo, m.pmmo_casa, m.pmmo_cantero, m.pmmo_variedad, m.pmni_nombrecomun, m.pmmo_cantidad,
            m.pmmo_canteros || null, m.pmmo_idvariedad || null, m.pmmo_grower || null, m.pmmo_cant_botada || null,
            m.pmmo_comentarios || null, m.pmmo_fecha || null, m.pmmo_automatico !== undefined ? m.pmmo_automatico : true,
            m.pmmo_estatus !== undefined ? m.pmmo_estatus : 1, m.pmmo_creadopor || 1,
            m.pmmo_nivmuestram1 || null, m.pmmo_nivmuestram2 || null, m.pmmo_nivmuestram3 || null,
            m.pmmo_nivmuestraa1 || null, m.pmmo_nivmuestraa2 || null, m.pmmo_nivmuestraa3 || null,
            m.pmmo_muestra1 || null, m.pmmo_muestra2 || null, m.pmmo_muestra3 || null,
            m.pmmo_contenedor || 'CONT_GENERAL', m.idempotency_key || null
          ]
        );
        
        const { success, message, monitoreo_id } = result.rows[0];
        const isIdempotent = message.includes('idempotente');
        
        if (success) {
          resultados.push({ success: true, server_id: monitoreo_id, temp_id: m.temp_id, idempotency_key: m.idempotency_key, idempotent: isIdempotent });
          isIdempotent ? idempotentes++ : creados++;
        } else {
          resultados.push({ success: false, message, temp_id: m.temp_id, idempotency_key: m.idempotency_key });
          fallidos++;
        }
      } catch (error) {
        resultados.push({ success: false, message: error.message, temp_id: m.temp_id });
        fallidos++;
      }
    }
    
    await client.query('COMMIT');
    
    res.json({
      success: true,
      message: `Sync: ${creados} creados, ${idempotentes} existían, ${fallidos} fallidos`,
      summary: { total: monitoreos.length, created: creados, idempotent: idempotentes, failed: fallidos },
      results: resultados
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error en sync batch:', err);
    res.status(500).json({ success: false, message: 'Error en sincronización', error: err.message });
  } finally {
    client.release();
  }
});

// GET - Obtener monitoreos por código de lote
router.get('/lote/:codigo', async (req, res) => {
  try {
    const { codigo } = req.params;
    
    console.log(`Consultando monitoreos para lote: ${codigo} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_monitoreos_by_lote($1)',
        [codigo]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreos_by_lote', [codigo]);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar monitoreos por lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al consultar monitoreos para el lote ${req.params.codigo}`,
        error: err.message
      });
    }
  }
});

// GET - Obtener información detallada de un lote
router.get('/info-lote/:codigo', async (req, res) => {
  try {
    const { codigo } = req.params;
    
    console.log(`Consultando información para lote: ${codigo} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_lote_info($1)',
        [codigo]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_lote_info', [codigo]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `No se encontró el lote con código ${codigo}`
      });
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al consultar información del lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al consultar información para el lote ${req.params.codigo}`,
        error: err.message
      });
    }
  }
});

// GET - Obtener estadísticas resumidas para el dashboard
router.get('/estadisticas/resumen', async (req, res) => {
  try {
    const { usuarioId } = req.query;
    const parsedUsuarioId = usuarioId ? parseInt(usuarioId) : null;
    
    console.log(`Consultando estadísticas${usuarioId ? ` para usuario ${usuarioId}` : ''} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_estadisticas_resumen($1)',
        [parsedUsuarioId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_estadisticas_resumen', [parsedUsuarioId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: 'No se pudieron obtener estadísticas'
      });
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al consultar estadísticas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar estadísticas de monitoreo',
        error: err.message
      });
    }
  }
});

// GET - Obtener todas las plagas activas
router.get('/plagas/activas', async (req, res) => {
  try {
    console.log('Consultando plagas activas mediante stored procedure');
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_plagas_activas()');
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_plagas_activas', []);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar plagas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar plagas activas',
        error: err.message
      });
    }
  }
});

// POST - Crear un monitoreo con cálculo automático de niveles
router.post('/auto-niveles', async (req, res) => {
  try {
    const {
      pmlt_codigo,
      pmmo_casa,
      pmmo_cantero,
      pmmo_variedad,
      pmni_nombrecomun,
      pmmo_cantidad,
      pmmo_muestra1,
      pmmo_muestra2,
      pmmo_muestra3,
      pmmo_canteros,
      pmmo_idvariedad,
      pmmo_grower,
      pmmo_cant_botada,
      pmmo_comentarios,
      pmmo_fecha,
      pmmo_automatico,
      pmmo_creadopor,
      pmmo_contenedor
    } = req.body;
    
    if (!pmlt_codigo || !pmmo_casa || !pmmo_cantero || !pmmo_variedad || !pmni_nombrecomun || 
        pmmo_cantidad === undefined || pmmo_muestra1 === undefined || 
        pmmo_muestra2 === undefined || pmmo_muestra3 === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Faltan campos obligatorios para el cálculo automático de niveles'
      });
    }
    
    console.log('Creando monitoreo con niveles automáticos mediante stored procedure');
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_monitoreo_con_niveles($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)',
        [
          pmlt_codigo,
          pmmo_casa,
          pmmo_cantero,
          pmmo_variedad,
          pmni_nombrecomun,
          pmmo_cantidad,
          pmmo_muestra1,
          pmmo_muestra2,
          pmmo_muestra3,
          pmmo_canteros || null,
          pmmo_idvariedad || null,
          pmmo_grower || null,
          pmmo_cant_botada || null,
          pmmo_comentarios || null,
          pmmo_fecha || null,
          pmmo_automatico !== undefined ? pmmo_automatico : true,
          pmmo_creadopor || 1,
          pmmo_contenedor || 'CONT_GENERAL'
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_create_monitoreo_con_niveles', [
        pmlt_codigo, pmmo_casa, pmmo_cantero, pmmo_variedad, pmni_nombrecomun, pmmo_cantidad,
        pmmo_muestra1, pmmo_muestra2, pmmo_muestra3
      ]);
      throw queryError;
    }
    
    if (!result.rows || result.rows.length === 0) {
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el monitoreo con niveles automáticos'
      });
    }
    
    const { success, message, monitoreo_id } = result.rows[0];
    
    if (!success) {
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    let monitoreoResult;
    try {
      monitoreoResult = await db.query(
        'SELECT * FROM sp_get_monitoreo_by_id($1)',
        [monitoreo_id]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreo_by_id', [monitoreo_id]);
      return res.status(201).json({
        success: true,
        message: message,
        data: { pmmo_secuencia: monitoreo_id }
      });
    }
    
    console.log(`Monitoreo con niveles automáticos creado exitosamente con ID: ${monitoreo_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: monitoreoResult.rows[0] || { pmmo_secuencia: monitoreo_id }
    });
  } catch (err) {
    console.error('Error al crear monitoreo con niveles automáticos:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear monitoreo con niveles automáticos',
        error: err.message
      });
    }
  }
});

// GET - Obtener monitoreos por usuario
router.get('/usuario/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    const { fechaInicio, fechaFin } = req.query;
    
    console.log(`Consultando monitoreos para usuario ID: ${parsedId} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_monitoreos_by_usuario($1, $2, $3)',
        [parsedId, fechaInicio || null, fechaFin || null]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreos_by_usuario', [parsedId, fechaInicio, fechaFin]);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar monitoreos por usuario:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al consultar monitoreos para el usuario ${req.params.id}`,
        error: err.message
      });
    }
  }
});

// GET - Obtener niveles para una plaga específica
router.get('/niveles/:plaga', async (req, res) => {
  try {
    const { plaga } = req.params;
    
    console.log(`Consultando niveles para plaga: ${plaga} mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_niveles_plaga($1)',
        [plaga]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_niveles_plaga', [plaga]);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar niveles de plaga:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: `Error al consultar niveles para la plaga ${req.params.plaga}`,
        error: err.message
      });
    }
  }
});

// GET - Obtener monitoreos recientes
router.get('/recientes/:dias?', async (req, res) => {
  try {
    const { dias } = req.params;
    const { usuarioId } = req.query;
    
    const diasParam = dias ? parseInt(dias) : 7;
    const usuarioIdParam = usuarioId ? parseInt(usuarioId) : null;
    
    console.log(`Consultando monitoreos recientes (${diasParam} días) mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_monitoreos_recientes($1, $2)',
        [diasParam, usuarioIdParam]
      );
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_monitoreos_recientes', [diasParam, usuarioIdParam]);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar monitoreos recientes:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar monitoreos recientes',
        error: err.message
      });
    }
  }
});

// GET - Obtener casas y canteros para filtros
router.get('/filtros/casas-canteros', async (req, res) => {
  try {
    console.log('Consultando casas y canteros para filtros mediante stored procedure');

    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_casas_canteros()');
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_casas_canteros', []);
      throw queryError;
    }
    
    const casas = [];
    const canteros = [];
    
    result.rows.forEach(row => {
      if (row.tipo === 'casa') {
        casas.push({
          valor: row.valor,
          cuenta: parseInt(row.cuenta)
        });
      } else if (row.tipo === 'cantero') {
        canteros.push({
          valor: row.valor,
          cuenta: parseInt(row.cuenta)
        });
      }
    });
    
    res.json({
      success: true,
      data: {
        casas,
        canteros
      }
    });
  } catch (err) {
    console.error('Error al consultar filtros de casas y canteros:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar filtros',
        error: err.message
      });
    }
  }
});

// GET - Obtener variedades activas
router.get('/filtros/variedades', async (req, res) => {
  try {
    console.log('Consultando variedades activas para filtros mediante stored procedure');
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_variedades_activas()');
    } catch (queryError) {
      logQueryError(queryError, 'sp_get_variedades_activas', []);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar variedades activas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar variedades activas',
        error: err.message
      });
    }
  }
});

// GET - Obtener tendencias de plagas por periodo
router.get('/tendencias/:periodo', async (req, res) => {
  try {
    const { periodo } = req.params;
    const { usuarioId } = req.query;
    
    let periodoEnDias = 30;
    
    switch (periodo) {
      case 'semanal':
        periodoEnDias = 7;
        break;
      case 'trimestral':
        periodoEnDias = 90;
        break;
      case 'anual':
        periodoEnDias = 365;
        break;
    }
    
    const parsedUsuarioId = usuarioId ? parseInt(usuarioId) : null;
    
    console.log(`Consultando tendencias de ${periodo} días mediante stored procedure`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      result = await db.query(`
        SELECT 
          p.pmpl_nombrecomun as plaga,
          COUNT(*) as cantidad,
          DATE_TRUNC('week', m.pmmo_fecha) as semana
        FROM pm_monitoreos m
        JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
        WHERE m.pmmo_fecha >= NOW() - INTERVAL '${periodoEnDias} days'
          AND m.pmmo_estatus = 1
          ${parsedUsuarioId ? 'AND m.pmmo_creadopor = $1' : ''}
        GROUP BY p.pmpl_nombrecomun, DATE_TRUNC('week', m.pmmo_fecha)
        ORDER BY semana, cantidad DESC
      `, parsedUsuarioId ? [parsedUsuarioId] : []);
    } catch (queryError) {
      logQueryError(queryError, 'consulta de tendencias', [parsedUsuarioId]);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar tendencias de plagas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar tendencias de plagas',
        error: err.message
      });
    }
  }
});

// GET - Obtener mapa de calor de plagas
router.get('/mapa-calor', async (req, res) => {
  try {
    const { fechaInicio, fechaFin, plaga } = req.query;
    
    console.log(`Consultando mapa de calor de plagas mediante consulta directa`);
    
    const db = req.app.get('db');
    
    const queryParams = [];
    let paramCount = 1;
    let whereClause = 'm.pmmo_estatus = 1';
    
    if (fechaInicio) {
      whereClause += ` AND m.pmmo_fecha >= $${paramCount++}`;
      queryParams.push(fechaInicio);
    } else {
      whereClause += ` AND m.pmmo_fecha >= NOW() - INTERVAL '30 days'`;
    }
    
    if (fechaFin) {
      whereClause += ` AND m.pmmo_fecha <= $${paramCount++}`;
      queryParams.push(fechaFin);
    }
    
    if (plaga) {
      whereClause += ` AND p.pmpl_nombrecomun = $${paramCount++}`;
      queryParams.push(plaga);
    }
    
    let result;
    try {
      result = await db.query(`
        SELECT 
          m.pmmo_casa as casa,
          m.pmmo_cantero as cantero,
          p.pmpl_nombrecomun as plaga,
          COUNT(*) as cantidad,
          AVG(m.pmmo_cantidad) as promedio
        FROM pm_monitoreos m
        JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
        WHERE ${whereClause}
        GROUP BY m.pmmo_casa, m.pmmo_cantero, p.pmpl_nombrecomun
        ORDER BY cantidad DESC, promedio DESC
      `, queryParams);
    } catch (queryError) {
      logQueryError(queryError, 'consulta de mapa de calor', queryParams);
      throw queryError;
    }
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al consultar mapa de calor de plagas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al consultar mapa de calor de plagas',
        error: err.message
      });
    }
  }
});

// GET - Obtener resumen de comparación entre lotes
router.get('/comparar-lotes', async (req, res) => {
  try {
    const { lotes, dias } = req.query;
    
    if (!lotes) {
      return res.status(400).json({
        success: false,
        message: 'Debe proporcionar al menos un lote para comparar'
      });
    }
    
    const lotesArray = Array.isArray(lotes) ? lotes : [lotes];
    const diasNum = parseInt(dias) || 30;
    
    console.log(`Comparando lotes: ${lotesArray.join(', ')} en los últimos ${diasNum} días`);
    
    const db = req.app.get('db');
    
    let result;
    try {
      const placeholders = lotesArray.map((_, i) => `$${i + 1}`).join(',');
      result = await db.query(`
        SELECT 
          m.pmlt_codigo,
          p.pmpl_nombrecomun,
          COUNT(*) as cantidad_monitoreos,
          AVG(m.pmmo_cantidad) as promedio_cantidad,
          MAX(m.pmmo_cantidad) as max_cantidad,
          COUNT(DISTINCT m.pmmo_casa) as cantidad_casas,
          COUNT(DISTINCT m.pmmo_cantero) as cantidad_canteros
        FROM pm_monitoreos m
        JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
        WHERE m.pmlt_codigo IN (${placeholders})
          AND m.pmmo_fecha >= NOW() - INTERVAL '${diasNum} days'
          AND m.pmmo_estatus = 1
        GROUP BY m.pmlt_codigo, p.pmpl_nombrecomun
        ORDER BY m.pmlt_codigo, cantidad_monitoreos DESC
      `, lotesArray);
    } catch (queryError) {
      logQueryError(queryError, 'comparación de lotes', lotesArray);
      throw queryError;
    }
    
    const comparacion = {};
    
    lotesArray.forEach(lote => {
      comparacion[lote] = {
        plagas: [],
        total_monitoreos: 0,
        total_casas: 0,
        total_canteros: 0
      };
    });
    
    result.rows.forEach(row => {
      const lote = row.pmlt_codigo;
      
      if (comparacion[lote]) {
        comparacion[lote].plagas.push({
          plaga: row.pmpl_nombrecomun,
          cantidad: parseInt(row.cantidad_monitoreos),
          promedio: parseFloat(row.promedio_cantidad).toFixed(2),
          maximo: parseInt(row.max_cantidad)
        });
        
        comparacion[lote].total_monitoreos += parseInt(row.cantidad_monitoreos);
        comparacion[lote].total_casas = parseInt(row.cantidad_casas);
        comparacion[lote].total_canteros = parseInt(row.cantidad_canteros);
      }
    });
    
    res.json({
      success: true,
      data: comparacion
    });
  } catch (err) {
    console.error('Error al comparar lotes:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al comparar lotes',
        error: err.message
      });
    }
  }
});

// POST - Importar múltiples monitoreos
router.post('/importar', async (req, res) => {
  const db = req.app.get('db');
  const client = await db.getClient();
  
  try {
    const { monitoreos } = req.body;
    
    if (!monitoreos || !Array.isArray(monitoreos) || monitoreos.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Debe proporcionar un array de monitoreos para importar'
      });
    }
    
    console.log(`Iniciando importación de ${monitoreos.length} monitoreos`);
    
    await client.query('BEGIN');
    
    const resultados = [];
    let exitosos = 0;
    let fallidos = 0;
    
    for (const monitoreo of monitoreos) {
      try {
        if (!monitoreo.pmlt_codigo || !monitoreo.pmmo_casa || !monitoreo.pmmo_cantero || 
            !monitoreo.pmmo_variedad || !monitoreo.pmni_nombrecomun || monitoreo.pmmo_cantidad === undefined) {
          resultados.push({
            success: false,
            message: 'Faltan campos obligatorios',
            data: monitoreo
          });
          fallidos++;
          continue;
        }
        
        const result = await client.query(
          'SELECT * FROM sp_create_monitoreo($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)',
          [
            monitoreo.pmlt_codigo,
            monitoreo.pmmo_casa,
            monitoreo.pmmo_cantero,
            monitoreo.pmmo_variedad,
            monitoreo.pmni_nombrecomun,
            monitoreo.pmmo_cantidad,
            monitoreo.pmmo_canteros || null,
            monitoreo.pmmo_idvariedad || null,
            monitoreo.pmmo_grower || null,
            monitoreo.pmmo_cant_botada || null,
            monitoreo.pmmo_comentarios || null,
            monitoreo.pmmo_fecha || null,
            monitoreo.pmmo_automatico !== undefined ? monitoreo.pmmo_automatico : true,
            monitoreo.pmmo_estatus !== undefined ? monitoreo.pmmo_estatus : 1,
            monitoreo.pmmo_creadopor || 1,
            monitoreo.pmmo_nivmuestram1 || null,
            monitoreo.pmmo_nivmuestram2 || null,
            monitoreo.pmmo_nivmuestram3 || null,
            monitoreo.pmmo_nivmuestraa1 || null,
            monitoreo.pmmo_nivmuestraa2 || null,
            monitoreo.pmmo_nivmuestraa3 || null,
            monitoreo.pmmo_muestra1 || null,
            monitoreo.pmmo_muestra2 || null,
            monitoreo.pmmo_muestra3 || null,
            monitoreo.pmmo_contenedor || 'CONT_GENERAL',
            monitoreo.idempotency_key || null
          ]
        );
        
        const { success, message, monitoreo_id } = result.rows[0];
        
        if (success) {
          resultados.push({
            success: true,
            message: message,
            id: monitoreo_id
          });
          exitosos++;
        } else {
          resultados.push({
            success: false,
            message: message,
            data: monitoreo
          });
          fallidos++;
        }
      } catch (error) {
        console.error('Error al importar un monitoreo:', error);
        resultados.push({
          success: false,
          message: error.message,
          data: monitoreo
        });
        fallidos++;
      }
    }
    
    await client.query('COMMIT');
    
    res.json({
      success: true,
      message: `Importación completada: ${exitosos} exitosos, ${fallidos} fallidos`,
      data: {
        total: monitoreos.length,
        exitosos: exitosos,
        fallidos: fallidos,
        resultados: resultados
      }
    });
  } catch (err) {
    await client.query('ROLLBACK');
    
    console.error('Error al importar monitoreos:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al importar monitoreos',
        error: err.message
      });
    }
  } finally {
    client.release();
  }
});

// ============================================================
// ENDPOINTS DE SINCRONIZACIÓN PARA DR PEST CONTROL
// ============================================================
// INSTRUCCIONES:
// 1. Abrir routes/monitoreo.js
// 2. Buscar la línea: module.exports = router;
// 3. Pegar TODO este código ANTES de esa línea
// 4. Reiniciar el servidor
// ============================================================

// GET - Sincronización incremental (pull de cambios desde servidor)
// Solo devuelve registros de los últimos N días para el usuario
// Uso: GET /api/monitoreo/sync?usuario=4&dias=2
router.get('/sync', async (req, res) => {
  try {
    const { desde, usuario, limit, dias } = req.query;
    
    const usuarioId = usuario ? parseInt(usuario) : null;
    const limitNum = Math.min(parseInt(limit) || 500, 1000);
    const diasNum = parseInt(dias) || 2; // Por defecto 2 días (hoy y ayer)
    
    if (!usuarioId) {
      return res.status(400).json({
        success: false,
        message: 'Se requiere el parámetro usuario'
      });
    }
    
    console.log(`Sync incremental - usuario: ${usuarioId}, dias: ${diasNum}, desde: ${desde || 'inicio'}`);
    
    const db = req.app.get('db');
    
    let query;
    let params;
    
    if (desde) {
      // Sync incremental: cambios desde última sincronización (dentro de ventana de días)
      query = `
        SELECT 
          pmmo_secuencia,
          pmlt_codigo,
          pmmo_casa,
          pmmo_cantero,
          pmmo_canteros,
          pmmo_variedad,
          pmmo_idvariedad,
          pmmo_grower,
          pmni_nombrecomun,
          pmmo_cantidad,
          pmmo_cant_botada,
          pmmo_comentarios,
          pmmo_fecha,
          pmmo_automatico,
          pmmo_estatus,
          pmmo_creadopor,
          pmmo_contenedor,
          pmni_id,
          pmmo_muestra1,
          pmmo_muestra2,
          pmmo_muestra3,
          pmmo_nivmuestraa1,
          pmmo_nivmuestraa2,
          pmmo_nivmuestraa3,
          pmmo_nivmuestram1,
          pmmo_nivmuestram2,
          pmmo_nivmuestram3,
          lmsupniv1,
          lmsupniv2,
          lmsupniv3,
          version,
          idempotency_key,
          pmmo_fechacreacion,
          pmmo_fechamodificacion,
          GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) as last_modified
        FROM pm_monitoreos
        WHERE pmmo_creadopor = $1
          AND pmmo_fecha >= (CURRENT_DATE - INTERVAL '${diasNum} days')
          AND GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) > $2
        ORDER BY last_modified ASC
        LIMIT ${limitNum}
      `;
      params = [usuarioId, desde];
    } else {
      // Sync inicial: todos los registros de los últimos N días
      query = `
        SELECT 
          pmmo_secuencia,
          pmlt_codigo,
          pmmo_casa,
          pmmo_cantero,
          pmmo_canteros,
          pmmo_variedad,
          pmmo_idvariedad,
          pmmo_grower,
          pmni_nombrecomun,
          pmmo_cantidad,
          pmmo_cant_botada,
          pmmo_comentarios,
          pmmo_fecha,
          pmmo_automatico,
          pmmo_estatus,
          pmmo_creadopor,
          pmmo_contenedor,
          pmni_id,
          pmmo_muestra1,
          pmmo_muestra2,
          pmmo_muestra3,
          pmmo_nivmuestraa1,
          pmmo_nivmuestraa2,
          pmmo_nivmuestraa3,
          pmmo_nivmuestram1,
          pmmo_nivmuestram2,
          pmmo_nivmuestram3,
          lmsupniv1,
          lmsupniv2,
          lmsupniv3,
          version,
          idempotency_key,
          pmmo_fechacreacion,
          pmmo_fechamodificacion,
          GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) as last_modified
        FROM pm_monitoreos
        WHERE pmmo_creadopor = $1
          AND pmmo_estatus = 1
          AND pmmo_fecha >= (CURRENT_DATE - INTERVAL '${diasNum} days')
        ORDER BY pmmo_fecha DESC
        LIMIT ${limitNum}
      `;
      params = [usuarioId];
    }
    
    const result = await db.query(query, params);
    
    const hasMore = result.rows.length === limitNum;
    const lastTimestamp = result.rows.length > 0 
      ? result.rows[result.rows.length - 1].last_modified 
      : null;
    
    console.log(`Sync: ${result.rows.length} registros devueltos (ventana: ${diasNum} días)`);
    
    res.json({
      success: true,
      data: result.rows,
      meta: {
        count: result.rows.length,
        hasMore: hasMore,
        lastTimestamp: lastTimestamp,
        serverTime: new Date().toISOString(),
        windowDays: diasNum
      }
    });
    
  } catch (err) {
    console.error('Error en sync incremental:', err);
    res.status(500).json({
      success: false,
      message: 'Error en sincronización',
      error: err.message
    });
  }
});

// POST - Sync bidireccional completo (push + pull en una llamada)
// Para usuarios normales: solo sincroniza ventana de 2 días
router.post('/sync/full', async (req, res) => {
  const db = req.app.get('db');
  const client = await db.getClient();
  
  try {
    const { 
      monitoreos_pendientes,
      last_sync_timestamp,
      usuario_id,
      dias // Ventana de días (default 2)
    } = req.body;
    
    if (!usuario_id) {
      return res.status(400).json({ 
        success: false, 
        message: 'Se requiere usuario_id' 
      });
    }
    
    const diasNum = parseInt(dias) || 2;
    
    console.log(`Sync full - usuario: ${usuario_id}, pendientes: ${monitoreos_pendientes?.length || 0}, ventana: ${diasNum} días`);
    
    await client.query('BEGIN');
    
    const resultados_push = [];
    let creados = 0, actualizados = 0, conflictos = 0, fallidos = 0, idempotentes = 0;
    
    // ========== FASE 1: PUSH (subir cambios locales) ==========
    if (monitoreos_pendientes && monitoreos_pendientes.length > 0) {
      for (const m of monitoreos_pendientes) {
        try {
          const isUpdate = m.pmmo_secuencia && m.pmmo_secuencia > 0;
          
          if (isUpdate) {
            // UPDATE: Registro existente
            const updateResult = await client.query(
              `UPDATE pm_monitoreos SET
                pmlt_codigo = COALESCE($2, pmlt_codigo),
                pmmo_casa = COALESCE($3, pmmo_casa),
                pmmo_cantero = COALESCE($4, pmmo_cantero),
                pmmo_canteros = COALESCE($5, pmmo_canteros),
                pmmo_variedad = COALESCE($6, pmmo_variedad),
                pmmo_idvariedad = COALESCE($7, pmmo_idvariedad),
                pmmo_grower = COALESCE($8, pmmo_grower),
                pmni_nombrecomun = COALESCE($9, pmni_nombrecomun),
                pmmo_cantidad = COALESCE($10, pmmo_cantidad),
                pmmo_cant_botada = $11,
                pmmo_comentarios = $12,
                pmmo_fecha = COALESCE($13, pmmo_fecha),
                pmmo_automatico = COALESCE($14, pmmo_automatico),
                pmmo_estatus = COALESCE($15, pmmo_estatus),
                pmmo_modificadopor = $16,
                pmmo_fechamodificacion = NOW(),
                pmmo_contenedor = COALESCE($17, pmmo_contenedor),
                pmni_id = COALESCE($18, pmni_id),
                pmmo_muestra1 = $19,
                pmmo_muestra2 = $20,
                pmmo_muestra3 = $21,
                pmmo_nivmuestraa1 = $22,
                pmmo_nivmuestraa2 = $23,
                pmmo_nivmuestraa3 = $24,
                pmmo_nivmuestram1 = $25,
                pmmo_nivmuestram2 = $26,
                pmmo_nivmuestram3 = $27,
                version = version + 1
              WHERE pmmo_secuencia = $1
                AND (version = $28 OR $28 IS NULL)
              RETURNING pmmo_secuencia, version`,
              [
                m.pmmo_secuencia,
                m.pmlt_codigo, m.pmmo_casa, m.pmmo_cantero, m.pmmo_canteros,
                m.pmmo_variedad, m.pmmo_idvariedad, m.pmmo_grower,
                m.pmni_nombrecomun, m.pmmo_cantidad, m.pmmo_cant_botada,
                m.pmmo_comentarios, m.pmmo_fecha, m.pmmo_automatico,
                m.pmmo_estatus, usuario_id, m.pmmo_contenedor, m.pmni_id,
                m.pmmo_muestra1, m.pmmo_muestra2, m.pmmo_muestra3,
                m.pmmo_nivmuestraa1, m.pmmo_nivmuestraa2, m.pmmo_nivmuestraa3,
                m.pmmo_nivmuestram1, m.pmmo_nivmuestram2, m.pmmo_nivmuestram3,
                m.expected_version !== undefined ? m.expected_version : null
              ]
            );
            
            if (updateResult.rows.length > 0) {
              resultados_push.push({
                success: true,
                operation: 'update',
                temp_id: m.temp_id,
                server_id: updateResult.rows[0].pmmo_secuencia,
                new_version: updateResult.rows[0].version,
                idempotency_key: m.idempotency_key
              });
              actualizados++;
            } else {
              // Conflicto de versión
              const currentVersion = await client.query(
                'SELECT version FROM pm_monitoreos WHERE pmmo_secuencia = $1',
                [m.pmmo_secuencia]
              );
              
              resultados_push.push({
                success: false,
                operation: 'update',
                conflict: true,
                temp_id: m.temp_id,
                server_id: m.pmmo_secuencia,
                message: 'Conflicto de versión - el registro fue modificado en el servidor',
                client_version: m.expected_version,
                server_version: currentVersion.rows[0]?.version,
                idempotency_key: m.idempotency_key
              });
              conflictos++;
            }
          } else {
            // INSERT: Nuevo registro
            // Verificar idempotency
            if (m.idempotency_key) {
              const existingCheck = await client.query(
                'SELECT pmmo_secuencia, version FROM pm_monitoreos WHERE idempotency_key = $1',
                [m.idempotency_key]
              );
              
              if (existingCheck.rows.length > 0) {
                resultados_push.push({
                  success: true,
                  operation: 'idempotent',
                  temp_id: m.temp_id,
                  server_id: existingCheck.rows[0].pmmo_secuencia,
                  new_version: existingCheck.rows[0].version,
                  idempotency_key: m.idempotency_key,
                  was_idempotent: true
                });
                idempotentes++;
                continue;
              }
            }
            
            // Insertar nuevo
            const insertResult = await client.query(
              `INSERT INTO pm_monitoreos (
                pmlt_codigo, pmmo_casa, pmmo_cantero, pmmo_canteros,
                pmmo_variedad, pmmo_idvariedad, pmmo_grower,
                pmni_nombrecomun, pmmo_cantidad, pmmo_cant_botada,
                pmmo_comentarios, pmmo_fecha, pmmo_automatico,
                pmmo_estatus, pmmo_creadopor, pmmo_contenedor, pmni_id,
                pmmo_muestra1, pmmo_muestra2, pmmo_muestra3,
                pmmo_nivmuestraa1, pmmo_nivmuestraa2, pmmo_nivmuestraa3,
                pmmo_nivmuestram1, pmmo_nivmuestram2, pmmo_nivmuestram3,
                idempotency_key, version, pmmo_fechacreacion
              ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
                $21, $22, $23, $24, $25, $26, $27, 1, NOW()
              )
              RETURNING pmmo_secuencia, version`,
              [
                m.pmlt_codigo, m.pmmo_casa, m.pmmo_cantero, m.pmmo_canteros,
                m.pmmo_variedad, m.pmmo_idvariedad, m.pmmo_grower,
                m.pmni_nombrecomun, m.pmmo_cantidad, m.pmmo_cant_botada,
                m.pmmo_comentarios, m.pmmo_fecha, 
                m.pmmo_automatico !== undefined ? m.pmmo_automatico : true,
                m.pmmo_estatus || 1, usuario_id, m.pmmo_contenedor || 'CONT_GENERAL', 
                m.pmni_id,
                m.pmmo_muestra1, m.pmmo_muestra2, m.pmmo_muestra3,
                m.pmmo_nivmuestraa1, m.pmmo_nivmuestraa2, m.pmmo_nivmuestraa3,
                m.pmmo_nivmuestram1, m.pmmo_nivmuestram2, m.pmmo_nivmuestram3,
                m.idempotency_key
              ]
            );
            
            resultados_push.push({
              success: true,
              operation: 'create',
              temp_id: m.temp_id,
              server_id: insertResult.rows[0].pmmo_secuencia,
              new_version: insertResult.rows[0].version,
              idempotency_key: m.idempotency_key,
              was_idempotent: false
            });
            creados++;
          }
        } catch (error) {
          console.error('Error procesando monitoreo en sync:', error);
          resultados_push.push({
            success: false,
            operation: m.pmmo_secuencia > 0 ? 'update' : 'create',
            temp_id: m.temp_id,
            error: error.message,
            idempotency_key: m.idempotency_key
          });
          fallidos++;
        }
      }
    }
    
    // ========== FASE 2: PULL (descargar cambios del servidor) ==========
    // Solo registros de los últimos N días
    let pullQuery;
    let pullParams;
    
    if (last_sync_timestamp) {
      pullQuery = `
        SELECT 
          pmmo_secuencia, pmlt_codigo, pmmo_casa, pmmo_cantero, pmmo_canteros,
          pmmo_variedad, pmmo_idvariedad, pmmo_grower, pmni_nombrecomun,
          pmmo_cantidad, pmmo_cant_botada, pmmo_comentarios, pmmo_fecha,
          pmmo_automatico, pmmo_estatus, pmmo_creadopor, pmmo_contenedor,
          pmni_id, pmmo_muestra1, pmmo_muestra2, pmmo_muestra3,
          pmmo_nivmuestraa1, pmmo_nivmuestraa2, pmmo_nivmuestraa3,
          pmmo_nivmuestram1, pmmo_nivmuestram2, pmmo_nivmuestram3,
          lmsupniv1, lmsupniv2, lmsupniv3, version, idempotency_key,
          pmmo_fechacreacion, pmmo_fechamodificacion,
          GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) as last_modified
        FROM pm_monitoreos
        WHERE pmmo_creadopor = $1
          AND pmmo_fecha >= (CURRENT_DATE - INTERVAL '${diasNum} days')
          AND GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) > $2
        ORDER BY last_modified ASC
        LIMIT 500
      `;
      pullParams = [usuario_id, last_sync_timestamp];
    } else {
      pullQuery = `
        SELECT 
          pmmo_secuencia, pmlt_codigo, pmmo_casa, pmmo_cantero, pmmo_canteros,
          pmmo_variedad, pmmo_idvariedad, pmmo_grower, pmni_nombrecomun,
          pmmo_cantidad, pmmo_cant_botada, pmmo_comentarios, pmmo_fecha,
          pmmo_automatico, pmmo_estatus, pmmo_creadopor, pmmo_contenedor,
          pmni_id, pmmo_muestra1, pmmo_muestra2, pmmo_muestra3,
          pmmo_nivmuestraa1, pmmo_nivmuestraa2, pmmo_nivmuestraa3,
          pmmo_nivmuestram1, pmmo_nivmuestram2, pmmo_nivmuestram3,
          lmsupniv1, lmsupniv2, lmsupniv3, version, idempotency_key,
          pmmo_fechacreacion, pmmo_fechamodificacion,
          GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion)) as last_modified
        FROM pm_monitoreos
        WHERE pmmo_creadopor = $1 
          AND pmmo_estatus = 1
          AND pmmo_fecha >= (CURRENT_DATE - INTERVAL '${diasNum} days')
        ORDER BY pmmo_fecha DESC
        LIMIT 500
      `;
      pullParams = [usuario_id];
    }
    
    const pullResult = await client.query(pullQuery, pullParams);
    
    await client.query('COMMIT');
    
    const serverTime = new Date().toISOString();
    
    console.log(`Sync full completado - push: ${creados} creados, ${actualizados} actualizados, ${idempotentes} idempotentes, ${conflictos} conflictos, ${fallidos} fallidos | pull: ${pullResult.rows.length} registros`);
    
    res.json({
      success: true,
      push: {
        results: resultados_push,
        summary: {
          total: monitoreos_pendientes?.length || 0,
          created: creados,
          updated: actualizados,
          idempotent: idempotentes,
          conflicts: conflictos,
          failed: fallidos
        }
      },
      pull: {
        data: pullResult.rows,
        count: pullResult.rows.length,
        hasMore: pullResult.rows.length === 500
      },
      meta: {
        serverTime: serverTime,
        lastTimestamp: pullResult.rows.length > 0 
          ? pullResult.rows[pullResult.rows.length - 1].last_modified 
          : serverTime,
        windowDays: diasNum
      }
    });
    
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error en sync full:', err);
    res.status(500).json({
      success: false,
      message: 'Error en sincronización completa',
      error: err.message
    });
  } finally {
    client.release();
  }
});

// GET - Estado de sincronización del usuario
router.get('/sync/status', async (req, res) => {
  try {
    const { usuario, dias } = req.query;
    
    if (!usuario) {
      return res.status(400).json({ 
        success: false, 
        message: 'Se requiere usuario' 
      });
    }
    
    const usuarioId = parseInt(usuario);
    const diasNum = parseInt(dias) || 2;
    const db = req.app.get('db');
    
    // Stats dentro de la ventana de días
    const statsResult = await db.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE pmmo_estatus = 1) as activos,
        MAX(GREATEST(pmmo_fechacreacion, COALESCE(pmmo_fechamodificacion, pmmo_fechacreacion))) as ultima_modificacion,
        MAX(version) as max_version
      FROM pm_monitoreos
      WHERE pmmo_creadopor = $1
        AND pmmo_fecha >= (CURRENT_DATE - INTERVAL '${diasNum} days')
    `, [usuarioId]);
    
    const stats = statsResult.rows[0];
    
    res.json({
      success: true,
      data: {
        usuario_id: usuarioId,
        window_days: diasNum,
        total_in_window: parseInt(stats.total),
        activos: parseInt(stats.activos),
        ultima_modificacion: stats.ultima_modificacion,
        max_version: parseInt(stats.max_version) || 0,
        serverTime: new Date().toISOString()
      }
    });
    
  } catch (err) {
    console.error('Error en sync status:', err);
    res.status(500).json({
      success: false,
      message: 'Error obteniendo estado de sincronización',
      error: err.message
    });
  }
});

module.exports = router;