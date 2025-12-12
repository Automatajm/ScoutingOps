// backend/routes/catalogos-sync.js
const express = require('express');
const router = express.Router();

// GET - Obtener TODOS los niveles de infestación activos (para sync)
router.get('/', async (req, res) => {
  try {
    console.log('Obteniendo todos los niveles de infestación para sincronización');
    
    const db = req.app.get('db');
    
    const result = await db.query(`
      SELECT 
        pmni_secuencia,
        pmni_plaga,
        pmni_nombrecomun,
        pmni_lminferior,
        pmni_lmsuperior,
        pmni_nivel,
        pmni_rango,
        pmni_tipoobservacion,
        pmni_observacion,
        pmni_cintaidentificadora,
        pmni_estatus
      FROM pm_nivelesinfestacion 
      WHERE pmni_estatus = 1
      ORDER BY pmni_nombrecomun, pmni_nivel
    `);
    
    console.log('Niveles de infestación obtenidos:', result.rows.length);
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('Error al obtener niveles:', err);
    res.status(500).json({
      success: false,
      message: 'Error al obtener niveles de infestación',
      error: err.message
    });
  }
});

// GET - Obtener counts de todos los catálogos para sincronización
router.get('/counts', async (req, res) => {
  try {
    console.log('Obteniendo counts de catálogos para sincronización');
    
    const db = req.app.get('db');
    
    const [variedades, lotes, plagas, unidades] = await Promise.all([
      db.query("SELECT COUNT(*) as count FROM pm_variedades WHERE pmva_estatus = 1"),
      db.query("SELECT COUNT(*) as count FROM pm_lotes WHERE pmlt_estatus = 1"),
      db.query("SELECT COUNT(*) as count FROM pm_plagas WHERE pmpl_estatus = 1"),
      db.query("SELECT COUNT(*) as count FROM pm_unidadescultivo WHERE pmuc_estatus = 1")
    ]);
    
    const counts = {
      variedades: parseInt(variedades.rows[0].count),
      lotes: parseInt(lotes.rows[0].count),
      plagas: parseInt(plagas.rows[0].count),
      unidades_cultivo: parseInt(unidades.rows[0].count),
      timestamp: new Date().toISOString()
    };
    
    console.log('Counts de catálogos:', counts);
    
    res.json({
      success: true,
      data: counts
    });
  } catch (err) {
    console.error('Error al obtener counts:', err);
    res.status(500).json({
      success: false,
      message: 'Error al obtener counts de catálogos',
      error: err.message
    });
  }
});

// GET - Obtener todos los catálogos en una sola llamada
router.get('/all', async (req, res) => {
  try {
    console.log('Obteniendo todos los catálogos para sincronización');
    
    const db = req.app.get('db');
    
    const [variedades, lotes, plagas, unidades, nivelesLimites] = await Promise.all([
      db.query("SELECT * FROM sp_get_variedades(NULL, 1)"),
      db.query("SELECT * FROM sp_get_lotes_by_codigo_variedad(NULL, 1, NULL)"),
      db.query("SELECT * FROM sp_get_plagas(NULL, 1, NULL)"),
      db.query("SELECT * FROM sp_get_unidades_cultivo(NULL, 1, NULL)"),
      db.query("SELECT * FROM pm_niveleslimites WHERE lmni_estatus = 1")
    ]);
    
    const catalogos = {
      variedades: variedades.rows,
      lotes: lotes.rows,
      plagas: plagas.rows,
      unidades_cultivo: unidades.rows,
      niveles_limites: nivelesLimites.rows,
      counts: {
        variedades: variedades.rows.length,
        lotes: lotes.rows.length,
        plagas: plagas.rows.length,
        unidades_cultivo: unidades.rows.length,
        niveles_limites: nivelesLimites.rows.length
      },
      timestamp: new Date().toISOString()
    };
    
    console.log('Catálogos obtenidos:', catalogos.counts);
    
    res.json({
      success: true,
      data: catalogos
    });
  } catch (err) {
    console.error('Error al obtener catálogos:', err);
    res.status(500).json({
      success: false,
      message: 'Error al obtener catálogos',
      error: err.message
    });
  }
});

module.exports = router;