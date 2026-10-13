const db = require('../models');
const { Caja, Usuario, Sucursal } = db;

exports.cerrarCaja = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id_caja, ingresos, egresos, justificacion, cerrado_por } = req.body;

        if (!id_caja) {
            await transaction.rollback();
            return res.status(400).json({ error: 'Falta el ID de la caja para cerrar.' });
        }

        const caja = await Caja.findOne({
            where: { id: id_caja, estado: 'abierta' },
            transaction
        });

        if (!caja) {
            await transaction.rollback();
            return res.status(400).json({ error: 'No hay una caja abierta con ese ID o ya está cerrada.' });
        }

        caja.ingresos = parseFloat(ingresos !== undefined ? ingresos : caja.ingresos);
        caja.egresos = parseFloat(egresos !== undefined ? egresos : caja.egresos);

        const saldo_calculado = parseFloat(caja.saldo_inicial) + parseFloat(caja.ingresos) - parseFloat(caja.egresos);
        caja.saldo_final = saldo_calculado.toFixed(2);

        if (caja.egresos > 0) {
            caja.justificacion = justificacion;
        } else {
            caja.justificacion = null;
        }

        caja.estado = 'cerrada';
        caja.cerrado_por = cerrado_por || (req.user ? req.user.id : null);
        caja.fecha_cierre = new Date();
        await caja.save({ transaction });

        const reporte = {
            id_caja: caja.id,
            id_sucursal: caja.id_sucursal,
            fecha: caja.fecha,
            saldo_inicial: caja.saldo_inicial,
            ingresos: caja.ingresos,
            egresos: caja.egresos,
            saldo_final: caja.saldo_final,
            cerrado_por: caja.cerrado_por,
            fecha_cierre: caja.fecha_cierre,
            justificacion: caja.justificacion,
        };

        await transaction.commit();
        res.status(200).json({ message: 'Caja cerrada exitosamente.', reporte });
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al cerrar la caja:', error);
        res.status(500).json({ error: 'Error al cerrar la caja.', detalle: error.message });
    }
};

exports.abrirCaja = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        let { id_sucursal, saldo_inicial, monto_inicial, rol, abierto_por } = req.body;

        if (typeof id_sucursal === 'object' && id_sucursal !== null) {
            id_sucursal = id_sucursal.id;
        }

        if (!id_sucursal || saldo_inicial === undefined || !rol) {
            await transaction.rollback();
            return res.status(400).json({ error: 'Faltan datos necesarios (sucursal activa, saldo inicial, rol) para abrir la caja.' });
        }

        const cajaAbierta = await Caja.findOne({
            where: { id_sucursal, estado: 'abierta' },
            transaction
        });

        if (cajaAbierta) {
            await transaction.rollback();
            return res.status(400).json({ error: 'Ya existe una caja abierta para esta sucursal.' });
        }

        const ultimaCaja = await Caja.findOne({
            where: { id_sucursal, estado: 'cerrada' },
            order: [['fecha_cierre', 'DESC'], ['createdAt', 'DESC']],
            transaction
        });

        const saldoInicialCalculado = ultimaCaja ? parseFloat(ultimaCaja.saldo_final) : 0.00;
        const saldoInicialIngresado = parseFloat(saldo_inicial);

        if (rol !== "administrador") {
            if (Math.abs(saldoInicialCalculado - saldoInicialIngresado) > 0.01) {
                await transaction.rollback();
                return res.status(400).json({ error: 'El saldo inicial no coincide con el saldo final de la última caja cerrada para esta sucursal.' });
            }
        }

        const nuevaCaja = await Caja.create({
            id_sucursal,
            fecha: new Date().toISOString().slice(0, 10),
            saldo_inicial: saldoInicialIngresado,
            monto_inicial: parseFloat(monto_inicial) || saldoInicialIngresado,
            ingresos: 0.00,
            egresos: 0.00,
            saldo_final: saldoInicialIngresado.toFixed(2),
            estado: 'abierta',
            abierto_por: abierto_por || (req.user ? req.user.id : null)
        }, { transaction });

        await transaction.commit();
        res.status(201).json({ message: 'Caja abierta exitosamente.', caja: nuevaCaja });
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al abrir la caja:', error);
        res.status(500).json({ error: 'Error al abrir la caja.', detalle: error.message });
    }
};

