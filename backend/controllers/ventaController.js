const db = require('../models');
const { Venta, DetalleVenta, Producto, Caja, Cliente, Usuario, Sucursal } = db;
const fidelidadController = require('./fidelidadController');

exports.obtenerVentas = async (req, res) => {
    try {
        const ventas = await Venta.findAll({
            include: [
                {
                    model: Cliente,
                    as: 'cliente',
                    attributes: ['nombre_completo', 'ci']
                },
                {
                    model: Usuario,
                    as: 'usuario',
                    attributes: ['nombre']
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['direccion']
                },
                {
                    model: DetalleVenta,
                    as: 'detalles',
                    include: [
                        {
                            model: Producto,
                            as: 'producto',
                            attributes: ['nombre', 'codigo_barras']
                        }
                    ]
                }
            ],
        });
        res.status(200).json(ventas);
    } catch (error) {
        console.error('Error al obtener ventas:', error);
        res.status(500).json({ error: 'Error al obtener ventas' });
    }
};

exports.obtenerVenta = async (req, res) => {
    try {
        const venta = await Venta.findByPk(req.params.id, {
            include: [
                {
                    model: Cliente,
                    as: 'cliente',
                    attributes: ['nombre_completo', 'ci']
                },
                {
                    model: Usuario,
                    as: 'usuario',
                    attributes: ['nombre']
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['direccion']
                },
                {
                    model: DetalleVenta,
                    as: 'detalles',
                    include: [
                        {
                            model: Producto,
                            as: 'producto',
                            attributes: ['nombre', 'codigo_barras']
                        }
                    ]
                }
            ],
        });
        if (!venta) {
            return res.status(404).json({ error: 'Venta no encontrada' });
        }
        res.status(200).json(venta);
    } catch (error) {
        console.error('Error al obtener la venta:', error);
        res.status(500).json({ error: 'Error al obtener la venta' });
    }
};

exports.crearVenta = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        let { nombre_completo, ci, id_cliente, id_usuario, id_sucursal_activa, id_sucursal, id_caja_activa, detalles, monto_total, fecha } = req.body;

        if (!id_sucursal_activa && id_sucursal) {
            id_sucursal_activa = id_sucursal;
        }

        if (!id_usuario || !id_sucursal_activa || !id_caja_activa || !detalles || detalles.length === 0 || !monto_total) {
            await transaction.rollback();
            return res.status(400).json({ error: 'Faltan datos obligatorios (usuario, sucursal, caja, detalles, monto)' });
        }

        let cliente = null;

        if (id_cliente && id_cliente !== 0) {
            cliente = await Cliente.findByPk(id_cliente, { transaction });
            if (!cliente) {
                await transaction.rollback();
                return res.status(404).json({ error: 'Cliente no encontrado con el ID proporcionado.' });
            }
        } else if (ci && ci !== '0') {
            const [clienteEncontrado] = await Cliente.findOrCreate({
                where: { ci },
                defaults: { nombre_completo },
                transaction
            });
            cliente = clienteEncontrado;
        }

        const { tipo_pago } = req.body;

        const venta = await Venta.create({
            id_cliente: cliente ? cliente.id_cliente : null,
            id_usuario,
            id_sucursal: id_sucursal_activa,
            monto_total: parseFloat(monto_total),
            tipo_pago: tipo_pago || 'efectivo',
            fecha: fecha || new Date(),
        }, { transaction });

        for (const detalle of detalles) {
            const producto = await Producto.findByPk(detalle.producto_id, { transaction });
            if (!producto) {
                await transaction.rollback();
                return res.status(404).json({ error: `Producto ID ${detalle.producto_id} no encontrado.` });
            }
            if (producto.stock < detalle.cantidad) {
                await transaction.rollback();
                return res.status(400).json({ error: `Producto ID ${detalle.producto_id} stock insuficiente.` });
            }

            await producto.update({ stock: producto.stock - detalle.cantidad }, { transaction });

            await DetalleVenta.create({
                id_venta: venta.id,
                id_producto: detalle.producto_id,
                cantidad: detalle.cantidad,
                precio_unitario: parseFloat(detalle.precio_unitario),
                subtotal: parseFloat(detalle.subtotal)
            }, { transaction });
        }

        const cajaOperativa = await Caja.findOne({
            where: { id: id_caja_activa, id_sucursal: id_sucursal_activa, estado: 'abierta' },
            transaction
        });

        if (!cajaOperativa) {
            await transaction.rollback();
            return res.status(400).json({
                error: 'La caja activa especificada no está abierta o no pertenece a la sucursal activa.',
                detalle: `Caja ID: ${id_caja_activa}, Sucursal ID: ${id_sucursal_activa}`
            });
        }

        cajaOperativa.ingresos = parseFloat(cajaOperativa.ingresos) + parseFloat(monto_total);
        cajaOperativa.saldo_final = (
            parseFloat(cajaOperativa.saldo_inicial) +
            parseFloat(cajaOperativa.ingresos) -
            parseFloat(cajaOperativa.egresos)
        ).toFixed(2);

        await cajaOperativa.save({ transaction });

        if (cliente) {
            try {
                await fidelidadController.actualizarFidelidadCliente(cliente.id_cliente, monto_total);
            } catch (fidelidadError) {
                console.error('Error al actualizar fidelidad del cliente:', fidelidadError);
            }
        }

        await transaction.commit();

        const ventaConDetalles = await Venta.findOne({
            where: { id: venta.id },
            include: [
                {
                    model: Cliente,
                    as: 'cliente',
                    attributes: ['nombre_completo', 'ci']
                },
                {
                    model: Usuario,
                    as: 'usuario',
                    attributes: ['nombre']
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['direccion', 'nombre']
                },
                {
                    model: DetalleVenta,
                    as: 'detalles',
                    include: [
                        {
                            model: Producto,
                            as: 'producto',
                            attributes: ['nombre', 'codigo_barras']
                        }
                    ]
                }
            ],
        });

        res.status(201).json(ventaConDetalles);
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al crear venta:', error);
        res.status(500).json({ error: 'Error al crear la venta', detalle: error.message });
    }
};

exports.eliminarVenta = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const venta = await Venta.findByPk(req.params.id, {
            include: [{ model: DetalleVenta, as: 'detalles' }],
            transaction
        });
        if (!venta) {
            await transaction.rollback();
            return res.status(404).json({ error: 'Venta no encontrada' });
        }

        for (const detalle of venta.detalles) {
            const producto = await Producto.findByPk(detalle.id_producto, { transaction });
            if (producto) {
                await producto.update({ stock: producto.stock + detalle.cantidad }, { transaction });
            }
        }

        await DetalleVenta.destroy({ where: { id_venta: venta.id }, transaction });
        await venta.destroy({ transaction });

        await transaction.commit();
        res.status(200).json({ message: 'Venta eliminada correctamente' });
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al eliminar venta:', error);
        res.status(500).json({ error: 'Error al eliminar la venta' });
    }
};
