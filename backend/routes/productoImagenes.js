const express = require('express');
const router = express.Router();
const productoImagenController = require('../controllers/productoImagenController');

router.get('/producto/:id/imagenes', productoImagenController.obtenerImagenes);
router.post('/producto/:id/imagenes', productoImagenController.agregarImagenes);
router.put('/producto/:id/imagenes/:imagen_id/principal', productoImagenController.establecerImagenPrincipal);
router.put('/producto/:id/imagenes/orden', productoImagenController.reordenarImagenes);
router.delete('/producto/:id/imagenes/:imagen_id', productoImagenController.eliminarImagen);

module.exports = router;