exports.obtenerCajasHoy = async (req, res) => {
    try {
        const { id_sucursal, fecha } = req.query;

        if (!id_sucursal || !fecha) {
            return res.status(400).json({ error: 'Faltan parámetros id_sucursal o fecha.' });
        }

        const cajas = await Caja.findAll({
            where: { id_sucursal, fecha },
            include: [
                {
                    model: Usuario,
                    as: 'usuario_cierre',
                    attributes: ['nombre'],
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['nombre', 'direccion'],
                }
            ],
            order: [['createdAt', 'DESC']],
        });

        res.status(200).json(cajas);
    } catch (error) {
        console.error('Error al obtener cajas del día:', error);
        res.status(500).json({ error: 'Error al obtener cajas del día.', detalle: error.message });
    }
};

exports.obtenerEstadoCaja = async (req, res) => {
    try {
        const { id_sucursal_activa, id_sucursal } = req.query;

        let sucursalId;

        if (id_sucursal) {
            sucursalId = typeof id_sucursal === 'object' ?
                id_sucursal.id : id_sucursal;
        } else if (id_sucursal_activa) {
            sucursalId = typeof id_sucursal_activa === 'object' ?
                id_sucursal_activa.id : id_sucursal_activa;
        }

        if (typeof sucursalId === 'string' && sucursalId.startsWith('{')) {
            try {
                const parsed = JSON.parse(sucursalId);
                sucursalId = parsed.id;
            } catch (e) {}
        }

        if (!sucursalId) {
            return res.status(400).json({ error: 'Se requiere el ID de la sucursal activa.' });
        }

        const caja = await Caja.findOne({
            where: { id_sucursal: sucursalId },
            order: [['createdAt', 'DESC'], ['fecha', 'DESC']],
            include: [
                {
                    model: Usuario,
                    as: 'usuario_cierre',
                    attributes: ['nombre'],
                },
                {
                    model: Usuario,
                    as: 'usuario_apertura',
                    attributes: ['nombre'],
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['nombre', 'direccion'],
                }
            ],
        });

        if (!caja) {
            return res.status(200).json({ estado: 'no_existe', message: 'No se encontró ninguna caja para esta sucursal. Se debe abrir una nueva.' });
        }
        if (caja.estado === 'cerrada') {
            return res.status(200).json({ estado: 'cerrada', message: 'La última caja de esta sucursal está cerrada. Se debe abrir una nueva.', caja });
        }

        res.status(200).json({ estado: 'abierta', caja });
    } catch (error) {
        console.error('Error al obtener el estado de la caja:', error);
        res.status(500).json({ error: 'Error al obtener el estado de la caja.', detalle: error.message });
    }
};

exports.obtenerTodasCajas = async (req, res) => {
    try {
        const { id_sucursal } = req.query;

        if (!id_sucursal) {
            return res.status(400).json({ error: 'Se requiere el ID de la sucursal.' });
        }

        const cajas = await Caja.findAll({
            where: { id_sucursal },
            include: [
                {
                    model: Usuario,
                    as: 'usuario_cierre',
                    attributes: ['nombre'],
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['nombre', 'direccion'],
                }
            ],
            order: [['createdAt', 'DESC']],
        });

        res.status(200).json(cajas);
    } catch (error) {
        console.error('Error al obtener todas las cajas:', error);
        res.status(500).json({ error: 'Error al obtener todas las cajas.', detalle: error.message });
    }
};

