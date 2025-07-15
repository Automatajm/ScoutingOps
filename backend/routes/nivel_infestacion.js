const express = require('express');
const router = express.Router();

// Función auxiliar para loguear errores de consulta
const logQueryError = (error, query, params) => {
  console.error('Error en consulta:', {
    text: query,
    params: params,
    duration: error.duration,
    error: error.message
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

// GET - Obtener niveles de infestación por plaga usando stored procedure
router.get('/plaga/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo niveles de infestación para plaga ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_niveles_por_plaga($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_niveles_por_plaga($1)', [parsedId]);
      throw queryError;
    }
    
    console.log(`Niveles de infestación obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener niveles de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los niveles de infestación',
        error: err.message
      });
    }
  }
});

// GET - Obtener límites generales para niveles de infestación usando stored procedure
router.get('/limites', async (req, res) => {
  try {
    console.log('Obteniendo límites de niveles de infestación usando stored procedure');
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_limites_niveles()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_limites_niveles()', []);
      throw queryError;
    }
    
    // Siempre debería devolver una fila con valores por defecto
    console.log('Límites obtenidos:', result.rows[0]);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener límites de niveles:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener límites de niveles',
        error: err.message
      });
    }
  }
});

// GET - Obtener un nivel de infestación por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo nivel de infestación con secuencia: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_nivel_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_nivel_by_id($1)', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Nivel de infestación con secuencia ${parsedId} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Nivel de infestación no encontrado'
      });
    }
    
    console.log(`Nivel de infestación con secuencia ${parsedId} obtenido exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener nivel de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener el nivel de infestación',
        error: err.message
      });
    }
  }
});

