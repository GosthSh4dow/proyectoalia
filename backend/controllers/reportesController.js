const { Venta, DetalleVenta, Cliente, Usuario, Producto, Caja, Sucursal, Categoria, Egreso } = require('../models');
const { Op, Sequelize } = require('sequelize');
const dayjs = require('dayjs');
const { validationResult } = require('express-validator');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const reportesController = {
  async getVentas(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errores: errors.array() });
      }

      let { startDate, endDate, filterType, page, limit, sucursalId } = req.query;
      page = parseInt(page) || 1;
      limit = parseInt(limit) || 10;
      const offset = (page - 1) * limit;

      const whereClause = {};

      if (sucursalId) {
        whereClause.id_sucursal = sucursalId;
      }

      const now = dayjs();

      if (startDate && endDate) {
        whereClause.fecha = {
          [Op.between]: [
            dayjs(startDate).startOf('day').toDate(),
            dayjs(endDate).endOf('day').toDate()
          ]
        };
      } else if (filterType) {
        if (filterType === 'day') {
          whereClause.fecha = {
            [Op.between]: [
              now.startOf('day').toDate(),
              now.endOf('day').toDate()
            ]
          };
        } else if (filterType === 'week') {
          whereClause.fecha = {
            [Op.between]: [
              now.startOf('week').toDate(),
              now.endOf('week').toDate()
            ]
          };
        } else if (filterType === 'month') {
          whereClause.fecha = {
            [Op.between]: [
              now.startOf('month').toDate(),
              now.endOf('month').toDate()
            ]
          };
        }
      }

      const ventas = await Venta.findAndCountAll({
        where: whereClause,
        include: [
          { model: Cliente, as: 'cliente', attributes: ['nombre_completo'] },
          { model: Usuario, as: 'usuario', attributes: ['nombre'] }
        ],
        attributes: {
          include: ['tipo_pago']
        },
        limit,
        offset,
        order: [['fecha', 'DESC']]
      });

      return res.status(200).json({
        data: ventas.rows,
        total: ventas.count,
        page,
        limit
      });
    } catch (error) {
      console.error('Error en getVentas:', error);
      return res.status(500).json({ error: 'Error al obtener ventas.' });
    }
  },

  async getDetalleVentas(req, res) {
    try {
      const { startDate, endDate, filterType, sucursalId } = req.query;
      const whereClause = {};
      const whereClauseEgreso = {};
      const now = dayjs();

      let startRange, endRange;

      if (startDate && endDate) {
        startRange = dayjs(startDate).startOf('day').toDate();
        endRange = dayjs(endDate).endOf('day').toDate();
      } else if (filterType) {
        if (filterType === 'day') {
          startRange = now.startOf('day').toDate();
          endRange = now.endOf('day').toDate();
        } else if (filterType === 'week') {
          startRange = now.startOf('week').toDate();
          endRange = now.endOf('week').toDate();
        } else if (filterType === 'month') {
          startRange = now.startOf('month').toDate();
          endRange = now.endOf('month').toDate();
        }
      }

      if (startRange && endRange) {
        whereClause.fecha = { [Op.between]: [startRange, endRange] };
        whereClauseEgreso.fecha = { [Op.between]: [startRange, endRange] };
      }

      if (sucursalId) {
        whereClause.id_sucursal = sucursalId;
      }

      const ventas = await Venta.findAll({
        where: whereClause,
        include: [
          { model: Usuario, as: 'usuario', attributes: ['nombre'] },
          { model: Cliente, as: 'cliente', attributes: ['nombre_completo'] },
          {
            model: DetalleVenta,
            as: 'detalles',
            include: [
              { model: Producto, as: 'producto', attributes: ['nombre', 'codigo_barras', 'costo'] }
            ]
          }
        ],
        attributes: {
          include: ['tipo_pago']
        },
        order: [['fecha', 'DESC']]
      });

      const ingresoTotal = ventas.reduce((sum, v) => sum + (Number(v.monto_total) || 0), 0);
      let costoVentasTotal = 0;

      ventas.forEach(venta => {
        venta.detalles.forEach(detalle => {
          const costo = Number(detalle.producto?.costo) || 0;
          const cantidad = Number(detalle.cantidad) || 0;
          costoVentasTotal += costo * cantidad;
        });
      });

      const utilidadBruta = ingresoTotal - costoVentasTotal;

      let includeCajaOptions = [];
      if (sucursalId) {
        includeCajaOptions.push({
          model: Caja,
          as: 'caja',
          where: { id_sucursal: sucursalId },
          required: true
        });
      } else {
        includeCajaOptions.push({
          model: Caja,
          as: 'caja',
          required: true
        });
      }

      const egresos = await Egreso.findAll({
        where: whereClauseEgreso,
        include: includeCajaOptions
      });

      const totalGastosOperativos = egresos.reduce((sum, e) => sum + (Number(e.monto) || 0), 0);
      const utilidadNetaOperativa = utilidadBruta - totalGastosOperativos;

      let promedioDiario = null;
      if (startRange && endRange) {
        const diffTime = Math.abs(endRange - startRange);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        promedioDiario = diffDays > 0 ? ingresoTotal / diffDays : ingresoTotal;
      }

      return res.status(200).json({
        ingresoTotal,
        costoVentasTotal,
        utilidadBruta,
        totalGastosOperativos,
        utilidadNetaOperativa,
        promedioDiario,
        ventas_count: ventas.length,
        ventas
      });
    } catch (error) {
      console.error('Error en getDetalleVentas:', error);
      return res.status(500).json({ error: 'Error al obtener el detalle de ventas.' });
    }
  },

  async getVentasPorSucursal(req, res) {
    try {
      const ventasPorSucursal = await Venta.findAll({
        attributes: [
          [Sequelize.col('Venta.id_sucursal'), 'id_sucursal'],
          [Sequelize.fn('COUNT', Sequelize.col('Venta.id')), 'totalVentas'],
          [Sequelize.fn('SUM', Sequelize.col('Venta.monto_total')), 'ingresoTotal']
        ],
        group: ['Venta.id_sucursal'],
        include: [
          { model: Sucursal, as: 'sucursal', attributes: ['nombre'] }
        ]
      });
      return res.status(200).json(ventasPorSucursal);
    } catch (error) {
      console.error('Error en getVentasPorSucursal:', error);
      return res.status(500).json({ error: 'Error al obtener ventas por sucursal.' });
    }
  },

  async getVentasPorUsuario(req, res) {
    try {
      const ventasPorUsuario = await Venta.findAll({
        attributes: [
          'id_usuario',
          [Sequelize.fn('COUNT', Sequelize.col('id_usuario')), 'totalVentas']
        ],
        group: ['id_usuario'],
        include: [
          { model: Usuario, as: 'usuario', attributes: ['nombre'] }
        ]
      });
      return res.status(200).json(ventasPorUsuario);
    } catch (error) {
      console.error('Error en getVentasPorUsuario:', error);
      return res.status(500).json({ error: 'Error al obtener ventas por usuario.' });
    }
  },

  async getVentasPorCliente(req, res) {
    try {
      const ventasPorCliente = await Venta.findAll({
        attributes: [
          [Sequelize.col('Venta.id_cliente'), 'id_cliente'],
          [Sequelize.fn('COUNT', Sequelize.col('Venta.id_cliente')), 'totalVentas']
        ],
        group: ['Venta.id_cliente'],
        include: [
          { model: Cliente, as: 'cliente', attributes: ['nombre_completo'] }
        ]
      });
      return res.status(200).json(ventasPorCliente);
    } catch (error) {
      console.error('Error en getVentasPorCliente:', error);
      return res.status(500).json({ error: 'Error al obtener ventas por cliente.' });
    }
  },

  async getReporteCajas(req, res) {
    try {
      let { filterType, startDate, endDate, sucursalId } = req.query;
      const whereClause = {};

      if (sucursalId) {
        whereClause.id_sucursal = sucursalId;
      }

      const now = dayjs();
      if (startDate && endDate) {
        whereClause.fecha = {
          [Op.between]: [startDate, endDate]
        };
      } else if (filterType) {
        if (filterType === 'day') {
          whereClause.fecha = now.format('YYYY-MM-DD');
        } else if (filterType === 'month') {
          whereClause.fecha = { [Op.between]: [now.startOf('month').format('YYYY-MM-DD'), now.endOf('month').format('YYYY-MM-DD')] };
        } else if (filterType === 'year') {
          whereClause.fecha = { [Op.between]: [now.startOf('year').format('YYYY-MM-DD'), now.endOf('year').format('YYYY-MM-DD')] };
        }
      }

      const cajas = await Caja.findAll({
        where: whereClause,
        include: [
          { model: Sucursal, as: 'sucursal', attributes: ['nombre'] },
          { model: Usuario, as: 'usuario_cierre', attributes: ['nombre'] }
        ],
        order: [['fecha', 'DESC']]
      });

      const totalIngresos = cajas.reduce((sum, caja) => sum + parseFloat(caja.ingresos), 0);
      const totalEgresos = cajas.reduce((sum, caja) => sum + parseFloat(caja.egresos), 0);
      const utilidadNeta = totalIngresos - totalEgresos;

      return res.status(200).json({
        totalIngresos: totalIngresos || "Sin dato",
        totalEgresos: totalEgresos || "Sin dato",
        utilidadNeta: utilidadNeta || "Sin dato",
        cajas
      });
    } catch (error) {
      console.error('Error en getReporteCajas:', error);
      return res.status(500).json({ error: 'Error al obtener reporte de cajas.' });
    }
  },

  async getProductosMasVendidos(req, res) {
    try {
      const productosVendidos = await DetalleVenta.findAll({
        attributes: [
          'id_producto',
          [Sequelize.fn('SUM', Sequelize.col('cantidad')), 'totalVendidos']
        ],
        group: ['id_producto'],
        include: [
          { model: Producto, as: 'producto', attributes: ['nombre', 'stock'] }
        ],
        order: [[Sequelize.fn('SUM', Sequelize.col('cantidad')), 'DESC']]
      });
      return res.status(200).json(productosVendidos);
    } catch (error) {
      console.error('Error en getProductosMasVendidos:', error);
      return res.status(500).json({ error: 'Error al obtener productos más vendidos.' });
    }
  },

  async getBajoStock(req, res) {
    try {
      let { limitStock } = req.query;
      limitStock = parseInt(limitStock) || 10;
      const productos = await Producto.findAll({
        where: { stock: { [Op.lte]: limitStock } },
        include: [
          {
            model: Categoria,
            as: 'categoria',
            attributes: ['id', 'nombre'],
            required: false
          }
        ],
        order: [['stock', 'ASC']]
      });
      return res.status(200).json(productos);
    } catch (error) {
      console.error('Error en getBajoStock:', error);
      return res.status(500).json({ error: 'Error al obtener productos con bajo stock.' });
    }
  },

  async getFinanzas(req, res) {
    try {
      const ingresos = await Venta.sum('monto_total');
      const egresos = 0;
      const utilidadTotal = ingresos - egresos;
      const gananciaNeta = utilidadTotal;
      return res.status(200).json({
        ingresos: ingresos || "Sin dato",
        egresos: egresos || "Sin dato",
        utilidadTotal: utilidadTotal || "Sin dato",
        gananciaNeta: gananciaNeta || "Sin dato"
      });
    } catch (error) {
      console.error('Error en getFinanzas:', error);
      return res.status(500).json({ error: 'Error al obtener datos financieros.' });
    }
  },

  async exportarReportes(req, res) {
    try {
      const { format } = req.query;
      const ventas = await Venta.findAll({
        include: [
          { model: Cliente, as: 'cliente', attributes: ['nombre_completo'] },
          { model: Usuario, as: 'usuario', attributes: ['nombre'] }
        ],
        order: [['fecha', 'DESC']]
      });
      if (format && format.toLowerCase() === 'csv') {
        const csvWriter = createCsvWriter({
          path: 'reportes.csv',
          header: [
            { id: 'id', title: 'ID' },
            { id: 'fecha', title: 'Fecha' },
            { id: 'monto_total', title: 'Monto Total' },
            { id: 'cliente', title: 'Cliente' },
            { id: 'usuario', title: 'Usuario' }
          ]
        });
        const records = ventas.map(venta => ({
          id: venta.id,
          fecha: venta.fecha,
          monto_total: venta.monto_total,
          cliente: venta.cliente && venta.cliente.nombre_completo ? venta.cliente.nombre_completo : "Sin dato",
          usuario: venta.usuario && venta.usuario.nombre ? venta.usuario.nombre : "Sin dato"
        }));
        await csvWriter.writeRecords(records);
        return res.download('reportes.csv');
      } else {
        return res.status(200).json(ventas);
      }
    } catch (error) {
      console.error('Error en exportarReportes:', error);
      return res.status(500).json({ error: 'Error al exportar reportes.' });
    }
  }
};

module.exports = reportesController;