exports.editarCaja = async (req, res) => {
    const transaction = await db.sequelize.transaction();
    try {
        const { id_sucursal, caja_id, saldo_inicial, ingresos, egresos } = req.body;

        if (!id_sucursal || !caja_id) {
            await transaction.rollback();
            return res.status(400).json({ error: 'Faltan datos necesarios para editar la caja.' });
        }

        const caja = await Caja.findOne({
            where: { id: caja_id, id_sucursal },
            transaction
        });

        if (!caja) {
            await transaction.rollback();
            return res.status(404).json({ error: 'Caja no encontrada para esta sucursal.' });
        }

        if (saldo_inicial !== undefined) {
            caja.saldo_inicial = parseFloat(saldo_inicial) || caja.saldo_inicial;
        }
        if (ingresos !== undefined) {
            caja.ingresos = parseFloat(ingresos) || caja.ingresos;
        }
        if (egresos !== undefined) {
            caja.egresos = parseFloat(egresos) || caja.egresos;
        }

        caja.saldo_final = (parseFloat(caja.saldo_inicial) + parseFloat(caja.ingresos) - parseFloat(caja.egresos)).toFixed(2);

        await caja.save({ transaction });

        await transaction.commit();
        res.status(200).json({ message: 'Caja editada exitosamente.', caja });
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al editar la caja:', error);
        res.status(500).json({ error: 'Error al editar la caja.', detalle: error.message });
    }
};

exports.registrarEgreso = async (req, res) => {
    const { caja_id } = req.params;
    const { monto, justificacion, id_usuario } = req.body;

    const userId = req.user ? req.user.id : (id_usuario || null);

    if (!caja_id) {
        return res.status(400).json({ error: 'Se requiere el ID de la caja.' });
    }

    if (isNaN(monto) || monto <= 0) {
        return res.status(400).json({ error: 'Monto de egreso inválido.' });
    }

    if (!userId) {
        return res.status(400).json({ error: 'Se requiere el ID del usuario.' });
    }

    const transaction = await db.sequelize.transaction();
    try {
        const caja = await Caja.findOne({
            where: { id: caja_id, estado: 'abierta' },
            transaction
        });

        if (!caja) {
            await transaction.rollback();
            return res.status(404).json({ error: 'Caja no encontrada o ya está cerrada.' });
        }

        if (monto > parseFloat(caja.saldo_final)) {
            await transaction.rollback();
            return res.status(400).json({ error: 'El monto del egreso excede el saldo disponible.' });
        }

        await db.Egreso.create({
            monto: monto,
            justificacion: justificacion,
            id_caja: caja.id,
            id_usuario: userId,
            fecha: new Date()
        }, { transaction });

        caja.egresos = parseFloat(caja.egresos) + parseFloat(monto);
        caja.saldo_final = (parseFloat(caja.saldo_inicial) + parseFloat(caja.ingresos) - parseFloat(caja.egresos)).toFixed(2);

        if (justificacion) {
            caja.justificacion = justificacion;
        }

        await caja.save({ transaction });
        await transaction.commit();

        res.status(200).json({ message: 'Egreso registrado exitosamente.', egresos: caja.egresos, saldo_final: caja.saldo_final });
    } catch (error) {
        if (transaction.finished !== 'commit') {
            await transaction.rollback();
        }
        console.error('Error al registrar egreso:', error);
        res.status(500).json({ error: 'Error interno al registrar el egreso.' });
    }
};

exports.obtenerHistorialCajas = async (req, res) => {
    try {
        const { id_sucursal, fecha_inicio, fecha_fin } = req.query;
        const whereClause = {};

        let sucursalId = id_sucursal;
        if (typeof id_sucursal === 'object') {
            sucursalId = id_sucursal.id;
        } else if (typeof id_sucursal === 'string') {
            if (id_sucursal.startsWith('{')) {
                try {
                    const parsed = JSON.parse(id_sucursal);
                    sucursalId = parsed.id;
                } catch (e) {}
            } else {
                sucursalId = parseInt(id_sucursal);
            }
        }

        if (sucursalId) {
            whereClause.id_sucursal = sucursalId;
        } else {
            return res.status(400).json({ error: 'Se requiere un ID de sucursal válido' });
        }

        if (fecha_inicio && fecha_fin) {
            whereClause.fecha = {
                [db.Sequelize.Op.between]: [fecha_inicio, fecha_fin]
            };
        }

        const cajas = await Caja.findAll({
            where: whereClause,
            include: [
                {
                    model: Usuario,
                    as: 'usuario_cierre',
                    attributes: ['nombre'],
                    required: false
                },
                {
                    model: Usuario,
                    as: 'usuario_apertura',
                    attributes: ['nombre'],
                    required: false
                },
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['nombre']
                }
            ],
            order: [['fecha', 'DESC'], ['createdAt', 'DESC']],
        });

        res.status(200).json(cajas);
    } catch (error) {
        console.error('Error al obtener historial de cajas:', error);
        res.status(500).json({ error: 'Error al obtener historial de cajas.' });
    }
};

