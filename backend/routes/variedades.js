const express = require('express');
const router = express.Router();

// Función auxiliar para loguear errores de consulta (reutilizada del módulo de usuarios)
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

// GET - Obtener todas las variedades con filtros opcionales usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de variedades con stored procedure');
    const { busqueda, estatus } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus ? parseInt(estatus) : null;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_variedades($1, $2)',
        [busqueda || null, estatusParam]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_variedades($1, $2)', 
        [busqueda || null, estatusParam]);
      throw queryError;
    }
    
    console.log(`Variedades obtenidas: ${result.rows.length}`);
    res.json(result.rows);
  } catch (err) {
    console.error('Error al obtener variedades:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener las variedades',
        error: err.message
      });
    }
  }
});

// GET - Obtener una variedad por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo variedad con ID: ${parsedId}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_variedad_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_variedad_by_id($1)', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Variedad con ID ${parsedId} no encontrada`);
      return res.status(404).json({
        success: false,
        message: 'Variedad no encontrada'
      });
    }
    
    console.log(`Variedad con ID ${parsedId} obtenida exitosamente`);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error al obtener variedad:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener la variedad',
        error: err.message
      });
    }
  }
});

// POST - Crear una nueva variedad usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      codigo, 
      descripcion, 
      responsable,
      estatus, 
      creadoPor 
    } = req.body;
    
    console.log(`Iniciando creación de variedad: ${codigo} - ${descripcion} usando stored procedure`);
    
    // Validaciones básicas
    if (!codigo || !descripcion) {
      return res.status(400).json({
        success: false,
        message: 'Los campos código y descripción son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedCreadoPor = creadoPor ? parseInt(creadoPor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      codigo,
      descripcion,
      responsable: responsable || null,
      estatus: parsedEstatus,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear variedad con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_variedad($1, $2, $3, $4, $5)',
        [
          codigo,
          descripcion,
          responsable || null,
          parsedEstatus,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_variedad($1, $2, $3, $4, $5)', 
        [codigo, descripcion, responsable || null, parsedEstatus, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear la variedad'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, variedad_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear variedad: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Variedad creada exitosamente con ID: ${variedad_id}`);
    res.status(201).json(variedad_id);
  } catch (err) {
    console.error('Error al crear variedad:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear la variedad',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar una variedad usando stored procedure
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const { 
      codigo, 
      descripcion, 
      responsable,
      estatus, 
      modificadoPor 
    } = req.body;
    
    console.log(`Iniciando actualización de variedad con ID: ${parsedId} usando stored procedure`);
    
    // Validaciones básicas
    if (!codigo || !descripcion) {
      return res.status(400).json({
        success: false,
        message: 'Los campos código y descripción son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedModificadoPor = modificadoPor ? parseInt(modificadoPor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      id: parsedId,
      codigo,
      descripcion,
      responsable: responsable || null,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar variedad con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_variedad($1, $2, $3, $4, $5, $6)',
        [
          parsedId,
          codigo,
          descripcion,
          responsable || null,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_variedad($1, $2, $3, $4, $5, $6)', 
        [parsedId, codigo, descripcion, responsable || null, parsedEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar la variedad'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar variedad: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Variedad con ID ${parsedId} actualizada exitosamente`);
    res.json(true);
  } catch (err) {
    console.error('Error al actualizar variedad:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar la variedad',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar una variedad (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica de la variedad con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar variedad con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_variedad($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_variedad($1)', [parsedId]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar la variedad'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrada')) {
        console.log(`Variedad con ID ${parsedId} no encontrada`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar variedad: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Variedad con ID ${parsedId} eliminada lógicamente con éxito`);
    res.json(true);
  } catch (err) {
    console.error('Error al eliminar variedad:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar la variedad',
        error: err.message
      });
    }
  }
});

module.exports = router;