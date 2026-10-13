const express = require('express');
const router = express.Router();
const { query } = require('express-validator');
const reportesController = require('../controllers/reportesController');

router.get(
  '/ventas',
  [
    query('startDate').optional().isISO8601().withMessage('startDate debe ser una fecha válida'),
    query('endDate').optional().isISO8601().withMessage('endDate debe ser una fecha válida'),
    query('page').optional().isInt({ min: 1 }).withMessage('page debe ser un número entero positivo'),
    query('limit').optional().isInt({ min: 1 }).withMessage('limit debe ser un número entero positivo')
  ],
  reportesController.getVentas
);
router.get('/ventas/detalle', reportesController.getDetalleVentas);
router.get('/ventas/por-sucursal', reportesController.getVentasPorSucursal);
router.get('/usuarios', reportesController.getVentasPorUsuario);
router.get('/clientes', reportesController.getVentasPorCliente);
router.get('/cajas', reportesController.getReporteCajas);
router.get('/inventario/bajo-stock', reportesController.getBajoStock);
router.get('/finanzas', reportesController.getFinanzas);
router.get('/exportar', reportesController.exportarReportes);
router.get('/productos/mas-vendidos', reportesController.getProductosMasVendidos);

module.exports = router;
