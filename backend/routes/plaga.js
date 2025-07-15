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

// GET - Obtener todas las plagas con filtros opcionales usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de plagas con stored procedure');
    const { tipo, estatus, busqueda } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? parseInt(estatus) : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      tipo: tipo || null,
      estatus: estatusParam,
      busqueda: busqueda || null
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_plagas($1, $2, $3)',
        [
          tipo || null, 
          estatusParam,
          busqueda || null
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_plagas($1, $2, $3)', 
        [tipo || null, estatusParam, busqueda || null]);
      throw queryError;
    }
    
    console.log(`Plagas obtenidas: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener plagas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener las plagas',
        error: err.message
      });
    }
  }
});

// GET - Obtener tipos de plagas usando stored procedure
router.get('/tipos', async (req, res) => {
  try {
    console.log('Iniciando obtención de tipos de plagas con stored procedure');
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_tipos_plagas()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_tipos_plagas()', []);
      throw queryError;
    }
    
    console.log(`Tipos de plagas obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener tipos de plagas:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los tipos de plagas',
        error: err.message
      });
    }
  }
});

// GET - Obtener una plaga por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo plaga con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_plaga_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_plaga_by_id($1)', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Plaga con ID ${parsedId} no encontrada`);
      return res.status(404).json({
        success: false,
        message: 'Plaga no encontrada'
      });
    }
    
    console.log(`Plaga con ID ${parsedId} obtenida exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener plaga:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener la plaga',
        error: err.message
      });
    }
  }
});

// POST - Crear una nueva plaga usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      pmpl_nombrecomun, 
      pmpl_genero, 
      pmpl_familia, 
      pmpl_tipo, 
      pmpl_estatus, 
      pmpl_creadopor 
    } = req.body;
    
    console.log(`Iniciando creación de plaga: ${pmpl_nombrecomun} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmpl_nombrecomun) {
      return res.status(400).json({
        success: false,
        message: 'El nombre común de la plaga es obligatorio'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = pmpl_estatus !== undefined ? parseInt(pmpl_estatus) : 1;
    const parsedCreadoPor = pmpl_creadopor ? parseInt(pmpl_creadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      nombrecomun: pmpl_nombrecomun,
      genero: pmpl_genero || null,
      familia: pmpl_familia || null,
      tipo: pmpl_tipo || null,
      estatus: parsedEstatus,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear plaga con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_plaga($1, $2, $3, $4, $5, $6)',
        [
          pmpl_nombrecomun,
          pmpl_genero || null,
          pmpl_familia || null,
          pmpl_tipo || null,
          parsedEstatus,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_plaga($1, $2, $3, $4, $5, $6)', 
        [pmpl_nombrecomun, pmpl_genero || null, pmpl_familia || null, pmpl_tipo || null, parsedEstatus, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear la plaga'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, plaga_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear plaga: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    // Obtener la plaga recién creada para devolver datos completos
    let plagaResult;
    try {
      plagaResult = await db.query(
        'SELECT * FROM sp_get_plaga_by_id($1)',
        [plaga_id]
      );
    } catch (queryError) {
      // Si falla al obtener la plaga, igual reportamos éxito pero sin datos completos
      console.log(`Advertencia: No se pudo obtener la plaga recién creada con ID ${plaga_id}`);
      
      return res.status(201).json({
        success: true,
        message: message,
        data: { pmpl_id: plaga_id }
      });
    }
    
    console.log(`Plaga creada exitosamente con ID: ${plaga_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: plagaResult.rows[0] || { pmpl_id: plaga_id }
    });
  } catch (err) {
    console.error('Error al crear plaga:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear la plaga',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar una plaga usando stored procedure
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const { 
      pmpl_nombrecomun, 
      pmpl_genero, 
      pmpl_familia, 
      pmpl_tipo, 
      pmpl_estatus, 
      pmpl_modificadopor 
    } = req.body;
    
    console.log(`Iniciando actualización de plaga con ID: ${parsedId} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmpl_nombrecomun) {
      return res.status(400).json({
        success: false,
        message: 'El nombre común de la plaga es obligatorio'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = pmpl_estatus !== undefined ? parseInt(pmpl_estatus) : null;
    const parsedModificadoPor = pmpl_modificadopor ? parseInt(pmpl_modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      id: parsedId,
      nombrecomun: pmpl_nombrecomun,
      genero: pmpl_genero || null,
      familia: pmpl_familia || null,
      tipo: pmpl_tipo || null,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar plaga con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_plaga($1, $2, $3, $4, $5, $6, $7)',
        [
          parsedId,
          pmpl_nombrecomun,
          pmpl_genero || null,
          pmpl_familia || null,
          pmpl_tipo || null,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_plaga($1, $2, $3, $4, $5, $6, $7)', 
        [parsedId, pmpl_nombrecomun, pmpl_genero || null, pmpl_familia || null, pmpl_tipo || null, parsedEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar la plaga'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, plaga_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar plaga: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    // Obtener la plaga actualizada para devolver datos completos
    let plagaResult;
    try {
      plagaResult = await db.query(
        'SELECT * FROM sp_get_plaga_by_id($1)',
        [plaga_id]
      );
    } catch (queryError) {
      // Si falla al obtener la plaga, igual reportamos éxito pero sin datos completos
      console.log(`Advertencia: No se pudo obtener la plaga actualizada con ID ${plaga_id}`);
      
      return res.json({
        success: true,
        message: message
      });
    }
    
    console.log(`Plaga con ID ${parsedId} actualizada exitosamente`);
    res.json({
      success: true,
      message: message,
      data: plagaResult.rows[0] || { pmpl_id: plaga_id }
    });
  } catch (err) {
    console.error('Error al actualizar plaga:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar la plaga',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar una plaga (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica de la plaga con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar plaga con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_plaga($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_plaga($1)', [parsedId]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar la plaga'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrada')) {
        console.log(`Plaga con ID ${parsedId} no encontrada`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar plaga: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Plaga con ID ${parsedId} eliminada lógicamente con éxito`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar plaga:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar la plaga',
        error: err.message
      });
    }
  }
});

module.exports = router;