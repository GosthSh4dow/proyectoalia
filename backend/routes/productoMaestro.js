const express = require('express');
const router = express.Router();
const productoMaestroController = require('../controllers/productoMaestroController');

router.get('/', productoMaestroController.obtenerProductosMaestros);
router.get('/:id', productoMaestroController.obtenerProductoMaestro);
router.get('/:id/instancias', productoMaestroController.obtenerInstanciasProductoMaestro);
router.post('/', productoMaestroController.crearProductoMaestro);
router.put('/:id', productoMaestroController.actualizarProductoMaestro);
router.delete('/:id', productoMaestroController.eliminarProductoMaestro);

module.exports = router;
