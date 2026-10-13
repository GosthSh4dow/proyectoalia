const { Boleta, Usuario, Asistencia, sequelize } = require('../models');
const { Op } = require('sequelize');
const moment = require('moment');

module.exports = {
    async getAllBoletas(req, res) {
        try {
            const { fechaInicio, fechaFin, usuarioId } = req.query;

            const whereCondition = {};

            if (fechaInicio && fechaFin) {
                whereCondition.fecha_pago = {
                    [Op.between]: [fechaInicio, fechaFin]
                };
            }

            if (usuarioId) {
                whereCondition.id_usuario = usuarioId;
            }

            const boletas = await Boleta.findAll({
                where: whereCondition,
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'email', 'rol']
                    }
                ],
                order: [['fecha_pago', 'DESC']]
            });

            res.status(200).json(boletas);
        } catch (error) {
            console.error('Error al obtener todas las boletas:', error);
            res.status(500).json({ error: 'Error al obtener las boletas' });
        }
    },

    async getBoletaById(req, res) {
        try {
            const { id } = req.params;

            const boleta = await Boleta.findByPk(id, {
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'email', 'rol']
                    }
                ]
            });

            if (!boleta) {
                return res.status(404).json({ error: 'Boleta no encontrada' });
            }

            res.status(200).json(boleta);
        } catch (error) {
            console.error('Error al obtener la boleta:', error);
            res.status(500).json({ error: 'Error al obtener la boleta' });
        }
    },

    async createBoleta(req, res) {
        const transaction = await sequelize.transaction();
        try {
            const {
                id_usuario,
                monto_turno,
                total,
                asistencias_count,
                faltas_injustificadas,
                faltas_justificadas,
                reemplazos_count,
                turnos_reemplazados,
                fecha_pago,
                fecha_inicio,
                fecha_fin
            } = req.body;

            if (!id_usuario || !fecha_pago || !monto_turno || !total || asistencias_count === undefined) {
                await transaction.rollback();
                return res.status(400).json({ error: 'Faltan campos requeridos para crear la boleta' });
            }

            const boletaExistente = await Boleta.findOne({
                where: {
                    id_usuario,
                    fecha_pago
                },
                transaction
            });

            if (boletaExistente) {
                await transaction.rollback();
                return res.status(409).json({ error: 'Ya existe una boleta para este usuario en este período' });
            }

            const nuevaBoleta = await Boleta.create({
                id_usuario,
                monto_turno,
                total,
                asistencias_count,
                faltas_injustificadas: faltas_injustificadas || 0,
                faltas_justificadas: faltas_justificadas || 0,
                reemplazos_count: reemplazos_count || 0,
                turnos_reemplazados: turnos_reemplazados || 0,
                fecha_pago
            }, { transaction });

            if (fecha_inicio && fecha_fin) {
                await Asistencia.update(
                    { pagado: true },
                    {
                        where: {
                            id_usuario,
                            fecha: {
                                [Op.between]: [fecha_inicio, fecha_fin]
                            }
                        },
                        transaction
                    }
                );
            }

            await transaction.commit();

            const boletaConUsuario = await Boleta.findByPk(nuevaBoleta.id, {
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'email', 'rol']
                    }
                ]
            });

            res.status(201).json({
                message: 'Boleta creada exitosamente',
                boleta: boletaConUsuario
            });
        } catch (error) {
            await transaction.rollback();
            console.error('Error al crear la boleta:', error);
            res.status(500).json({ error: 'Error al crear la boleta' });
        }
    },
};
