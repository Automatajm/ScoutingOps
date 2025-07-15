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

// GET - Obtener todos los roles usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de roles con stored procedure');
    const { busqueda } = req.query;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_roles($1)',
        [busqueda || null]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_roles($1)', [busqueda || null]);
      throw queryError;
    }
    
    console.log(`Roles obtenidos: ${result.rows.length}`);
    res.json(result.rows);
  } catch (err) {
    console.error('Error al obtener roles:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los roles',
        error: err.message
      });
    }
  }
});

// GET - Obtener lista simple de roles para dropdown (ya está usando sp)
router.get('/dropdown', async (req, res) => {
  try {
    console.log('Obteniendo lista simple de roles para dropdown');
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_roles_dropdown()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_roles_dropdown()', []);
      throw queryError;
    }
    
    console.log(`Dropdown roles obtenidos: ${result.rows.length}`);
    res.json(result.rows);
  } catch (err) {
    console.error('Error al obtener dropdown de roles:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener la lista de roles',
        error: err.message
      });
    }
  }
});

// GET - Obtener un rol por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Obteniendo rol con ID: ${parsedId}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_rol_by_id($1)',
        [parsedId]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_rol_by_id($1)', [parsedId]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Rol con ID ${parsedId} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Rol no encontrado'
      });
    }
    
    console.log(`Rol con ID ${parsedId} obtenido exitosamente`);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error al obtener rol:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener el rol',
        error: err.message
      });
    }
  }
});

// POST - Crear un nuevo rol usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      descripcion, 
      estatus, 
      creadoPor 
    } = req.body;
    
    console.log(`Iniciando creación de rol: "${descripcion}" usando stored procedure`);
    
    // Validaciones básicas
    if (!descripcion) {
      return res.status(400).json({
        success: false,
        message: 'El campo descripción es obligatorio'
      });
    }
    
    // Parsear parámetros
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedCreadoPor = creadoPor ? parseInt(creadoPor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      descripcion,
      estatus: parsedEstatus,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear rol
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_rol($1, $2, $3)',
        [
          descripcion,
          parsedEstatus,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_rol($1, $2, $3)', 
        [descripcion, parsedEstatus, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el rol'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, rol_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear rol: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Rol creado exitosamente con ID: ${rol_id}`);
    res.status(201).json(rol_id);
  } catch (err) {
    console.error('Error al crear rol:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear el rol',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar un rol usando stored procedure
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    const { 
      descripcion, 
      estatus, 
      modificadoPor 
    } = req.body;
    
    console.log(`Iniciando actualización de rol con ID: ${parsedId} usando stored procedure`);
    
    // Validaciones básicas
    if (!descripcion) {
      return res.status(400).json({
        success: false,
        message: 'El campo descripción es obligatorio'
      });
    }
    
    // Parsear parámetros
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedModificadoPor = modificadoPor ? parseInt(modificadoPor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      id: parsedId,
      descripcion,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar rol
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_rol($1, $2, $3, $4)',
        [
          parsedId,
          descripcion,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_rol($1, $2, $3, $4)', 
        [parsedId, descripcion, parsedEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el rol'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar rol: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Rol con ID ${parsedId} actualizado exitosamente`);
    res.json(true);
  } catch (err) {
    console.error('Error al actualizar rol:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el rol',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar un rol (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica del rol con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar rol
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_rol($1, $2)',
        [parsedId, 1] // ID del rol, ID del modificador (1 por defecto)
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_rol($1, $2)', [parsedId, 1]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar el rol'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      console.log(`Error al eliminar rol: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Rol con ID: ${parsedId} eliminado lógicamente con éxito`);
    return res.json(true);
  } catch (err) {
    console.error('Error al eliminar rol:', err);
    if (!res.headersSent) {
      return res.status(500).json({
        success: false,
        message: 'Error al eliminar el rol',
        error: err.message
      });
    }
  }
});

module.exports = router;