// POST - Crear un nuevo nivel de infestación usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      pmni_nivel,
      pmni_plaga,
      pmni_nombrecomun,
      pmni_rango,
      pmni_lminferior,
      pmni_lmsuperior,
      pmni_tipoobservacion,
      pmni_observacion,
      pmni_cintaidentificadora,
      pmni_estatus,
      pmni_creadopor
    } = req.body;
    
    console.log(`Iniciando creación de nivel de infestación ${pmni_nivel} para plaga ${pmni_plaga} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmni_nivel || !pmni_plaga || !pmni_nombrecomun || !pmni_rango) {
      return res.status(400).json({
        success: false,
        message: 'Nivel, plaga, nombre común y rango son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedNivel = parseInt(pmni_nivel);
    const parsedPlaga = parseInt(pmni_plaga);
    const parsedLimInf = pmni_lminferior !== undefined ? parseInt(pmni_lminferior) : 0;
    const parsedLimSup = pmni_lmsuperior !== undefined ? parseInt(pmni_lmsuperior) : 0;
    const parsedEstatus = pmni_estatus !== undefined ? parseInt(pmni_estatus) : 1;
    const parsedCreadoPor = pmni_creadopor ? parseInt(pmni_creadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      nivel: parsedNivel,
      plaga: parsedPlaga,
      nombrecomun: pmni_nombrecomun,
      rango: pmni_rango,
      lminferior: parsedLimInf,
      lmsuperior: parsedLimSup,
      tipoobservacion: pmni_tipoobservacion || null,
      observacion: pmni_observacion || null,
      cintaidentificadora: pmni_cintaidentificadora || null,
      estatus: parsedEstatus,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear nivel con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_nivel($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
        [
          parsedNivel,
          parsedPlaga,
          pmni_nombrecomun,
          pmni_rango,
          parsedLimInf,
          parsedLimSup,
          pmni_tipoobservacion || null,
          pmni_observacion || null,
          pmni_cintaidentificadora || null,
          parsedEstatus,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_nivel($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)', 
        [parsedNivel, parsedPlaga, pmni_nombrecomun, pmni_rango, parsedLimInf, parsedLimSup, 
          pmni_tipoobservacion || null, pmni_observacion || null, pmni_cintaidentificadora || null, 
          parsedEstatus, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el nivel de infestación'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, nivel_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear nivel de infestación: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    // Obtener el nivel recién creado para devolver datos completos
    let nivelResult;
    try {
      nivelResult = await db.query(
        'SELECT * FROM sp_get_nivel_by_id($1)',
        [nivel_id]
      );
    } catch (queryError) {
      // Si falla al obtener el nivel, igual reportamos éxito pero sin datos completos
      console.log(`Advertencia: No se pudo obtener el nivel recién creado con secuencia ${nivel_id}`);
      
      return res.status(201).json({
        success: true,
        message: message,
        data: { pmni_secuencia: nivel_id }
      });
    }
    
    console.log(`Nivel de infestación creado exitosamente con secuencia: ${nivel_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: nivelResult.rows[0] || { pmni_secuencia: nivel_id }
    });
  } catch (err) {
    console.error('Error al crear nivel de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear el nivel de infestación',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar un nivel de infestación usando stored procedure
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const { 
      pmni_rango,
      pmni_lminferior,
      pmni_lmsuperior,
      pmni_tipoobservacion,
      pmni_observacion,
      pmni_cintaidentificadora,
      pmni_estatus,
      pmni_modificadopor
    } = req.body;
    
    console.log(`Iniciando actualización de nivel de infestación con secuencia: ${parsedId} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmni_rango) {
      return res.status(400).json({
        success: false,
        message: 'El rango es obligatorio'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedLimInf = pmni_lminferior !== undefined ? parseInt(pmni_lminferior) : null;
    const parsedLimSup = pmni_lmsuperior !== undefined ? parseInt(pmni_lmsuperior) : null;
    const parsedEstatus = pmni_estatus !== undefined ? parseInt(pmni_estatus) : null;
    const parsedModificadoPor = pmni_modificadopor ? parseInt(pmni_modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      secuencia: parsedId,
      rango: pmni_rango,
      lminferior: parsedLimInf,
      lmsuperior: parsedLimSup,
      tipoobservacion: pmni_tipoobservacion || null,
      observacion: pmni_observacion || null,
      cintaidentificadora: pmni_cintaidentificadora || null,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar nivel con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_nivel($1, $2, $3, $4, $5, $6, $7, $8, $9)',
        [
          parsedId,
          pmni_rango,
          parsedLimInf,
          parsedLimSup,
          pmni_tipoobservacion || null,
          pmni_observacion || null,
          pmni_cintaidentificadora || null,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_nivel($1, $2, $3, $4, $5, $6, $7, $8, $9)', 
        [parsedId, pmni_rango, parsedLimInf, parsedLimSup, pmni_tipoobservacion || null, 
          pmni_observacion || null, pmni_cintaidentificadora || null, parsedEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el nivel de infestación'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, nivel_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar nivel de infestación: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    // Obtener el nivel actualizado para devolver datos completos
    let nivelResult;
    try {
      nivelResult = await db.query(
        'SELECT * FROM sp_get_nivel_by_id($1)',
        [nivel_id]
      );
    } catch (queryError) {
      // Si falla al obtener el nivel, igual reportamos éxito pero sin datos completos
      console.log(`Advertencia: No se pudo obtener el nivel actualizado con secuencia ${nivel_id}`);
      
      return res.json({
        success: true,
        message: message
      });
    }
    
    console.log(`Nivel de infestación con secuencia ${parsedId} actualizado exitosamente`);
    res.json({
      success: true,
      message: message,
      data: nivelResult.rows[0] || { pmni_secuencia: nivel_id }
    });
  } catch (err) {
    console.error('Error al actualizar nivel de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el nivel de infestación',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar un nivel de infestación (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica del nivel de infestación con secuencia: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar nivel con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_nivel($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_nivel($1)', [parsedId]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar el nivel de infestación'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrado')) {
        console.log(`Nivel de infestación con secuencia ${parsedId} no encontrado`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar nivel de infestación: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Nivel de infestación con secuencia ${parsedId} eliminado lógicamente con éxito`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar nivel de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar el nivel de infestación',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar todos los niveles de una plaga usando stored procedure
router.delete('/plaga/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica de todos los niveles para plaga ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar niveles por plaga con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_niveles_por_plaga($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_niveles_por_plaga($1)', [parsedId]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar los niveles de infestación'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, count } = result.rows[0];
    
    if (!success) {
      if (message.includes('No hay niveles')) {
        console.log(`No hay niveles de infestación activos para la plaga ${parsedId}`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar niveles de infestación: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`${count} niveles de infestación eliminados lógicamente con éxito para plaga ID ${parsedId}`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar niveles de infestación:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar los niveles de infestación',
        error: err.message
      });
    }
  }
});

module.exports = router;