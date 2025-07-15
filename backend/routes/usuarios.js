const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');

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

// GET - Obtener todos los usuarios usando stored procedure
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de usuarios con stored procedure');
    const { rol, estatus, busqueda } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const rolId = rol && rol !== 'Todos' ? parseInt(rol) : null;
    const estatusParam = estatus && estatus !== 'Todos' 
      ? (estatus === 'Activo' ? 1 : 0) 
      : null;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_usuarios($1, $2, $3)',
        [rolId, estatusParam, busqueda || null]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_usuarios($1, $2, $3)', 
        [rolId, estatusParam, busqueda || null]);
      throw queryError;
    }
    
    console.log(`Usuarios obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener usuarios:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los usuarios',
        error: err.message
      });
    }
  }
});

// GET - Obtener un usuario por ID usando stored procedure
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`Obteniendo usuario con ID: ${id}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_usuario_by_id($1)',
        [parseInt(id)]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_usuario_by_id($1)', [id]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Usuario con ID ${id} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    console.log(`Usuario con ID ${id} obtenido exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener usuario:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener el usuario',
        error: err.message
      });
    }
  }
});

// POST - Crear un nuevo usuario usando stored procedure
router.post('/', async (req, res) => {
  try {
    const { 
      codigo, 
      usuario, 
      funcion, 
      estatus, 
      password, 
      correo, 
      telefono,
      creador 
    } = req.body;
    
    console.log(`Iniciando creación de usuario: ${usuario} usando stored procedure`);
    
    // Validaciones básicas
    if (!usuario || !password || !funcion) {
      return res.status(400).json({
        success: false,
        message: 'Los campos usuario, contraseña y rol son obligatorios'
      });
    }
    
    // Obtener la configuración de seguridad desde la configuración centralizada
    const saltRounds = req.config?.security?.saltRounds || 10;
    
    // Hashear contraseña
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración (omitiendo la contraseña)
    console.log('Parámetros de creación:', {
      usuario,
      funcion: parseInt(funcion),
      codigo: codigo !== undefined ? parseInt(codigo) : 0,
      estatus: estatus !== undefined ? parseInt(estatus) : 1,
      correo: correo || null,
      telefono: telefono || null,
      creador: creador ? parseInt(creador) : 1
    });
    
    // Parámetros correctamente parseados
    const parsedFuncion = parseInt(funcion);
    const parsedCodigo = codigo !== undefined ? parseInt(codigo) : 0;
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedCreador = creador ? parseInt(creador) : 1;
    
    // Llamar al stored procedure para crear usuario con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_usuario($1, $2, $3, $4, $5, $6, $7, $8)',
        [
          usuario,               // usuario_param (obligatorio)
          parsedFuncion,         // funcion_param (obligatorio)
          hashedPassword,        // password_param (obligatorio)
          parsedCodigo,          // codigo_param (default 0)
          parsedEstatus,         // estatus_param (default 1)
          correo || null,        // correo_param (default null)
          telefono || null,      // telefono_param (default null)
          parsedCreador          // creador_param (default 1)
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_usuario($1, $2, $3, $4, $5, $6, $7, $8)', 
        [usuario, parsedFuncion, '[CONTRASEÑA PROTEGIDA]', parsedCodigo, parsedEstatus, 
        correo || null, telefono || null, parsedCreador]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el usuario'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, usuario_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear usuario: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Usuario creado exitosamente con ID: ${usuario_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: { id: usuario_id }
    });
  } catch (err) {
    console.error('Error al crear usuario:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear el usuario',
        error: err.message
      });
    }
  }
});

