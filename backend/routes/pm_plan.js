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

// ===============================================
// GET - Obtener todos los planes con filtros opcionales
// ===============================================
router.get('/', async (req, res) => {
  try {
    console.log('Iniciando obtención de planes con stored procedure');
    const { ubicacion, estado_planificacion, estatus, busqueda } = req.query;
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? estatus : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      ubicacion: ubicacion || null,
      estado_planificacion: estado_planificacion || null,
      estatus: estatusParam,
      busqueda: busqueda || null
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_planes($1, $2, $3, $4)',
        [
          ubicacion || null,
          estado_planificacion || null,
          estatusParam,
          busqueda || null
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_planes($1, $2, $3, $4)', 
        [ubicacion || null, estado_planificacion || null, estatusParam, busqueda || null]);
      throw queryError;
    }
    
    console.log(`Planes obtenidos: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener planes:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener los planes',
        error: err.message
      });
    }
  }
});

// ===============================================
// GET - Obtener unidades de cultivo disponibles para planificar
// ===============================================
router.get('/unidades-disponibles', async (req, res) => {
  try {
    console.log('Iniciando obtención de unidades disponibles para planificar');
    const { ubicacion, busqueda, estatus } = req.query;
    
    // Validar ubicación requerida
    if (!ubicacion) {
      return res.status(400).json({
        success: false,
        message: 'La ubicación es obligatoria'
      });
    }
    
    // Convertir parámetros a tipos adecuados
    const estatusParam = estatus !== undefined ? estatus : null;
    
    // Log para depuración
    console.log('Parámetros recibidos:', {
      ubicacion,
      busqueda: busqueda || null,
      estatus: estatusParam
    });
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_unidades_disponibles_planificar($1, $2, $3)',
        [
          ubicacion,
          busqueda || null,
          estatusParam
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_unidades_disponibles_planificar($1, $2, $3)', 
        [ubicacion, busqueda || null, estatusParam]);
      throw queryError;
    }
    
    console.log(`Unidades disponibles obtenidas: ${result.rows.length}`);
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener unidades disponibles:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener las unidades disponibles',
        error: err.message
      });
    }
  }
});

// ===============================================
// PUT - Actualización masiva de estado de planificación CON FILTRO DE CÓDIGOS
// ===============================================
router.put('/actualizar-masivo', async (req, res) => {
  try {
    const { 
      nuevo_estado,
      ubicacion,
      estado_planificacion,
      estatus,
      busqueda,
      codigos, // ← NUEVO PARÁMETRO para filtrar por códigos específicos
      modificadopor
    } = req.body;
    
    console.log(`Iniciando actualización masiva a estado: ${nuevo_estado}`);
    
    // Log del nuevo parámetro de códigos
    if (codigos && Array.isArray(codigos) && codigos.length > 0) {
      console.log(`Filtro de códigos aplicado: ${codigos.join(', ')} (${codigos.length} códigos)`);
    }
    
    // Validaciones básicas
    if (!nuevo_estado) {
      return res.status(400).json({
        success: false,
        message: 'El nuevo estado de planificación es obligatorio'
      });
    }
    
    // Validar que el estado sea válido
    const estadosValidos = ['Planificado', 'En proceso', 'Ejecutado'];
    if (!estadosValidos.includes(nuevo_estado)) {
      return res.status(400).json({
        success: false,
        message: 'Estado de planificación no válido. Use: Planificado, En proceso, Ejecutado'
      });
    }
    
    // Validar que codigos sea un array si está presente
    if (codigos !== undefined && codigos !== null) {
      if (!Array.isArray(codigos)) {
        return res.status(400).json({
          success: false,
          message: 'El parámetro códigos debe ser un array'
        });
      }
      
      // Validar que todos los elementos sean strings no vacíos
      const codigosInvalidos = codigos.some(codigo => 
        typeof codigo !== 'string' || codigo.trim() === ''
      );
      
      if (codigosInvalidos) {
        return res.status(400).json({
          success: false,
          message: 'Todos los códigos deben ser strings no vacíos'
        });
      }
    }
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : null;
    const parsedModificadoPor = modificadopor ? parseInt(modificadopor) : 1;
    
    // Convertir array de códigos a JSON si está presente y no está vacío
    const codigosJson = (codigos && Array.isArray(codigos) && codigos.length > 0) 
      ? JSON.stringify(codigos) 
      : null;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Log para depuración con el nuevo parámetro
    console.log('Parámetros de actualización masiva:', {
      nuevo_estado,
      ubicacion: ubicacion || null,
      estado_planificacion: estado_planificacion || null,
      estatus: parsedEstatus,
      busqueda: busqueda || null,
      codigos: codigosJson ? `JSON con ${codigos.length} códigos` : null,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure ACTUALIZADO para actualización masiva (ahora con 7 parámetros)
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_planes_masivo($1, $2, $3, $4, $5, $6, $7)',
        [
          nuevo_estado,
          ubicacion || null,
          estado_planificacion || null,
          parsedEstatus,
          busqueda || null,
          codigosJson, // ← NUEVO PARÁMETRO: JSON con array de códigos
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_planes_masivo($1, $2, $3, $4, $5, $6, $7)', 
        [nuevo_estado, ubicacion || null, estado_planificacion || null, parsedEstatus, busqueda || null, codigosJson, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar los planes'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, planes_actualizados } = result.rows[0];
    
    if (!success) {
      console.log(`Error en actualización masiva: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    // Log de éxito con información sobre códigos
    let successMessage = `Actualización masiva exitosa: ${planes_actualizados} planes actualizados`;
    if (codigosJson) {
      successMessage += ` (filtrados por ${codigos.length} códigos específicos)`;
    }
    console.log(successMessage);
    
    res.json({
      success: true,
      message: message,
      data: { 
        planes_actualizados: planes_actualizados,
        codigos_aplicados: codigos ? codigos.length : 0
      }
    });
  } catch (err) {
    console.error('Error en actualización masiva:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar los planes masivamente',
        error: err.message
      });
    }
  }
});

