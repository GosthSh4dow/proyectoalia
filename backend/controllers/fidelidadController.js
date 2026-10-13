const db = require('../models');
const { ClienteFidelidad, Cliente, Venta } = db;
const { Op } = require('sequelize');

module.exports = {
    async getFidelidadCliente(req, res) {
        try {
            const { clienteId } = req.params;
            if (!clienteId) {
                return res.status(400).json({ error: 'ID de cliente es requerido' });
            }
            const cliente = await Cliente.findByPk(clienteId);
            if (!cliente) {
                return res.status(404).json({ error: 'Cliente no encontrado' });
            }
            let fidelidad = await ClienteFidelidad.findOne({
                where: { cliente_id: clienteId },
                include: [{
                    model: Cliente,
                    as: 'cliente_fidelidad',
                    attributes: ['id_cliente', 'nombre_completo', 'ci']
                }]
            });
            if (!fidelidad) {
                const ventasCliente = await Venta.findAll({
                    where: { id_cliente: clienteId },
                    order: [['fecha', 'ASC']]
                });
                const totalCompras = ventasCliente.length;
                const montoTotal = ventasCliente.reduce((sum, venta) =>
                    sum + parseFloat(venta.monto_total), 0);
                let nivel = 'nuevo';
                if (totalCompras >= 6) nivel = 'vip';
                else if (totalCompras >= 2) nivel = 'frecuente';
                fidelidad = await ClienteFidelidad.create({
                    cliente_id: clienteId,
                    total_compras: totalCompras,
                    monto_total_gastado: montoTotal,
                    nivel: nivel,
                    primera_compra: ventasCliente.length > 0 ? ventasCliente[0].fecha : null,
                    ultima_compra: ventasCliente.length > 0 ? ventasCliente[ventasCliente.length - 1].fecha : null
                });
                await fidelidad.reload({
                    include: [{
                        model: Cliente,
                        as: 'cliente_fidelidad',
                        attributes: ['id_cliente', 'nombre_completo', 'ci']
                    }]
                });
            }
            res.status(200).json({
                cliente: fidelidad.cliente_fidelidad,
                fidelidad: {
                    total_compras: fidelidad.total_compras,
                    monto_total_gastado: fidelidad.monto_total_gastado,
                    nivel: fidelidad.nivel,
                    primera_compra: fidelidad.primera_compra,
                    ultima_compra: fidelidad.ultima_compra
                }
            });
        } catch (error) {
            console.error('Error al obtener fidelidad del cliente:', error);
            res.status(500).json({ error: 'Error al obtener fidelidad del cliente' });
        }
    },

    async getAllClientesFidelidad(req, res) {
        try {
            const { nivel, ordenar } = req.query;
            const whereCondition = {};
            if (nivel && ['nuevo', 'frecuente', 'vip'].includes(nivel)) {
                whereCondition.nivel = nivel;
            }
            const orderCondition = [];
            if (ordenar === 'compras') {
                orderCondition.push(['total_compras', 'DESC']);
            } else if (ordenar === 'monto') {
                orderCondition.push(['monto_total_gastado', 'DESC']);
            } else {
                orderCondition.push(['ultima_compra', 'DESC']);
            }
            const clientesFidelidad = await ClienteFidelidad.findAll({
                where: whereCondition,
                include: [{
                    model: Cliente,
                    as: 'cliente_fidelidad',
                    attributes: ['id_cliente', 'nombre_completo', 'ci']
                }],
                order: orderCondition
            });
            const transformedData = clientesFidelidad.map(item => ({
                id: item.id,
                nivel: item.nivel,
                total_compras: item.total_compras,
                monto_total: item.monto_total_gastado,
                primera_compra: item.primera_compra,
                ultima_compra: item.ultima_compra,
                cliente: item.cliente_fidelidad
            }));
            res.status(200).json(transformedData);
        } catch (error) {
            console.error('Error al obtener clientes con fidelidad:', error);
            res.status(500).json({ error: 'Error al obtener clientes con fidelidad' });
        }
    },

    async getEstadisticasFidelidad(req, res) {
        try {
            const estadisticasNivel = await ClienteFidelidad.findAll({
                attributes: [
                    'nivel',
                    [db.sequelize.fn('COUNT', db.sequelize.col('id')), 'total_clientes'],
                    [db.sequelize.fn('SUM', db.sequelize.col('monto_total_gastado')), 'monto_total']
                ],
                group: ['nivel']
            });
            const topVIP = await ClienteFidelidad.findAll({
                where: { nivel: 'vip' },
                include: [{
                    model: Cliente,
                    as: 'cliente_fidelidad',
                    attributes: ['nombre_completo']
                }],
                order: [['monto_total_gastado', 'DESC']],
                limit: 5
            });
            const topFrecuentes = await ClienteFidelidad.findAll({
                where: { nivel: 'frecuente' },
                include: [{
                    model: Cliente,
                    as: 'cliente_fidelidad',
                    attributes: ['nombre_completo']
                }],
                order: [['total_compras', 'DESC']],
                limit: 5
            });
            const totalClientes = await ClienteFidelidad.count();
            const montoTotalGeneral = await ClienteFidelidad.sum('monto_total_gastado');
            const promedioCompras = await ClienteFidelidad.findOne({
                attributes: [[db.sequelize.fn('AVG', db.sequelize.col('total_compras')), 'promedio']]
            });
            const clientesNuevos = await ClienteFidelidad.count({ where: { nivel: 'nuevo' } });
            const clientesFrecuentes = await ClienteFidelidad.count({ where: { nivel: 'frecuente' } });
            const clientesVIP = await ClienteFidelidad.count({ where: { nivel: 'vip' } });
            const promedioMonto = totalClientes > 0 ? (montoTotalGeneral || 0) / totalClientes : 0;
            res.status(200).json({
                estadisticas_por_nivel: estadisticasNivel,
                top_vip: topVIP,
                top_frecuentes: topFrecuentes,
                estadisticas_generales: {
                    total_clientes: totalClientes,
                    monto_total_general: montoTotalGeneral || 0,
                    promedio_compras: parseFloat(promedioCompras?.dataValues?.promedio || 0).toFixed(2),
                    promedio_monto: parseFloat(promedioMonto).toFixed(2)
                },
                totalClientes,
                clientesNuevos,
                clientesFrecuentes,
                clientesVIP,
                promedioCompras: parseFloat(promedioCompras?.dataValues?.promedio || 0).toFixed(2),
                promedioMonto: parseFloat(promedioMonto).toFixed(2)
            });
        } catch (error) {
            console.error('Error al obtener estadísticas de fidelidad:', error);
            res.status(500).json({ error: 'Error al obtener estadísticas de fidelidad' });
        }
    },

    async actualizarFidelidadCliente(clienteId, montoVenta) {
        try {
            let fidelidad = await ClienteFidelidad.findOne({
                where: { cliente_id: clienteId }
            });
            if (!fidelidad) {
                fidelidad = await ClienteFidelidad.create({
                    cliente_id: clienteId,
                    total_compras: 1,
                    monto_total_gastado: montoVenta,
                    nivel: 'nuevo',
                    primera_compra: new Date(),
                    ultima_compra: new Date()
                });
            } else {
                const nuevasCompras = fidelidad.total_compras + 1;
                const nuevoMonto = parseFloat(fidelidad.monto_total_gastado) + parseFloat(montoVenta);
                let nuevoNivel = 'nuevo';
                if (nuevasCompras >= 6) nuevoNivel = 'vip';
                else if (nuevasCompras >= 2) nuevoNivel = 'frecuente';
                await fidelidad.update({
                    total_compras: nuevasCompras,
                    monto_total_gastado: nuevoMonto,
                    nivel: nuevoNivel,
                    ultima_compra: new Date()
                });
            }
            return fidelidad;
        } catch (error) {
            console.error('Error al actualizar fidelidad del cliente:', error);
            throw error;
        }
    }
};