exports.obtenerResumenCaja = async (req, res) => {
    try {
        const { id_caja } = req.params;

        if (!id_caja) {
            return res.status(400).json({ error: 'Se requiere el ID de la caja.' });
        }

        const caja = await Caja.findByPk(id_caja, {
            include: [
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['nombre']
                },
                {
                    model: Usuario,
                    as: 'usuario_apertura',
                    attributes: ['nombre']
                },
                {
                    model: Usuario,
                    as: 'usuario_cierre',
                    attributes: ['nombre']
                }
            ]
        });

        if (!caja) {
            return res.status(404).json({ error: 'Caja no encontrada.' });
        }

        const fechaInicio = caja.createdAt;
        const fechaFin = caja.fecha_cierre || new Date();

        const ventas = await db.Venta.findAll({
            where: {
                id_sucursal: caja.id_sucursal,
                createdAt: {
                    [db.Sequelize.Op.between]: [fechaInicio, fechaFin]
                }
            },
            include: [
                {
                    model: Usuario,
                    as: 'usuario',
                    attributes: ['id', 'nombre']
                }
            ]
        });

        let egresosDetallados = [];
        try {
            egresosDetallados = await db.Egreso.findAll({
                where: {
                    id_caja: caja.id
                },
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre']
                    }
                ]
            });
        } catch (err) {}

        const resumenUsuarios = {};

        ventas.forEach(venta => {
            const userId = venta.id_usuario;
            const usuarioObj = venta.usuario;
            const monto = parseFloat(venta.monto_total);

            if (!resumenUsuarios[userId]) {
                resumenUsuarios[userId] = {
                    id: userId,
                    nombre: usuarioObj ? usuarioObj.nombre : 'Desconocido',
                    foto_url: null,
                    total_ventas: 0,
                    cantidad_ventas: 0,
                    total_egresos: 0,
                    cantidad_egresos: 0
                };
            }

            resumenUsuarios[userId].total_ventas += monto;
            resumenUsuarios[userId].cantidad_ventas += 1;
        });

        egresosDetallados.forEach(egreso => {
            const userId = egreso.id_usuario;
            const usuarioObj = egreso.usuario;
            const monto = parseFloat(egreso.monto);

            if (!resumenUsuarios[userId]) {
                resumenUsuarios[userId] = {
                    id: userId,
                    nombre: usuarioObj ? usuarioObj.nombre : 'Desconocido',
                    foto_url: null,
                    total_ventas: 0,
                    cantidad_ventas: 0,
                    total_egresos: 0,
                    cantidad_egresos: 0
                };
            }
            resumenUsuarios[userId].total_egresos += monto;
            resumenUsuarios[userId].cantidad_egresos += 1;
        });

        const desgloseUsuarios = Object.values(resumenUsuarios);
        const totalVentasPeriodo = desgloseUsuarios.reduce((acc, curr) => acc + curr.total_ventas, 0);
        const totalEgresosPeriodo = desgloseUsuarios.reduce((acc, curr) => acc + curr.total_egresos, 0);

        res.status(200).json({
            caja,
            desglose_usuarios: desgloseUsuarios,
            total_ventas_periodo: totalVentasPeriodo,
            total_egresos_periodo: totalEgresosPeriodo,
            usuario_apertura: caja.usuario_apertura ? caja.usuario_apertura.nombre : 'Sistema',
            usuario_cierre: caja.usuario_cierre ? caja.usuario_cierre.nombre : (caja.estado === 'cerrada' ? 'Sistema' : null)
        });

    } catch (error) {
        console.error('Error al obtener resumen de caja:', error);
        res.status(500).json({ error: 'Error al obtener resumen de caja.', detalle: error.message });
    }
};