// ===============================================
// PUT - Actualizar estatus del INVERNADERO (unidad de cultivo) desde un plan
// ===============================================
router.put('/actualizar-invernadero', async (req, res) => {
  try {
    const { 
      unidad_codigo,
      ubicacion,
      nuevo_estatus, // Opcional: si no se envía, hace toggle automático
      modificadopor
    } = req.body;
    
    console.log(`Iniciando actualización de estatus del invernadero para unidad: ${unidad_codigo}`);
    
    // Validaciones básicas
    if (!unidad_codigo) {
      return res.status(400).json({
        success: false,
        message: 'El código de unidad es obligatorio'
      });
    }
    
    if (!ubicacion) {
      return res.status(400).json({
        success: false,
        message: 'La ubicación es obligatoria'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedNuevoEstatus = nuevo_estatus !== undefined ? parseInt(nuevo_estatus) : null;
    const parsedModificadoPor = modificadopor ? parseInt(modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Log para depuración
    console.log('Parámetros de actualización de invernadero:', {
      unidad_codigo,
      ubicacion,
      nuevo_estatus: parsedNuevoEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar estatus del invernadero
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_unidad_estatus_from_plan($1, $2, $3, $4)',
        [
          unidad_codigo,
          ubicacion,
          parsedNuevoEstatus, // null = toggle automático
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_unidad_estatus_from_plan($1, $2, $3, $4)', 
        [unidad_codigo, ubicacion, parsedNuevoEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el estatus del invernadero'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, estatus_anterior, estatus_nuevo } = result.rows[0];
    
    if (!success) {
      console.log(`Error al actualizar estatus del invernadero: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Estatus del invernadero actualizado exitosamente: ${estatus_anterior} → ${estatus_nuevo}`);
    res.json({
      success: true,
      message: message,
      data: { 
        unidad_codigo: unidad_codigo,
        estatus_anterior: estatus_anterior,
        estatus_nuevo: estatus_nuevo
      }
    });
  } catch (err) {
    console.error('Error al actualizar estatus del invernadero:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el estatus del invernadero',
        error: err.message
      });
    }
  }
});

// ===============================================
// GET - Obtener un plan por secuencia
// ===============================================
router.get('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    console.log(`Obteniendo plan con secuencia: ${parsedSecuencia}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Query con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_get_plan_by_id($1)',
        [parsedSecuencia]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_get_plan_by_id($1)', [parsedSecuencia]);
      throw queryError;
    }
    
    if (result.rows.length === 0) {
      console.log(`Plan con secuencia ${parsedSecuencia} no encontrado`);
      return res.status(404).json({
        success: false,
        message: 'Plan no encontrado'
      });
    }
    
    console.log(`Plan con secuencia ${parsedSecuencia} obtenido exitosamente`);
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error al obtener plan:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al obtener el plan',
        error: err.message
      });
    }
  }
});

// ===============================================
// POST - Crear un nuevo plan
// ===============================================
router.post('/', async (req, res) => {
  try {
    const { 
      unidad_codigo, 
      unidad_cantero, 
      ubicacion,
      creadopor 
    } = req.body;
    
    console.log(`Iniciando creación de plan: ${unidad_codigo} - ${ubicacion} usando stored procedure`);
    
    // Validaciones básicas
    if (!unidad_codigo || !unidad_cantero || !ubicacion) {
      return res.status(400).json({
        success: false,
        message: 'Los campos código de unidad, cantero y ubicación son obligatorios'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedCreadoPor = creadopor ? parseInt(creadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación:', {
      unidad_codigo,
      unidad_cantero,
      ubicacion,
      creadoPor: parsedCreadoPor
    });
    
    // Llamar al stored procedure para crear plan con mejor manejo de errores
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_plan($1, $2, $3, $4)',
        [
          unidad_codigo,
          unidad_cantero,
          ubicacion,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_plan($1, $2, $3, $4)', 
        [unidad_codigo, unidad_cantero, ubicacion, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear el plan'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, plan_id } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear plan: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`Plan creado exitosamente con ID: ${plan_id}`);
    res.status(201).json({
      success: true,
      message: message,
      data: { secuencia: plan_id }
    });
  } catch (err) {
    console.error('Error al crear plan:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear el plan',
        error: err.message
      });
    }
  }
});

// ===============================================
// POST - Crear múltiples planes desde unidades seleccionadas
// ===============================================
router.post('/crear-multiples', async (req, res) => {
  try {
    const { 
      unidades, 
      ubicacion,
      creadopor 
    } = req.body;
    
    console.log(`Iniciando creación de múltiples planes para ubicación: ${ubicacion}`);
    
    // Validaciones básicas
    if (!unidades || !Array.isArray(unidades) || unidades.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'La lista de unidades es obligatoria y debe contener al menos una unidad'
      });
    }
    
    if (!ubicacion) {
      return res.status(400).json({
        success: false,
        message: 'La ubicación es obligatoria'
      });
    }
    
    // Parsear correctamente los valores numéricos
    const parsedCreadoPor = creadopor ? parseInt(creadopor) : 1;
    
    // Convertir array de unidades a JSON
    const unidadesJson = JSON.stringify(unidades);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de creación múltiple:', {
      cantidad_unidades: unidades.length,
      ubicacion,
      creadoPor: parsedCreadoPor,
      primera_unidad: unidades[0]
    });
    
    // Llamar al stored procedure para crear múltiples planes
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_create_planes_multiples($1, $2, $3)',
        [
          unidadesJson,
          ubicacion,
          parsedCreadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_create_planes_multiples($1, $2, $3)', 
        [unidadesJson, ubicacion, parsedCreadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al crear los planes'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message, planes_creados } = result.rows[0];
    
    if (!success) {
      console.log(`Error al crear planes múltiples: ${message}`);
      return res.status(400).json({
        success: false,
        message: message
      });
    }
    
    console.log(`${planes_creados} planes creados exitosamente`);
    res.status(201).json({
      success: true,
      message: message,
      data: { planes_creados: planes_creados }
    });
  } catch (err) {
    console.error('Error al crear planes múltiples:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al crear los planes',
        error: err.message
      });
    }
  }
});

