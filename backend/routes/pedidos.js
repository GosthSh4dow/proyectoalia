const express = require('express');
const router = express.Router();
const pedidoController = require('../controllers/pedidoController');
const authMiddleware = require('../middlewares/authMiddleware');

const clientIdentifier = (req, res, next) => {
  req.clientInfo = {
    timestamp: Date.now(),
    userAgent: req.headers['user-agent'] || 'unknown',
    language: req.headers['accept-language'] || 'unknown',
    acceptHeader: req.headers['accept'] || 'unknown',
    isMobileRequest: false
  };
  const userAgent = (req.headers['user-agent'] || '').toLowerCase();
  req.clientInfo.isMobileRequest =
    userAgent.includes('android') ||
    userAgent.includes('iphone') ||
    userAgent.includes('mobile') ||
    userAgent.includes('samsung') ||
    userAgent.includes('huawei');
  next();
};

const pedidoErrorHandler = (handler) => {
  return async (req, res, next) => {
    try {
      await handler(req, res, next);
    } catch (error) {
      console.error('Error en ruta de pedidos:', error);
      res.status(500).json({
        error: 'Error al procesar la solicitud de pedido',
        mensaje: error.message
      });
    }
  };
};

router.post('/', clientIdentifier, pedidoController.pedidoLimiter, pedidoErrorHandler(pedidoController.crearPedido));
router.get('/', authMiddleware, pedidoErrorHandler(pedidoController.obtenerPedidos));
router.get('/:id', authMiddleware, pedidoErrorHandler(pedidoController.obtenerPedidoPorId));
router.put('/:id/estado', authMiddleware, pedidoErrorHandler(pedidoController.actualizarEstadoPedido));
router.post('/:id/aprobar-enviar-qr', authMiddleware, pedidoErrorHandler(pedidoController.aprobarEnviarQr));
router.post('/:id/confirmar-pago', authMiddleware, pedidoErrorHandler(pedidoController.confirmarPago));
router.post('/realizar-venta', authMiddleware, pedidoErrorHandler(pedidoController.realizarVenta));

module.exports = router;