// PUT - Actualizar un usuario usando stored procedure
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      codigo, 
      usuario, 
      funcion, 
      estatus, 
      password, 
      correo, 
      telefono,
      modificador 
    } = req.body;
    
    console.log(`Iniciando actualización de usuario con ID: ${id} usando stored procedure`);
    
    // Validaciones básicas
    if (!usuario || !funcion) {
      return res.status(400).json({
        success: false,
        message: 'Los campos usuario y rol son obligatorios'
      });
    }
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Procesamiento de la contraseña
    let hashedPassword = null;
    if (password) {
      // Obtener la configuración de seguridad desde la configuración centralizada
      const saltRounds = req.config?.security?.saltRounds || 10;
      hashedPassword = await bcrypt.hash(password, saltRounds);
    }
    
    // Parsear correctamente los valores numéricos
    const parsedId = parseInt(id);
    const parsedFuncion = parseInt(funcion);
    const parsedCodigo = codigo !== undefined ? parseInt(codigo) : 0;
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : 1;
    const parsedModificador = modificador ? parseInt(modificador) : 1;
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      id: parsedId,
      usuario,
      funcion: parsedFuncion,
      codigo: parsedCodigo,
      estatus: parsedEstatus,
      password: password ? '[PROTEGIDO]' : null,
      correo,
      telefono,
      modificador: parsedModificador
    });
    
    // Llamar al stored procedure para actualizar usuario con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_usuario($1, $2, $3, $4, $5, $6, $7, $8, $9)',
        [
          parsedId,              // usuario_id (obligatorio)
          usuario,               // usuario_param (obligatorio)
          parsedFuncion,         // funcion_param (obligatorio)
          parsedCodigo,          // codigo_param (default 0)
          parsedEstatus,         // estatus_param (default 1)
          hashedPassword,        // password_param (default null)
          correo || null,        // correo_param (default null)
          telefono || null,      // telefono_param (default null)
          parsedModificador      // modificador_param (default 1)
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_usuario($1, $2, $3, $4, $5, $6, $7, $8, $9)', 
        [parsedId, usuario, parsedFuncion, parsedCodigo, parsedEstatus, 
        '[CONTRASEÑA PROTEGIDA]', correo || null, telefono || null, parsedModificador]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el usuario'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar usuario: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Usuario con ID ${id} actualizado exitosamente`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al actualizar usuario:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el usuario',
        error: err.message
      });
    }
  }
});

// DELETE - Eliminar un usuario (baja lógica) usando stored procedure
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    
    console.log(`Iniciando eliminación lógica del usuario con ID: ${parsedId} usando stored procedure`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para actualizar el estatus con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_usuario_status($1, $2, $3)',
        [parsedId, 0, 1] // ID del usuario, nuevo estatus (0 = inactivo), ID del modificador
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_usuario_status($1, $2, $3)', 
        [parsedId, 0, 1]);
      throw queryError;
    }
    
    if (result.rows[0].sp_update_usuario_status === false) {
      console.log(`Usuario con ID ${parsedId} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    console.log(`Usuario con ID: ${parsedId} eliminado lógicamente con éxito`);
    
    // Enviar respuesta
    return res.json({
      success: true,
      message: 'Usuario eliminado correctamente'
    });
  } catch (err) {
    console.error('Error al eliminar usuario:', err);
    
    // Asegurarse de que la respuesta se envíe incluso en caso de error
    if (!res.headersSent) {
      return res.status(500).json({
        success: false,
        message: 'Error al eliminar el usuario',
        error: err.message
      });
    }
  }
});

// GET - Obtener la lista de roles para el dropdown
router.get('/roles/lista', async (req, res) => {
  try {
    console.log('Iniciando obtención de roles para dropdown');
    // Usar el módulo db compartido con stored procedure
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query('SELECT * FROM sp_get_roles_dropdown()');
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_roles_dropdown()', []);
      throw queryError;
    }
    
    console.log(`Roles para dropdown obtenidos: ${result.rows.length}`);
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener roles:', err);
    // Asegurarse de que no se ha enviado ya una respuesta
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los roles',
        error: err.message
      });
    }
  }
});

// Ruta de login usando stored procedure
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    // Validar que se proporcionen credenciales
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Debe proporcionar usuario y contraseña'
      });
    }

    console.log(`Iniciando login para usuario: ${username} usando stored procedure`);

    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Buscar usuario con el stored procedure con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_usuario_login($1)', 
        [username]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_usuario_login($1)', [username]);
      throw queryError;
    }

    if (result.rows.length === 0) {
      console.log(`Usuario ${username} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }

    // Verificar contraseña
    const user = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password);
    
    if (!isPasswordValid) {
      console.log(`Contraseña incorrecta para usuario: ${username}`);
      return res.status(401).json({
        success: false,
        message: 'Contraseña incorrecta'
      });
    }

    // Verificar si el usuario está activo
    if (user.estatus !== 1) {
      console.log(`El usuario ${username} está inactivo`);
      return res.status(403).json({
        success: false,
        message: 'Usuario inactivo'
      });
    }

    console.log(`Login exitoso para usuario: ${username}`);
    
    // Inicio de sesión exitoso
    res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user: {
        id: user.usuario_id,
        username: user.usuario,
        rol: user.funcion
      }
    });
  } catch (error) {
    console.error('Error de inicio de sesión:', error);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error en el inicio de sesión',
        error: error.message
      });
    }
  }
});

module.exports = router;