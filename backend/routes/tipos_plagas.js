// GET - Obtener todos los tipos de plagas
router.get('/tipos_plagas', async (req, res) => {
  try {
    // Usar el módulo db compartido
    const db = req.app.get('db');
    const tiposPlagas = await obtenerTiposPlagas(db);
    
    res.json({
      success: true,
      data: tiposPlagas
    });
  } catch (err) {
    console.error('Error al obtener tipos de plagas:', err);
    res.status(500).json({
      success: false,
      message: 'Error al obtener los tipos de plagas',
      error: err.message
    });
  }
});