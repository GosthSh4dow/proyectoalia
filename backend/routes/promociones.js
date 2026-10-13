const express = require('express');
const router = express.Router();
const {
  obtenerPromociones,
  obtenerPromocion,
  crearPromocion,
  actualizarPromocion,
  eliminarPromocion,
  actualizarPromocionesExpiradas,
  eliminarProductoDePromocion,
} = require('../controllers/promocionController');

router.get('/', obtenerPromociones);
router.get('/:id', obtenerPromocion);
router.post('/', crearPromocion);
router.put('/:id', actualizarPromocion);
router.delete('/:id', eliminarPromocion);
router.put('/expiradas', actualizarPromocionesExpiradas);
router.delete('/:id/producto/:id_producto', eliminarProductoDePromocion);

module.exports = router;
