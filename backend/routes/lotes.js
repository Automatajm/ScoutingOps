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

// GET - Obtener lista de variedades para dropdown usando stored procedure
router.get('/variedades/lista', async (req, res) => {
  try {
    console.log('Iniciando obtención de variedades para dropdown con stored procedure');
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_variedades_dropdown()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_variedades_dropdown()', []);
      throw queryError;
    }
    
    console.log(`Variedades para dropdown obtenidas: ${result.rows.length}`);
    
    res.json({
      success: true,
      data: result.rows
    });
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

// GET - Obtener todos los lotes con filtros opcionales usando stored procedure
// MODIFICADO: Ahora acepta codigo_variedad en lugar de variedad
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de lotes con stored procedure');
    const { codigo_variedad, estatus, busqueda } = req.query;
    
    // Convertir parámetros a tipos adecuados
    // El código de variedad ahora es un string, no un número
    const codigoVariedadParam = codigo_variedad && codigo_variedad !== 'Todos' ? codigo_variedad : null;
    const estatusParam = estatus && estatus !== 'Todos' 
      ? (estatus === 'Activo' ? 1 : 0) 
      : null;
    
    console.log('Parámetros de filtrado:', {
      codigo_variedad: codigoVariedadParam,
      estatus: estatusParam,
      busqueda: busqueda || null
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores - modificada para usar el código_variedad
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_lotes_by_codigo_variedad($1, $2, $3)',
        [codigoVariedadParam, estatusParam, busqueda || null]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_lotes_by_codigo_variedad($1, $2, $3)', 
        [codigoVariedadParam, estatusParam, busqueda || null]);
      throw queryError;
    }
    
    console.log(`Lotes obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener lotes:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los lotes',
        error: err.message
      });
    }
  }
});

// GET - Obtener un lote por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo lote con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_lote_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_lote_by_id($1)', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Lote con ID ${parsedId} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Lote no encontrado'
      });
    }
    
    console.log(`Lote con ID ${parsedId} obtenido exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener el lote',
        error: err.message
      });
    }
  }
});

