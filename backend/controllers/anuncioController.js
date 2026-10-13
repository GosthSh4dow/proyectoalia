const db = require('../models');
const Anuncio = db.Anuncio;
const Usuario = db.Usuario;
const { Op } = require('sequelize');
const moment = require('moment');
const path = require('path');
const fs = require('fs');

const procesarImagen = (archivo) => {
  return new Promise((resolve, reject) => {
    const nombreImagen = Date.now() + '_' + Math.random().toString(36).substring(2, 15) + path.extname(archivo.name);
    const rutaImagen = path.join(__dirname, '..', 'uploads', nombreImagen);
    archivo.mv(rutaImagen, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve('/uploads/' + nombreImagen);
      }
    });
  });
};

const procesarLottie = (archivo) => {
  return new Promise((resolve, reject) => {
    const animDir = path.join(__dirname, '..', 'uploads', 'animaciones');
    if (!fs.existsSync(animDir)) {
      fs.mkdirSync(animDir, { recursive: true });
    }
    const nombreAnim = Date.now() + '_' + Math.random().toString(36).substring(2, 15) + path.extname(archivo.name);
    const rutaAnim = path.join(animDir, nombreAnim);
    archivo.mv(rutaAnim, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve('/uploads/animaciones/' + nombreAnim);
      }
    });
  });
};

exports.crearAnuncio = async (req, res) => {
  try {
    let imagenUrl = null;
    let lottieUrl = null;
    if (req.files && req.files.imagen) {
      try {
        imagenUrl = await procesarImagen(req.files.imagen);
      } catch (error) {
        console.error('Error al procesar imagen:', error);
        return res.status(500).json({ error: 'Error al procesar la imagen' });
      }
    }
    if (req.files && req.files.lottie_json) {
      try {
        lottieUrl = await procesarLottie(req.files.lottie_json);
      } catch (error) {
        console.error('Error al procesar animación Lottie:', error);
        return res.status(500).json({ error: 'Error al procesar la animación' });
      }
    } else if (req.body.lottie_json_url) {
      lottieUrl = req.body.lottie_json_url;
    }

    const {
      titulo,
      mensaje,
      tipo,
      fecha_inicio,
      fecha_expiracion,
      activo,
      bloqueante
    } = req.body;

    const id_usuario_creador = req.user?.id || req.body.id_usuario_creador;
    if (!id_usuario_creador) {
      return res.status(400).json({ error: 'Usuario creador requerido' });
    }

    const anuncio = await Anuncio.create({
      titulo,
      mensaje,
      tipo,
      imagen: imagenUrl,
      fecha_inicio,
      fecha_expiracion,
      activo: activo === 'true' || activo === true,
      bloqueante: bloqueante === 'true' || bloqueante === true,
      lottie_json: lottieUrl,
      id_usuario_creador
    });

    res.status(201).json(anuncio);
  } catch (error) {
    console.error('Error al crear anuncio:', error);
    res.status(500).json({ error: 'Error al crear anuncio' });
  }
};

exports.obtenerAnuncios = async (req, res) => {
  try {
    const anuncios = await Anuncio.findAll({
      include: [{ model: Usuario, as: 'creador', attributes: ['id', 'nombre', 'email'] }],
      order: [['fecha_inicio', 'DESC']]
    });
    res.status(200).json(anuncios);
  } catch (error) {
    console.error('Error al obtener anuncios:', error);
    res.status(500).json({ error: 'Error al obtener anuncios' });
  }
};

