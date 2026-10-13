const express = require('express');
const router = express.Router();
const fidelidadController = require('../controllers/fidelidadController');

router.get('/cliente/:clienteId', fidelidadController.getFidelidadCliente);
router.get('/todos', fidelidadController.getAllClientesFidelidad);
router.get('/estadisticas', fidelidadController.getEstadisticasFidelidad);

module.exports = router;
