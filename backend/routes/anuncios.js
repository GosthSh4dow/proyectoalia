const express = require('express');
const router = express.Router();
const anuncioController = require('../controllers/anuncioController');
const authMiddleware = require('../middlewares/authMiddleware');
const fs = require('fs');
const path = require('path');

router.get('/', anuncioController.obtenerAnuncios);
router.get('/activos', anuncioController.obtenerAnunciosActivos);
router.get('/animaciones-list', (req, res) => {
  const animDir = path.join(__dirname, '..', 'uploads', 'animaciones');
  if (!fs.existsSync(animDir)) {
    return res.json({ files: [] });
  }
  const files = fs.readdirSync(animDir)
    .filter(f => f.endsWith('.json'))
    .map(f => '/uploads/animaciones/' + f);
  res.json({ files });
});
router.post('/animaciones', authMiddleware, async (req, res) => {
  if (!req.files || !req.files.lottie_json) {
    return res.status(400).json({ error: 'No se envió ningún archivo Lottie' });
  }
  const archivo = req.files.lottie_json;
  const animDir = path.join(__dirname, '..', 'uploads', 'animaciones');
  if (!fs.existsSync(animDir)) {
    fs.mkdirSync(animDir, { recursive: true });
  }
  const nombreAnim = Date.now() + '_' + Math.random().toString(36).substring(2, 15) + path.extname(archivo.name);
  const rutaAnim = path.join(animDir, nombreAnim);
  archivo.mv(rutaAnim, (err) => {
    if (err) {
      return res.status(500).json({ error: 'Error al guardar la animación' });
    }
    const files = fs.readdirSync(animDir)
      .filter(f => f.endsWith('.json'))
      .map(f => '/uploads/animaciones/' + f);
    return res.status(201).json({ url: '/uploads/animaciones/' + nombreAnim, files });
  });
});
router.get('/:id', anuncioController.obtenerAnuncio);
router.post('/', authMiddleware, anuncioController.crearAnuncio);
router.put('/:id', authMiddleware, anuncioController.actualizarAnuncio);
router.delete('/:id', authMiddleware, anuncioController.eliminarAnuncio);

module.exports = router;