exports.obtenerAnunciosActivos = async (req, res) => {
  try {
    const now = moment().toDate();
    let anuncios = await Anuncio.findAll({
      where: {
        activo: true,
        fecha_inicio: { [Op.lte]: now },
        fecha_expiracion: { [Op.gte]: now }
      },
      include: [{ model: Usuario, as: 'creador', attributes: ['id', 'nombre', 'email'] }],
      order: [['fecha_inicio', 'DESC']]
    });
    const expirados = await Anuncio.findAll({
      where: {
        activo: true,
        fecha_expiracion: { [Op.lt]: now }
      }
    });
    for (const anuncio of expirados) {
      await anuncio.update({ activo: false });
    }
    res.status(200).json(anuncios);
  } catch (error) {
    console.error('Error al obtener anuncios activos:', error);
    res.status(500).json({ error: 'Error al obtener anuncios activos' });
  }
};

exports.obtenerAnuncio = async (req, res) => {
  try {
    const anuncio = await Anuncio.findByPk(req.params.id, {
      include: [{ model: Usuario, as: 'creador', attributes: ['id', 'nombre', 'email'] }]
    });
    if (!anuncio) {
      return res.status(404).json({ error: 'Anuncio no encontrado' });
    }
    res.status(200).json(anuncio);
  } catch (error) {
    console.error('Error al obtener anuncio:', error);
    res.status(500).json({ error: 'Error al obtener anuncio' });
  }
};

exports.actualizarAnuncio = async (req, res) => {
  try {
    const anuncio = await Anuncio.findByPk(req.params.id);
    if (!anuncio) {
      return res.status(404).json({ error: 'Anuncio no encontrado' });
    }
    let imagenUrl = anuncio.imagen;
    let lottieUrl = anuncio.lottie_json;
    if (req.files && req.files.imagen) {
      try {
        if (anuncio.imagen) {
          const rutaAnterior = path.join(__dirname, '..', anuncio.imagen);
          if (fs.existsSync(rutaAnterior)) {
            fs.unlinkSync(rutaAnterior);
          }
        }
        imagenUrl = await procesarImagen(req.files.imagen);
      } catch (error) {
        console.error('Error al procesar nueva imagen:', error);
        return res.status(500).json({ error: 'Error al procesar la imagen' });
      }
    }
    if (req.files && req.files.lottie_json) {
      try {
        if (anuncio.lottie_json) {
          const rutaAnterior = path.join(__dirname, '..', anuncio.lottie_json);
          if (fs.existsSync(rutaAnterior)) {
            fs.unlinkSync(rutaAnterior);
          }
        }
        lottieUrl = await procesarLottie(req.files.lottie_json);
      } catch (error) {
        console.error('Error al procesar nueva animación Lottie:', error);
        return res.status(500).json({ error: 'Error al procesar la animación' });
      }
    } else if (req.body.lottie_json_url) {
      lottieUrl = req.body.lottie_json_url;
    }

    const {
      titulo,
      mensaje,
      tipo,
      fecha_inicio,
      fecha_expiracion,
      activo,
      bloqueante
    } = req.body;

    await anuncio.update({
      titulo: titulo || anuncio.titulo,
      mensaje: mensaje || anuncio.mensaje,
      tipo: tipo || anuncio.tipo,
      imagen: imagenUrl,
      fecha_inicio: fecha_inicio || anuncio.fecha_inicio,
      fecha_expiracion: fecha_expiracion || anuncio.fecha_expiracion,
      activo: activo === 'true' || activo === true,
      bloqueante: bloqueante === 'true' || bloqueante === true,
      lottie_json: lottieUrl,
    });

    res.status(200).json(anuncio);
  } catch (error) {
    console.error('Error al actualizar anuncio:', error);
    res.status(500).json({ error: 'Error al actualizar anuncio' });
  }
};

exports.eliminarAnuncio = async (req, res) => {
  try {
    const anuncio = await Anuncio.findByPk(req.params.id);
    if (!anuncio) {
      return res.status(404).json({ error: 'Anuncio no encontrado' });
    }
    await anuncio.destroy();
    res.status(200).json({ message: 'Anuncio eliminado correctamente' });
  } catch (error) {
    console.error('Error al eliminar anuncio:', error);
    res.status(500).json({ error: 'Error al eliminar anuncio' });
  }
};
