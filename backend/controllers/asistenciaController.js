const db = require('../models');
const { Op } = require('sequelize');
const moment = require('moment');
const Asistencia = db.Asistencia;
const Usuario = db.Usuario;
const Boleta = db.Boleta;

module.exports = {
    async getAsistenciasByUsuario(req, res) {
        try {
            const usuarioId = req.params.usuarioId;
            const { fechaInicio, fechaFin } = req.query;

            if (!usuarioId) {
                return res.status(400).json({ error: 'ID de usuario es requerido' });
            }

            const ultimaBoleta = await Boleta.findOne({
                where: { id_usuario: usuarioId },
                order: [['fecha_pago', 'DESC']]
            });

            const whereCondition = { id_usuario: usuarioId };

            if (ultimaBoleta) {
                const fechaUltimaBoleta = moment(ultimaBoleta.fecha_pago).format('YYYY-MM-DD');
                whereCondition.fecha = {
                    [Op.gt]: fechaUltimaBoleta
                };
            }

            if (fechaInicio && fechaFin) {
                whereCondition.fecha = {
                    [Op.between]: [fechaInicio, fechaFin]
                };
            }

            const asistencias = await Asistencia.findAll({
                where: whereCondition,
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'rol'],
                        required: false
                    },
                    {
                        model: Usuario,
                        as: 'reemplazo',
                        attributes: ['id', 'nombre', 'rol'],
                        required: false
                    }
                ],
                order: [['fecha', 'DESC']]
            });

            const whereReemplazos = { reemplazo_id: usuarioId };

            if (whereCondition.fecha) {
                whereReemplazos.fecha = whereCondition.fecha;
            }

            const reemplazosHechos = await Asistencia.findAll({
                where: whereReemplazos,
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'rol'],
                        required: true
                    }
                ],
                order: [['fecha', 'DESC']]
            });

            const noTieneRegistros = asistencias.length === 0 && reemplazosHechos.length === 0;

            let mensaje = null;
            if (noTieneRegistros) {
                if (ultimaBoleta) {
                    mensaje = `El usuario no tiene registros de asistencia desde el ${moment(ultimaBoleta.fecha_pago).format('DD/MM/YYYY')} (fecha de su última boleta).`;
                } else {
                    mensaje = 'El usuario no tiene registros de asistencia ni boletas generadas.';
                }
            }

            res.json({
                asistencias,
                reemplazosHechos,
                ultimaBoleta: ultimaBoleta ? {
                    id: ultimaBoleta.id,
                    fecha_pago: ultimaBoleta.fecha_pago
                } : null,
                mensaje
            });
        } catch (error) {
            console.error('Error al obtener asistencias:', error);
            res.status(500).json({ error: 'Error al obtener asistencias' });
        }
    },

    async updateAsistencia(req, res) {
        try {
            const { id } = req.params;
            const asistencia = await Asistencia.findByPk(id);
            if (!asistencia) {
                return res.status(404).json({ error: 'Asistencia no encontrada' });
            }

            const { estado, justificado, reemplazo } = req.body;

            asistencia.estado = estado;
            asistencia.justificado = justificado;
            asistencia.reemplazo_id = reemplazo ? reemplazo : null;

            await asistencia.save();

            res.json(asistencia);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    },

    async crearAsistencia(req, res) {
        try {
            const { id_usuario, ingreso, salida, reemplazo_id } = req.body;
            const fechaHoy = moment().format('YYYY-MM-DD');

            const usuario = await Usuario.findByPk(id_usuario);
            if (!usuario) {
                return res.status(404).json({ error: 'Usuario no encontrado' });
            }

            const asistenciaExistente = await Asistencia.findOne({
                where: {
                    id_usuario,
                    fecha: fechaHoy,
                    reemplazo_id: null
                }
            });

            if (asistenciaExistente && !reemplazo_id) {
                return res.status(409).json({
                    error: 'Ya marcaste un ingreso hoy',
                    asistencia: asistenciaExistente
                });
            }

            if (reemplazo_id) {
                const usuarioReemplazado = await Usuario.findByPk(reemplazo_id);
                if (!usuarioReemplazado) {
                    return res.status(404).json({ error: 'Usuario a reemplazar no encontrado' });
                }

                const reemplazoExistente = await Asistencia.findOne({
                    where: {
                        id_usuario,
                        fecha: fechaHoy,
                        reemplazo_id
                    }
                });

                if (reemplazoExistente) {
                    return res.status(409).json({
                        error: 'Ya estás reemplazando a esta persona hoy',
                        asistencia: reemplazoExistente
                    });
                }
            }

            const ultimaAsistencia = await Asistencia.findOne({
                where: {
                    id_usuario,
                },
                order: [['fecha', 'DESC']],
            });

            let fechaUltimaAsistencia = ultimaAsistencia ? moment(ultimaAsistencia.fecha) : null;

            if (!fechaUltimaAsistencia) {
                fechaUltimaAsistencia = moment('2024-01-01');
            }

            if (ultimaAsistencia && !fechaUltimaAsistencia.isSame(fechaHoy, 'day') && !reemplazo_id) {
                let fechaARegistrar = fechaUltimaAsistencia.clone().add(1, 'days');
                while (fechaARegistrar.isBefore(moment(fechaHoy), 'day')) {
                    const diaARegistrar = fechaARegistrar.format('YYYY-MM-DD');
                    const diaSemana = fechaARegistrar.day();

                    if (diaSemana !== 0 && diaSemana !== 6) {
                        const asistenciaExistente = await Asistencia.findOne({
                            where: {
                                id_usuario,
                                fecha: diaARegistrar,
                            }
                        });

                        if (!asistenciaExistente) {
                            await Asistencia.create({
                                id_usuario,
                                fecha: diaARegistrar,
                                ingreso: '00:00',
                                salida: '00:00',
                                estado: 'Falta',
                                justificado: false,
                            });
                        }
                    }

                    fechaARegistrar = fechaARegistrar.add(1, 'days');
                }
            }

            if (reemplazo_id) {
                const asistenciaReemplazado = await Asistencia.findOne({
                    where: {
                        id_usuario: reemplazo_id,
                        fecha: fechaHoy,
                    }
                });

                if (!asistenciaReemplazado) {
                    await Asistencia.create({
                        id_usuario: reemplazo_id,
                        fecha: fechaHoy,
                        ingreso: '00:00',
                        salida: '00:00',
                        estado: 'Falta',
                        justificado: true,
                        reemplazo_id: id_usuario,
                    });
                } else {
                    await asistenciaReemplazado.update({
                        estado: 'Falta',
                        justificado: true,
                        reemplazo_id: id_usuario,
                    });
                }
            }

            const asistencia = await Asistencia.create({
                id_usuario,
                fecha: fechaHoy,
                ingreso: ingreso,
                salida: salida || null,
                estado: reemplazo_id ? 'Reemplazo' : 'Asistido',
                justificado: null,
                reemplazo_id: reemplazo_id || null,
            });

            res.status(201).json({
                message: `Asistencia registrada exitosamente${reemplazo_id ? ' como reemplazo' : ''}`,
                asistencia: {
                    id: asistencia.id,
                    fecha: fechaHoy,
                    ingreso: asistencia.ingreso,
                    salida: asistencia.salida,
                    estado: asistencia.estado,
                    reemplazo: asistencia.reemplazo_id ? true : false,
                    reemplazo_id: asistencia.reemplazo_id
                },
            });
        } catch (error) {
            console.error('Error al crear la asistencia:', error);
            res.status(500).json({
                error: 'Error al crear la asistencia',
                details: error.message
            });
        }
    },

    async registrarReemplazoAdicional(req, res) {
        try {
            const { id_usuario, id_usuario_reemplazado, ingreso, salida } = req.body;
            const fechaHoy = moment().format('YYYY-MM-DD');

            if (id_usuario === id_usuario_reemplazado) {
                return res.status(400).json({
                    error: 'No puedes reemplazarte a ti mismo'
                });
            }

            const usuario = await Usuario.findByPk(id_usuario);
            const usuarioReemplazado = await Usuario.findByPk(id_usuario_reemplazado);

            if (!usuario || !usuarioReemplazado) {
                return res.status(404).json({
                    error: 'Uno o ambos usuarios no fueron encontrados'
                });
            }

            const asistenciaPrevia = await Asistencia.findOne({
                where: {
                    id_usuario,
                    fecha: fechaHoy,
                    reemplazo_id: null
                }
            });

            const faltaReemplazoExistente = await Asistencia.findOne({
                where: {
                    id_usuario: id_usuario_reemplazado,
                    fecha: fechaHoy,
                    estado: 'Falta',
                    justificado: true
                }
            });

            if (faltaReemplazoExistente) {
                await faltaReemplazoExistente.update({
                    reemplazo_id: id_usuario
                });
            } else {
                await Asistencia.create({
                    id_usuario: id_usuario_reemplazado,
                    fecha: fechaHoy,
                    ingreso: '00:00',
                    salida: '00:00',
                    estado: 'Falta',
                    justificado: true,
                    reemplazo_id: id_usuario
                });
            }

            const reemplazoAsistencia = await Asistencia.create({
                id_usuario,
                fecha: fechaHoy,
                ingreso: ingreso || moment().format('HH:mm:ss'),
                salida: salida || null,
                estado: 'Reemplazo',
                justificado: null,
                reemplazo_id: id_usuario_reemplazado
            });

            res.status(201).json({
                message: 'Reemplazo adicional registrado exitosamente',
                asistencia: reemplazoAsistencia,
                asistenciaNormal: asistenciaPrevia || null
            });
        } catch (error) {
            console.error('Error al registrar reemplazo adicional:', error);
            res.status(500).json({
                error: 'Error al registrar reemplazo adicional',
                details: error.message
            });
        }
    },

    async registrarSalida(req, res) {
        try {
            const { id_usuario, salida, id_asistencia } = req.body;
            const fechaHoy = moment().format('YYYY-MM-DD');

            let whereCondition = {
                id_usuario,
                fecha: fechaHoy,
                ingreso: { [Op.ne]: null },
                salida: null,
            };

            if (id_asistencia) {
                whereCondition = { id: id_asistencia, salida: null };
            }

            const asistenciaHoy = await Asistencia.findOne({ where: whereCondition });

            if (!asistenciaHoy) {
                return res.status(400).json({
                    error: 'No se puede registrar la salida. No hay un registro de asistencia sin salida.',
                });
            }

            const actualizacion = await asistenciaHoy.update({
                salida: salida || moment().format('HH:mm:ss'),
                estado: asistenciaHoy.reemplazo_id ? 'Reemplazo' : 'Asistido',
            });

            res.status(200).json({
                message: 'Salida registrada correctamente',
                asistencia: {
                    id: actualizacion.id,
                    fecha: actualizacion.fecha,
                    ingreso: actualizacion.ingreso,
                    salida: actualizacion.salida,
                    estado: actualizacion.estado,
                    es_reemplazo: !!actualizacion.reemplazo_id,
                    reemplazando_a: actualizacion.reemplazo_id
                },
            });
        } catch (error) {
            console.error('Error al registrar la salida:', error);
            res.status(500).json({ error: 'Error al registrar la salida' });
        }
    },

    async getAsistenciasPendientes(req, res) {
        try {
            const usuarioId = req.params.id;
            const fechaHoy = moment().format('YYYY-MM-DD');

            if (!usuarioId) {
                return res.status(400).json({ error: 'ID de usuario es requerido' });
            }

            const asistenciasPendientes = await Asistencia.findAll({
                where: {
                    id_usuario: usuarioId,
                    fecha: fechaHoy,
                    ingreso: { [Op.ne]: null },
                    salida: null
                },
                include: [
                    {
                        model: Usuario,
                        as: 'reemplazo',
                        attributes: ['id', 'nombre'],
                        required: false
                    }
                ],
                order: [['ingreso', 'ASC']]
            });

            res.json(asistenciasPendientes);
        } catch (error) {
            console.error('Error al obtener asistencias pendientes:', error);
            res.status(500).json({ error: 'Error al obtener asistencias pendientes' });
        }
    },

    async getAsistenciasPorFecha(req, res) {
        try {
            const { fechaInicio, fechaFin, usuarioId } = req.query;

            if (!fechaInicio || !fechaFin) {
                return res.status(400).json({ error: 'Se requieren las fechas de inicio y fin' });
            }

            const whereCondition = {
                fecha: {
                    [Op.between]: [fechaInicio, fechaFin]
                }
            };

            if (usuarioId) {
                whereCondition.id_usuario = usuarioId;
            }

            const asistencias = await Asistencia.findAll({
                where: whereCondition,
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'rol'],
                        required: true
                    },
                    {
                        model: Usuario,
                        as: 'reemplazo',
                        attributes: ['id', 'nombre', 'rol'],
                        required: false
                    }
                ],
                order: [
                    ['id_usuario', 'ASC'],
                    ['fecha', 'DESC']
                ]
            });

            const reemplazosCondition = {
                fecha: {
                    [Op.between]: [fechaInicio, fechaFin]
                },
                estado: 'Falta',
                justificado: true
            };

            if (usuarioId) {
                reemplazosCondition.reemplazo_id = usuarioId;
            }

            const reemplazos = await Asistencia.findAll({
                where: reemplazosCondition,
                include: [
                    {
                        model: Usuario,
                        as: 'usuario',
                        attributes: ['id', 'nombre', 'rol'],
                        required: true
                    },
                    {
                        model: Usuario,
                        as: 'reemplazo',
                        attributes: ['id', 'nombre', 'rol'],
                        required: true
                    }
                ],
                order: [
                    ['reemplazo_id', 'ASC'],
                    ['fecha', 'DESC']
                ]
            });

            const asistenciasPorUsuario = {};

            asistencias.forEach(asistencia => {
                const userId = asistencia.id_usuario;
                if (!asistenciasPorUsuario[userId]) {
                    asistenciasPorUsuario[userId] = {
                        usuario: asistencia.usuario,
                        asistencias: [],
                        reemplazosHechos: []
                    };
                }
                asistenciasPorUsuario[userId].asistencias.push(asistencia);
            });

            reemplazos.forEach(reemplazo => {
                const reemplazanteId = reemplazo.reemplazo_id;
                if (!asistenciasPorUsuario[reemplazanteId]) {
                    asistenciasPorUsuario[reemplazanteId] = {
                        usuario: reemplazo.reemplazo,
                        asistencias: [],
                        reemplazosHechos: []
                    };
                }
                asistenciasPorUsuario[reemplazanteId].reemplazosHechos.push(reemplazo);
            });

            res.json({
                asistenciasPorUsuario: Object.values(asistenciasPorUsuario),
                totalUsuarios: Object.keys(asistenciasPorUsuario).length
            });
        } catch (error) {
            console.error('Error al obtener asistencias por fecha:', error);
            res.status(500).json({ error: 'Error al obtener asistencias por fecha' });
        }
    },
};
