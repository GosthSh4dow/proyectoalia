const express = require('express');
const router = express.Router();
const whatsappController = require('../controllers/whatsappController');
const authMiddleware = require('../middlewares/authMiddleware');

// Webhook de Meta: sin auth (Meta no envía JWT).
router.get('/webhook', whatsappController.verificarWebhook);
router.post('/webhook', whatsappController.recibirWebhook);

// QR fijo del negocio (se puede ver y cambiar; lo usa aprobar-enviar-qr).
router.get('/negocio-qr', authMiddleware, whatsappController.negocioQr);
router.post('/negocio-qr', authMiddleware, whatsappController.subirQr);
// Envíos desde la APK / panel: requieren login.
router.post('/send', authMiddleware, whatsappController.enviarMensaje);
router.post('/send-imagen', authMiddleware, whatsappController.enviarImagenRoute);
router.post('/send-documento', authMiddleware, whatsappController.enviarDocumentoRoute);

module.exports = router;
