const express = require('express');
const router = express.Router();
const productoCodigoController = require('../controllers/productoCodigoController');

router.get('/buscar/:codigo', productoCodigoController.buscarPorCodigo);
router.get('/producto/:id', productoCodigoController.obtenerCodigosProducto);
router.post('/producto/:id', productoCodigoController.crearCodigo);
router.put('/:id', productoCodigoController.actualizarCodigo);
router.delete('/:id', productoCodigoController.eliminarCodigo);

module.exports = router;
