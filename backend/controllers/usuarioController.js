const db = require('../models');
const Usuario = db.Usuario;
const bcrypt = require('bcrypt');

exports.obtenerUsuarios = async (req, res) => {
    try {
        const usuarios = await Usuario.findAll({ include: ['sucursal'] });
        res.status(200).json(usuarios);
    } catch (error) {
        console.error('Error al obtener usuarios:', error);
        res.status(500).json({ error: 'Error al obtener usuarios' });
    }
};

exports.obtenerUsuario = async (req, res) => {
    try {
        const usuario = await Usuario.findByPk(req.params.id, { include: ['sucursal'] });
        if (!usuario) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        res.status(200).json(usuario);
    } catch (error) {
        console.error('Error al obtener el usuario:', error);
        res.status(500).json({ error: 'Error al obtener el usuario' });
    }
};

exports.crearUsuario = async (req, res) => {
    try {
        const { nombre, email, password, rol, id_sucursal, estado, hora_entrada, hora_salida, turno } = req.body;

        if (!nombre || !email || !password || !rol || !id_sucursal || !hora_entrada || !hora_salida || !turno) {
            return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
        }

        const usuarioExistente = await Usuario.findOne({ where: { email } });
        if (usuarioExistente) {
            return res.status(400).json({ error: 'El correo electrónico ya está registrado.' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const usuario = await Usuario.create({
            nombre,
            email,
            password: hashedPassword,
            rol,
            id_sucursal,
            estado: estado || 'activado',
            hora_entrada,
            hora_salida,
            turno: turno || 'Mañana',
        });

        res.status(201).json(usuario);
    } catch (error) {
        console.error('Error al crear usuario:', error);
        res.status(500).json({ error: 'Error al crear el usuario' });
    }
};

exports.actualizarUsuario = async (req, res) => {
    try {
        const usuario = await Usuario.findByPk(req.params.id);
        if (!usuario) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const { nombre, email, password, rol, id_sucursal, estado, hora_entrada, hora_salida, turno } = req.body;

        let hashedPassword = usuario.password;
        if (password) {
            hashedPassword = await bcrypt.hash(password, 10);
        }

        await usuario.update({
            nombre: nombre || usuario.nombre,
            email: email || usuario.email,
            password: hashedPassword,
            rol: rol || usuario.rol,
            id_sucursal: id_sucursal || usuario.id_sucursal,
            estado: estado || usuario.estado,
            hora_entrada: hora_entrada || usuario.hora_entrada,
            hora_salida: hora_salida || usuario.hora_salida,
            turno: turno || usuario.turno,
        });

        res.status(200).json(usuario);
    } catch (error) {
        console.error('Error al actualizar usuario:', error);
        res.status(500).json({ error: 'Error al actualizar el usuario' });
    }
};

exports.eliminarUsuario = async (req, res) => {
    try {
        const usuario = await Usuario.findByPk(req.params.id);
        if (!usuario) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        await usuario.destroy();
        res.status(200).json({ message: 'Usuario eliminado correctamente' });
    } catch (error) {
        console.error('Error al eliminar usuario:', error);
        res.status(500).json({ error: 'Error al eliminar el usuario' });
    }
};
