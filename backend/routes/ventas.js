const express = require('express');
const router = express.Router();
const ventaController = require('../controllers/ventaController');

router.get('/', ventaController.obtenerVentas);
router.get('/:id', ventaController.obtenerVenta);
router.post('/', ventaController.crearVenta);
router.delete('/:id', ventaController.eliminarVenta);

module.exports = router;
