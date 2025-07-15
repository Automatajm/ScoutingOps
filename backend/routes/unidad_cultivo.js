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

// GET - Obtener todas las unidades de cultivo con filtros opcionales usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de unidades de cultivo con stored procedure');
    const { busqueda, estatus } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? parseInt(estatus) : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      busqueda: busqueda || null,
      estatus: estatusParam
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_unidades_cultivo($1, $2)',
        [
          busqueda || null, 
          estatusParam
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_unidades_cultivo($1, $2)', 
        [busqueda || null, estatusParam]);
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

// POST - Crear una nueva unidad de cultivo usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      codigo, 
      cantero, 
      id,
      estatus, 
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
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      codigo,
      cantero,
      id: parsedId,
      estatus: parsedEstatus,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear unidad de cultivo con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_unidad_cultivo($1, $2, $3, $4, $5)',
        [
          codigo,
          cantero,
          parsedId,
          parsedEstatus,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_unidad_cultivo($1, $2, $3, $4, $5)', 
        [codigo, cantero, parsedId, parsedEstatus, parsedCreadoPor]);
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
    const { success, message, unidad_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear unidad de cultivo: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Unidad de cultivo creada exitosamente con ID: ${unidad_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: { secuencia: unidad_id }
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

// PUT - Actualizar una unidad de cultivo usando stored procedure
router.put('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    const { 
      codigo, 
      cantero, 
      id,
      estatus, 
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
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      secuencia: parsedSecuencia,
      codigo,
      cantero,
      id: parsedId,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar unidad de cultivo con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_unidad_cultivo($1, $2, $3, $4, $5, $6)',
        [
          parsedSecuencia,
          codigo,
          cantero,
          parsedId,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_unidad_cultivo($1, $2, $3, $4, $5, $6)', 
        [parsedSecuencia, codigo, cantero, parsedId, parsedEstatus, parsedModificadoPor]);
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