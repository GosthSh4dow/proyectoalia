const express = require('express');
const router = express.Router();
const cajaController = require('../controllers/cajaController');

router.post('/close', cajaController.cerrarCaja);
router.post('/open', cajaController.abrirCaja);
router.get('/status', cajaController.obtenerEstadoCaja);
router.get('/all', cajaController.obtenerTodasCajas);
router.get('/today', cajaController.obtenerCajasHoy);
router.put('/edit', cajaController.editarCaja);
router.get('/resumen/:id_caja', cajaController.obtenerResumenCaja);
router.post('/:caja_id/egresos', cajaController.registrarEgreso);
router.get('/historial', cajaController.obtenerHistorialCajas);

module.exports = router;