// POST - Crear un nuevo lote usando stored procedure
// MODIFICADO: pmlt_idvariedad ahora se trata como el código de la variedad
router.post('/', async (req, res) => {
  try {
    const { 
      pmlt_codigo, 
      pmlt_canteros, 
      pmlt_cantidad, 
      pmlt_estatus, 
      pmlt_idvariedad, 
      pmlt_contenedor, 
      pmlt_grower, 
      pmlt_variedad, 
      pmlt_casa, 
      pmlt_creadopor 
    } = req.body;
    
    console.log(`Iniciando creación de lote: ${pmlt_codigo} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmlt_codigo) {
      return res.status(400).json({
        success: false,
        message: 'El código del lote es obligatorio'
      });
    }
    
    if (!pmlt_cantidad && pmlt_cantidad !== 0) {
      return res.status(400).json({
        success: false,
        message: 'La cantidad es obligatoria'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedCantidad = pmlt_cantidad !== undefined ? parseInt(pmlt_cantidad) : 0;
    const parsedEstatus = pmlt_estatus !== undefined ? parseInt(pmlt_estatus) : 1;
    // MODIFICADO: Ahora pmlt_idvariedad ya es el código, no necesitamos conversión especial
    const parsedIdvariedad = pmlt_idvariedad || null;
    const parsedCreadoPor = pmlt_creadopor ? parseInt(pmlt_creadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      codigo: pmlt_codigo,
      canteros: pmlt_canteros || null,
      cantidad: parsedCantidad,
      estatus: parsedEstatus,
      idvariedad: parsedIdvariedad, // Ahora este es el código
      contenedor: pmlt_contenedor || null,
      grower: pmlt_grower || null,
      variedad: pmlt_variedad || null,
      casa: pmlt_casa || null,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear lote con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_lote($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
        [
          pmlt_codigo,
          pmlt_canteros || null,
          parsedCantidad,
          parsedEstatus,
          parsedIdvariedad,
          pmlt_contenedor || null,
          pmlt_grower || null,
          pmlt_variedad || null,
          pmlt_casa || null,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_lote(...)', 
        [pmlt_codigo, pmlt_canteros, parsedCantidad, parsedEstatus, 
        parsedIdvariedad, pmlt_contenedor, pmlt_grower, pmlt_variedad, 
        pmlt_casa, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el lote'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, lote_data } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear lote: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Lote creado exitosamente`);
    res.status(201).json({
      success: true,
      message: message,
      data: lote_data
    });
  } catch (err) {
    console.error('Error al crear lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear el lote',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar un lote usando stored procedure
// MODIFICADO: pmlt_idvariedad ahora se trata como el código de la variedad
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const { 
      pmlt_codigo, 
      pmlt_canteros, 
      pmlt_cantidad, 
      pmlt_estatus, 
      pmlt_idvariedad, 
      pmlt_contenedor, 
      pmlt_grower, 
      pmlt_variedad, 
      pmlt_casa, 
      pmlt_modificadopor 
    } = req.body;
    
    console.log(`Iniciando actualización de lote con ID: ${parsedId} usando stored procedure`);
    
    // Validaciones básicas
    if (!pmlt_codigo) {
      return res.status(400).json({
        success: false,
        message: 'El código del lote es obligatorio'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedCantidad = pmlt_cantidad !== undefined ? parseInt(pmlt_cantidad) : 0;
    const parsedEstatus = pmlt_estatus !== undefined ? parseInt(pmlt_estatus) : 1;
    // MODIFICADO: Aquí también tratamos pmlt_idvariedad como un código directamente
    const parsedIdvariedad = pmlt_idvariedad || null;
    const parsedModificadoPor = pmlt_modificadopor ? parseInt(pmlt_modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      id: parsedId,
      codigo: pmlt_codigo,
      canteros: pmlt_canteros || null,
      cantidad: parsedCantidad,
      estatus: parsedEstatus,
      idvariedad: parsedIdvariedad, // Ahora este es el código
      contenedor: pmlt_contenedor || null,
      grower: pmlt_grower || null,
      variedad: pmlt_variedad || null,
      casa: pmlt_casa || null,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar lote con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_lote($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
        [
          parsedId,
          pmlt_codigo,
          pmlt_canteros || null,
          parsedCantidad,
          parsedEstatus,
          parsedIdvariedad,
          pmlt_contenedor || null,
          pmlt_grower || null,
          pmlt_variedad || null,
          pmlt_casa || null,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_lote(...)', 
        [parsedId, pmlt_codigo, pmlt_canteros, parsedCantidad, parsedEstatus, 
        parsedIdvariedad, pmlt_contenedor, pmlt_grower, pmlt_variedad, 
        pmlt_casa, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el lote'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, lote_data } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar lote: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Lote con ID ${parsedId} actualizado exitosamente`);
    res.json({
      success: true,
      message: message,
      data: lote_data
    });
  } catch (err) {
    console.error('Error al actualizar lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el lote',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar un lote (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica del lote con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar lote con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_lote($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_lote($1)', [parsedId]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar el lote'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrado')) {
        console.log(`Lote con ID ${parsedId} no encontrado`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar lote: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Lote con ID ${parsedId} eliminado lógicamente con éxito`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar lote:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar el lote',
        error: err.message
      });
    }
  }
});

// POST - Importar múltiples lotes (endpoint para importación masiva) usando stored procedure
router.post('/batch', async (req, res) => {
  try {
    const { lotes } = req.body;
    
    console.log(`Iniciando importación batch de ${lotes?.length || 0} lotes usando stored procedure`);
    
    if (!lotes || !Array.isArray(lotes) || lotes.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No se proporcionaron lotes para importar'
      });
    }
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para importación batch con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_import_lotes_batch($1)',
        [JSON.stringify(lotes)]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_import_lotes_batch($1)', ['[DATOS LOTES]']);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno en la importación de lotes'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, lotes_creados, errores } = result.rows[0];
    
    if (!success) {
      console.log(`Error en importación batch: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Importación batch completada: ${lotes_creados} lotes creados`);
    res.status(201).json({
      success: true,
      message: message,
      count: lotes_creados,
      errores: errores
    });
  } catch (err) {
    console.error('Error en importación batch de lotes:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error en la importación de lotes',
        error: err.message
      });
    }
  }
});

module.exports = router;