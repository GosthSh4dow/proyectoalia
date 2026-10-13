const express = require('express');
const router = express.Router();
const catalogoInfoController = require('../controllers/catalogoInfoController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get('/publica', catalogoInfoController.obtenerInfoPublica);
router.get('/', authMiddleware, catalogoInfoController.obtenerInfo);
router.get('/:id', authMiddleware, catalogoInfoController.obtenerInfoPorId);
router.post('/', authMiddleware, catalogoInfoController.crearInfo);
router.put('/:id', authMiddleware, catalogoInfoController.actualizarInfo);
router.delete('/:id', authMiddleware, catalogoInfoController.eliminarInfo);
router.delete('/:id/banner', authMiddleware, catalogoInfoController.eliminarBanner);
router.post('/:id/banner/imagenes', authMiddleware, catalogoInfoController.agregarImagenBanner);
router.delete('/:id/banner/imagenes/:imagenId', authMiddleware, catalogoInfoController.eliminarImagenBanner);
router.put('/:id/banner/imagenes/:imagenId', authMiddleware, catalogoInfoController.actualizarImagenBanner);
router.put('/:id/banner/imagenes/reordenar', authMiddleware, catalogoInfoController.reordenarImagenesBanner);
router.post('/:id/logos', authMiddleware, catalogoInfoController.agregarImagenLogo);
router.delete('/:id/logos/:imagenId', authMiddleware, catalogoInfoController.eliminarImagenLogo);
router.put('/:id/logos/:imagenId', authMiddleware, catalogoInfoController.actualizarImagenLogo);
router.put('/:id/logos/reordenar', authMiddleware, catalogoInfoController.reordenarImagenesLogo);

module.exports = router;