// ===============================================
// PUT - Actualizar un plan existente
// ===============================================
router.put('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    const { 
      estado_planificacion, 
      estatus, 
      modificadopor 
    } = req.body;
    
    console.log(`Iniciando actualización de plan con secuencia: ${parsedSecuencia}`);
    
    // Parsear correctamente los valores numéricos
    const parsedEstatus = estatus !== undefined ? parseInt(estatus) : null;
    const parsedModificadoPor = modificadopor ? parseInt(modificadopor) : 1;
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Imprimir parámetros para depuración
    console.log('Parámetros de actualización:', {
      secuencia: parsedSecuencia,
      estado_planificacion,
      estatus: parsedEstatus,
      modificadoPor: parsedModificadoPor
    });
    
    // Llamar al stored procedure para actualizar plan
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_update_plan($1, $2, $3, $4)',
        [
          parsedSecuencia,
          estado_planificacion || null,
          parsedEstatus,
          parsedModificadoPor
        ]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_update_plan($1, $2, $3, $4)', 
        [parsedSecuencia, estado_planificacion || null, parsedEstatus, parsedModificadoPor]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al actualizar el plan'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrado')) {
        console.log(`Plan con secuencia ${parsedSecuencia} no encontrado`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al actualizar plan: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Plan con secuencia ${parsedSecuencia} actualizado exitosamente`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al actualizar plan:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al actualizar el plan',
        error: err.message
      });
    }
  }
});

// ===============================================
// DELETE - Eliminar un plan (baja lógica)
// ===============================================
router.delete('/:secuencia', async (req, res) => {
  try {
    const { secuencia } = req.params;
    const parsedSecuencia = parseInt(secuencia);
    
    console.log(`Iniciando eliminación lógica del plan con secuencia: ${parsedSecuencia}`);
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para eliminar plan
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_delete_plan($1)',
        [parsedSecuencia]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_delete_plan($1)', [parsedSecuencia]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al eliminar el plan'
      });
    }
    
    console.log('Resultado de SP:', result.rows[0]);
    const { success, message } = result.rows[0];
    
    if (!success) {
      if (message.includes('no encontrado')) {
        console.log(`Plan con secuencia ${parsedSecuencia} no encontrado`);
        return res.status(404).json({
          success: false,
          message: message
        });
      } else {
        console.log(`Error al eliminar plan: ${message}`);
        return res.status(400).json({
          success: false,
          message: message
        });
      }
    }
    
    console.log(`Plan con secuencia ${parsedSecuencia} eliminado lógicamente con éxito`);
    res.json({
      success: true,
      message: message
    });
  } catch (err) {
    console.error('Error al eliminar plan:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al eliminar el plan',
        error: err.message
      });
    }
  }
});

// ===============================================
// POST - Validar si una unidad ya existe en una ubicación
// ===============================================
router.post('/validate', async (req, res) => {
  try {
    const { 
      unidad_codigo, 
      ubicacion 
    } = req.body;
    
    console.log(`Validando existencia de unidad: ${unidad_codigo} en ubicación: ${ubicacion}`);
    
    // Validaciones básicas
    if (!unidad_codigo || !ubicacion) {
      return res.status(400).json({
        success: false,
        message: 'El código de unidad y la ubicación son obligatorios'
      });
    }
    
    // Usar el módulo db compartido
    const db = req.app.get('db');
    
    // Llamar al stored procedure para validar
    let result;
    try {
      result = await db.query(
        'SELECT * FROM sp_validate_unidad_exists($1, $2)',
        [unidad_codigo, ubicacion]
      );
    } catch (queryError) {
      logQueryError(queryError, 'SELECT * FROM sp_validate_unidad_exists($1, $2)', 
        [unidad_codigo, ubicacion]);
      throw queryError;
    }
    
    // Verificar si hubo un error en la respuesta del SP
    if (!result.rows || result.rows.length === 0) {
      console.error('Stored procedure no devolvió resultados');
      return res.status(500).json({
        success: false,
        message: 'Error interno al validar la unidad'
      });
    }
    
    console.log('Resultado de validación:', result.rows[0]);
    const { existe, message } = result.rows[0];  // Cambiado "exists" por "existe"
    
    res.json({
      success: true,
      exists: existe,  // Mantenemos "exists" en la respuesta para el frontend
      message: message
    });
  } catch (err) {
    console.error('Error al validar unidad:', err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Error al validar la unidad',
        error: err.message
      });
    }
  }
});

module.exports = router;