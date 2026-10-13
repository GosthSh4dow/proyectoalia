const db = require('../models');
const Usuario = db.Usuario;
const RefreshToken = db.RefreshToken;
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');

const generateAccessToken = (usuario) => {
  return jwt.sign(
    {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol,
      id_sucursal: usuario.id_sucursal,
    },
    process.env.JWT_SECRET,
    { expiresIn: '2h' }
  );
};

const generateRefreshToken = (usuario) => {
  return jwt.sign(
    { id: usuario.id },
    process.env.REFRESH_TOKEN_SECRET || 'refresh-secret-key',
    { expiresIn: '7d' }
  );
};

const saveRefreshToken = async (userId, token) => {
  try {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await RefreshToken.create({
      token,
      user_id: userId,
      expires_at: expiresAt,
      revoked: false,
    });
  } catch (error) {
    console.error('Error al guardar refresh token:', error);
    throw error;
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'El correo electrónico y la contraseña son obligatorios.' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    const usuario = await Usuario.findOne({
      where: { email: normalizedEmail }
    });

    if (!usuario) {
      return res.status(400).json({ error: 'Credenciales inválidas. Usuario no encontrado.' });
    }

    let sucursalPrincipalInfo = null;
    if (usuario.id_sucursal) {
      const sucursalPrincipal = await db.Sucursal.findByPk(usuario.id_sucursal);
      sucursalPrincipalInfo = sucursalPrincipal ? sucursalPrincipal.toJSON() : null;
    }

    if (usuario.estado !== 'activado' && usuario.estado !== '1') {
      return res.status(403).json({ error: 'El usuario está inactivo. Contacta al administrador.' });
    }

    const isMatch = await bcrypt.compare(password, usuario.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'Credenciales inválidas. Contraseña incorrecta.' });
    }

    const token = generateAccessToken(usuario);
    const refreshToken = generateRefreshToken(usuario);

    try {
      await saveRefreshToken(usuario.id, refreshToken);

      const sucursalesDisponibles = await db.Sucursal.findAll({
        where: { estado: 'activa' }
      });

      res.status(200).json({
        message: 'Inicio de sesión exitoso.',
        token,
        refreshToken,
        usuario: {
          id: usuario.id,
          nombre: usuario.nombre,
          email: usuario.email,
          rol: usuario.rol,
          id_sucursal_principal: usuario.id_sucursal,
          sucursal: sucursalPrincipalInfo,
          estado: usuario.estado,
        },
        sucursales: sucursalesDisponibles
      });
    } catch (tokenError) {
      console.error('Error al guardar el token de refresco:', tokenError);
      res.status(200).json({
        message: 'Inicio de sesión exitoso (sin refresh token).',
        token,
        usuario: {
          id: usuario.id,
          nombre: usuario.nombre,
          email: usuario.email,
          rol: usuario.rol,
          id_sucursal_principal: usuario.id_sucursal,
          sucursal: sucursalPrincipalInfo,
          estado: usuario.estado,
        },
        sucursales: await db.Sucursal.findAll({ where: { estado: 'activa' } })
      });
    }
  } catch (error) {
    console.error('Error detallado al iniciar sesión:', error);
    res.status(500).json({ error: 'Error interno del servidor.' });
  }
};

exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token no proporcionado.' });
    }

    const tokenRecord = await RefreshToken.findOne({
      where: {
        token: refreshToken,
        revoked: false,
        expires_at: { [Op.gt]: new Date() }
      }
    });

    if (!tokenRecord) {
      return res.status(401).json({ error: 'Refresh token inválido o expirado.' });
    }

    try {
      const decoded = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET || 'refresh-secret-key');

      const usuario = await Usuario.findByPk(decoded.id);

      if (!usuario || (usuario.estado !== 'activado' && usuario.estado !== '1')) {
        return res.status(401).json({ error: 'Usuario no encontrado o inactivo.' });
      }

      const newToken = generateAccessToken(usuario);

      let sucursalPrincipalInfo = null;
      if (usuario.id_sucursal) {
        const sucursalPrincipal = await db.Sucursal.findByPk(usuario.id_sucursal);
        sucursalPrincipalInfo = sucursalPrincipal ? sucursalPrincipal.toJSON() : null;
      }

      const sucursalesDisponibles = await db.Sucursal.findAll({
        where: { estado: 'activa' }
      });

      res.status(200).json({
        token: newToken,
        usuario: {
          id: usuario.id,
          nombre: usuario.nombre,
          email: usuario.email,
          rol: usuario.rol,
          id_sucursal_principal: usuario.id_sucursal,
          sucursal: sucursalPrincipalInfo,
          estado: usuario.estado,
        },
        sucursales: sucursalesDisponibles
      });

    } catch (error) {
      return res.status(401).json({ error: 'Refresh token inválido.' });
    }
  } catch (error) {
    console.error('Error al renovar token:', error);
    res.status(500).json({ error: 'Error interno del servidor.' });
  }
};

exports.logout = async (req, res) => {
  try {
    const { refreshToken, userId } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token no proporcionado.' });
    }

    const tokenRecord = await RefreshToken.findOne({ where: { token: refreshToken } });

    if (tokenRecord) {
      await tokenRecord.update({ revoked: true });
    }

    if (userId) {
      try {
        const currentTime = new Date();
        const horaActual = currentTime.toTimeString().split(' ')[0];
        const fechaHoy = currentTime.toISOString().split('T')[0];

        const asistenciasAbiertas = await db.Asistencia.findAll({
          where: {
            id_usuario: userId,
            fecha: fechaHoy,
            salida: null,
            [db.Sequelize.Op.not]: { ingreso: null }
          }
        });

        if (asistenciasAbiertas && asistenciasAbiertas.length > 0) {
          for (const asistencia of asistenciasAbiertas) {
            await asistencia.update({
              salida: horaActual,
              estado: asistencia.reemplazo_id ? 'Reemplazo' : 'Asistido'
            });
          }
        }
      } catch (asistenciaError) {
        console.error('Error al registrar hora de salida:', asistenciaError);
      }
    }

    res.status(200).json({ message: 'Sesión cerrada exitosamente.' });
  } catch (error) {
    console.error('Error al cerrar sesión:', error);
    res.status(500).json({ error: 'Error interno del servidor.' });
  }
};

exports.validateToken = async (req, res) => {
  res.status(200).json({ valid: true });
};
