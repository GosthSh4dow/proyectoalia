const db = require('../models');
const CatalogoInfo = db.CatalogoInfo;
const path = require('path');
const fs = require('fs');

const procesarImagen = (archivo, tipo = 'general') => {
  return new Promise((resolve, reject) => {
    let carpetaDestino = 'uploads';
    if (tipo === 'banner' || tipo === 'logo') {
      carpetaDestino = 'uploads/banner';
    }

    const rutaCarpeta = path.join(__dirname, '..', carpetaDestino);
    if (!fs.existsSync(rutaCarpeta)) {
      fs.mkdirSync(rutaCarpeta, { recursive: true });
    }

    const nombreImagen = Date.now() + '_' + Math.random().toString(36).substring(2, 15) + path.extname(archivo.name);
    const rutaImagen = path.join(rutaCarpeta, nombreImagen);
    
    archivo.mv(rutaImagen, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve('/' + carpetaDestino + '/' + nombreImagen);
      }
    });
  });
};

const eliminarImagen = (rutaImagen) => {
  if (!rutaImagen) return;
  
  const rutaCompleta = path.join(__dirname, '..', rutaImagen);
  if (fs.existsSync(rutaCompleta)) {
    try {
      fs.unlinkSync(rutaCompleta);
    } catch (error) {
      console.error('Error al eliminar imagen:', error);
    }
  }
};

exports.obtenerInfoPublica = async (req, res) => {
  try {
    const info = await CatalogoInfo.findOne({
      order: [['createdAt', 'DESC']]
    });

    if (!info) {
      return res.status(200).json({
        telefono: '+591 74842996',
        email: 'info@channels.com',
        direccion: 'Calle Omiste entre Sucre, frente a Impuestos Nacionales',
        horarios_semana: 'Lun-Sáb: 8:00-20:00',
        horarios_domingo: 'Dom: 9:00-14:00',
        facebook_url: 'https://www.facebook.com/share/1BJs4XPzVu/',
        instagram_url: 'https://www.instagram.com',
        tiktok_url: 'https://www.tiktok.com/@accesorioschannels',
        whatsapp_url: 'https://wa.me/59174842996',
        grupos_whatsapp: [
          { name: "Grupo 1", link: "https://chat.whatsapp.com/LqwALOUhgol9k9uFSgkijy", members: "250+", status: "activo" },
          { name: "Grupo 2", link: "https://chat.whatsapp.com/D8Z4wfqn730A2MXEqxLIT3", members: "230+", status: "activo" },
          { name: "Grupo 3", link: "https://chat.whatsapp.com/CToEbetZpr0KCdffPK3W4A", members: "200+", status: "activo" },
          { name: "Grupo 4", link: "https://chat.whatsapp.com/C9bLWNAGXwYIO82AtOG98E", members: "245+", status: "activo" },
          { name: "Grupo 5", link: "https://chat.whatsapp.com/Gqn3BZSy9a5JQpBZBH2G53", members: "210+", status: "nuevo" },
          { name: "Grupo 6", link: "https://chat.whatsapp.com/BUQSFdzGQQ4FS0Abp4HjJs", members: "190+", status: "activo" }
        ],
        descripcion_empresa: 'Bisutería Channels - Los mejores accesorios para ti',
        logo_url: null,
        banner_url: null,
        titulo_banner: "Channel's",
        subtitulo_banner: "Bisutería & Accesorios que Expresan tu Estilo Único",
        descripcion_banner: "Descubre nuestra colección exclusiva de bisutería y accesorios que complementan tu personalidad",
        boton_banner: "Explorar Colección",
        url_boton_banner: "#catalogo",
        activo: true
      });
    }

    res.status(200).json(info);
  } catch (error) {
    console.error('Error al obtener información del catálogo:', error);
    res.status(500).json({ error: 'Error al obtener información del catálogo' });
  }
};

exports.obtenerInfo = async (req, res) => {
  try {
    const info = await CatalogoInfo.findAll({
      order: [['createdAt', 'DESC']]
    });
    res.status(200).json(info);
  } catch (error) {
    console.error('Error al obtener información del catálogo:', error);
    res.status(500).json({ error: 'Error al obtener información del catálogo' });
  }
};

exports.obtenerInfoPorId = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }
    res.status(200).json(info);
  } catch (error) {
    console.error('Error al obtener información del catálogo:', error);
    res.status(500).json({ error: 'Error al obtener información del catálogo' });
  }
};

exports.crearInfo = async (req, res) => {
  try {
    let logoUrl = null;
    let bannerUrl = null;

    if (req.files && req.files.logo) {
      try {
        logoUrl = await procesarImagen(req.files.logo, 'logo');
      } catch (error) {
        console.error('Error al procesar logo:', error);
        return res.status(500).json({ error: 'Error al procesar el logo' });
      }
    }

    if (req.files && req.files.banner) {
      try {
        bannerUrl = await procesarImagen(req.files.banner, 'banner');
      } catch (error) {
        console.error('Error al procesar banner:', error);
        return res.status(500).json({ error: 'Error al procesar el banner' });
      }
    }

    let gruposWhatsappParsed = [];
    if (req.body.grupos_whatsapp) {
      try {
        gruposWhatsappParsed = typeof req.body.grupos_whatsapp === 'string' 
          ? JSON.parse(req.body.grupos_whatsapp)
          : req.body.grupos_whatsapp;
      } catch (error) {
        console.error('Error al parsear grupos_whatsapp:', error);
    }
    }

    const defaultValues = {
      telefono: '+591 74842996',
      email: 'info@channels.com',
      direccion: 'Calle Omiste entre Sucre, frente a Impuestos Nacionales',
      horarios_semana: 'Lun-Sáb: 8:00-20:00',
      horarios_domingo: 'Dom: 9:00-14:00',
      facebook_url: '',
      instagram_url: '',
      tiktok_url: '',
      whatsapp_url: '',
      grupos_whatsapp: [],
      descripcion_empresa: 'Bisutería Channels - Los mejores accesorios para ti',
      titulo_banner: "Channel's",
      subtitulo_banner: "Bisutería & Accesorios que Expresan tu Estilo Único",
      descripcion_banner: "Descubre nuestra colección exclusiva de bisutería y accesorios que complementan tu personalidad",
      boton_banner: "Explorar Colección",
      url_boton_banner: "#catalogo",
      activo: true
    };

    const createData = {
      ...defaultValues,
      ...req.body,
      grupos_whatsapp: gruposWhatsappParsed,
      logo_url: logoUrl,
      banner_url: bannerUrl,
      activo: req.body.activo === 'true' || req.body.activo === true || defaultValues.activo
    };

    const info = await CatalogoInfo.create(createData);
    res.status(201).json(info);
  } catch (error) {
    console.error('Error al crear información del catálogo:', error);
    res.status(500).json({ error: 'Error al crear información del catálogo' });
  }
};

exports.actualizarInfo = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    let logoUrl = info.logo_url;
    let bannerUrl = info.banner_url;

    if (req.files && req.files.logo) {
      try {
        eliminarImagen(info.logo_url);
        logoUrl = await procesarImagen(req.files.logo, 'logo');
      } catch (error) {
        console.error('Error al procesar nuevo logo:', error);
        return res.status(500).json({ error: 'Error al procesar el logo' });
      }
    }

    if (req.files && req.files.banner) {
      try {
        eliminarImagen(info.banner_url);
        bannerUrl = await procesarImagen(req.files.banner, 'banner');
      } catch (error) {
        console.error('Error al procesar nuevo banner:', error);
        return res.status(500).json({ error: 'Error al procesar el banner' });
      }
    }

    let gruposWhatsappParsed = info.grupos_whatsapp;
    if (req.body.grupos_whatsapp) {
      try {
        gruposWhatsappParsed = typeof req.body.grupos_whatsapp === 'string' 
          ? JSON.parse(req.body.grupos_whatsapp)
          : req.body.grupos_whatsapp;
      } catch (error) {
        console.error('Error al parsear grupos_whatsapp:', error);
      }
    }

    const updateData = {
      ...Object.keys(req.body).reduce((acc, key) => {
        if (req.body[key] !== undefined && req.body[key] !== null && req.body[key] !== '') {
          acc[key] = req.body[key];
        }
        return acc;
      }, {}),
      grupos_whatsapp: gruposWhatsappParsed,
      logo_url: logoUrl,
      banner_url: bannerUrl
    };

    if (req.body.activo !== undefined) {
      updateData.activo = req.body.activo === 'true' || req.body.activo === true;
    }

    await info.update(updateData);
    res.status(200).json(info);
  } catch (error) {
    console.error('Error al actualizar información del catálogo:', error);
    res.status(500).json({ error: 'Error al actualizar información del catálogo' });
  }
};

exports.eliminarInfo = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    if (info.logo_url) {
      eliminarImagen(info.logo_url);
    }

    if (info.banner_url) {
      eliminarImagen(info.banner_url);
    }

    await info.destroy();
    res.status(200).json({ message: 'Información del catálogo eliminada correctamente' });
  } catch (error) {
    console.error('Error al eliminar información del catálogo:', error);
    res.status(500).json({ error: 'Error al eliminar información del catálogo' });
  }
}; 

exports.eliminarBanner = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    if (info.banner_url) {
      eliminarImagen(info.banner_url);
      await info.update({ banner_url: null });
      res.status(200).json({ message: 'Banner eliminado correctamente' });
    } else {
      res.status(404).json({ error: 'No hay banner para eliminar' });
    }
  } catch (error) {
    console.error('Error al eliminar banner:', error);
    res.status(500).json({ error: 'Error al eliminar banner' });
  }
}; 

exports.agregarImagenBanner = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    if (!req.files || !req.files.imagen) {
      return res.status(400).json({ error: 'No se proporcionó ninguna imagen' });
    }

    const imagenUrl = await procesarImagen(req.files.imagen, 'banner');
    const imagenesActuales = info.banner_images || [];
    
    const nuevaImagen = {
      id: Date.now() + Math.random().toString(36).substring(2, 15),
      url: imagenUrl,
      titulo: req.body.titulo || 'Imagen del Banner',
      descripcion: req.body.descripcion || '',
      orden: imagenesActuales.length + 1,
      fecha_creacion: new Date().toISOString()
    };
    
    const nuevasImagenes = [...imagenesActuales, nuevaImagen];
    await info.update({ banner_images: nuevasImagenes });
    
    res.status(200).json({ 
      message: 'Imagen agregada correctamente',
      imagen: nuevaImagen
    });
  } catch (error) {
    console.error('Error al agregar imagen del banner:', error);
    res.status(500).json({ error: 'Error al agregar imagen del banner' });
  }
};

exports.eliminarImagenBanner = async (req, res) => {
  try {
    const { id, imagenId } = req.params;
    const info = await CatalogoInfo.findByPk(id);
    
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const imagenesActuales = info.banner_images || [];
    const imagenIndex = imagenesActuales.findIndex(img => img.id === imagenId);
    
    if (imagenIndex === -1) {
      return res.status(404).json({ error: 'Imagen no encontrada' });
    }

    const imagenAEliminar = imagenesActuales[imagenIndex];
    eliminarImagen(imagenAEliminar.url);
    
    const nuevasImagenes = imagenesActuales.filter(img => img.id !== imagenId);
    
    nuevasImagenes.forEach((img, index) => {
      img.orden = index + 1;
    });
    
    await info.update({ banner_images: nuevasImagenes });
    
    res.status(200).json({ 
      message: 'Imagen eliminada correctamente',
      imagenes: nuevasImagenes
    });
  } catch (error) {
    console.error('Error al eliminar imagen del banner:', error);
    res.status(500).json({ error: 'Error al eliminar imagen del banner' });
  }
};

exports.actualizarImagenBanner = async (req, res) => {
  try {
    const { id, imagenId } = req.params;
    const info = await CatalogoInfo.findByPk(id);
    
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const imagenesActuales = info.banner_images || [];
    const imagenIndex = imagenesActuales.findIndex(img => img.id === imagenId);
    
    if (imagenIndex === -1) {
      return res.status(404).json({ error: 'Imagen no encontrada' });
    }

    const imagenActualizada = {
      ...imagenesActuales[imagenIndex],
      titulo: req.body.titulo || imagenesActuales[imagenIndex].titulo,
      descripcion: req.body.descripcion || imagenesActuales[imagenIndex].descripcion
    };
    
    imagenesActuales[imagenIndex] = imagenActualizada;
    await info.update({ banner_images: imagenesActuales });
    
    res.status(200).json({ 
      message: 'Imagen actualizada correctamente',
      imagen: imagenActualizada
    });
  } catch (error) {
    console.error('Error al actualizar imagen del banner:', error);
    res.status(500).json({ error: 'Error al actualizar imagen del banner' });
  }
};

exports.reordenarImagenesBanner = async (req, res) => {
  try {
    const { id } = req.params;
    const { orden } = req.body;
    
    const info = await CatalogoInfo.findByPk(id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const imagenesActuales = info.banner_images || [];
    const imagenesReordenadas = [];
    
    orden.forEach((imagenId, index) => {
      const imagen = imagenesActuales.find(img => img.id === imagenId);
      if (imagen) {
        imagen.orden = index + 1;
        imagenesReordenadas.push(imagen);
      }
    });
    
    await info.update({ banner_images: imagenesReordenadas });
    
    res.status(200).json({ 
      message: 'Imágenes reordenadas correctamente',
      imagenes: imagenesReordenadas
    });
  } catch (error) {
    console.error('Error al reordenar imágenes del banner:', error);
    res.status(500).json({ error: 'Error al reordenar imágenes del banner' });
  }
}; 

exports.agregarImagenLogo = async (req, res) => {
  try {
    const info = await CatalogoInfo.findByPk(req.params.id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    if (!req.files || !req.files.imagen) {
      return res.status(400).json({ error: 'No se proporcionó ninguna imagen' });
    }

    const imagenUrl = await procesarImagen(req.files.imagen, 'banner');
    const logosActuales = info.logo_images || [];
    
    const nuevoLogo = {
      id: Date.now() + Math.random().toString(36).substring(2, 15),
      url: imagenUrl,
      titulo: req.body.titulo || 'Logo',
      descripcion: req.body.descripcion || '',
      orden: logosActuales.length + 1,
      fecha_creacion: new Date().toISOString()
    };
    
    const nuevosLogos = [...logosActuales, nuevoLogo];
    await info.update({ logo_images: nuevosLogos });
    
    res.status(200).json({ 
      message: 'Logo agregado correctamente',
      imagen: nuevoLogo
    });
  } catch (error) {
    console.error('Error al agregar logo:', error);
    res.status(500).json({ error: 'Error al agregar logo' });
  }
};

exports.eliminarImagenLogo = async (req, res) => {
  try {
    const { id, imagenId } = req.params;
    const info = await CatalogoInfo.findByPk(id);
    
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const logosActuales = info.logo_images || [];
    const imagenIndex = logosActuales.findIndex(img => img.id === imagenId);
    
    if (imagenIndex === -1) {
      return res.status(404).json({ error: 'Logo no encontrado' });
    }

    const imagenAEliminar = logosActuales[imagenIndex];
    eliminarImagen(imagenAEliminar.url);
    
    const nuevosLogos = logosActuales.filter(img => img.id !== imagenId);
    
    nuevosLogos.forEach((img, index) => {
      img.orden = index + 1;
    });
    
    await info.update({ logo_images: nuevosLogos });
    
    res.status(200).json({ 
      message: 'Logo eliminado correctamente',
      imagenes: nuevosLogos
    });
  } catch (error) {
    console.error('Error al eliminar logo:', error);
    res.status(500).json({ error: 'Error al eliminar logo' });
  }
};

exports.actualizarImagenLogo = async (req, res) => {
  try {
    const { id, imagenId } = req.params;
    const info = await CatalogoInfo.findByPk(id);
    
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const logosActuales = info.logo_images || [];
    const imagenIndex = logosActuales.findIndex(img => img.id === imagenId);
    
    if (imagenIndex === -1) {
      return res.status(404).json({ error: 'Logo no encontrado' });
    }

    const imagenActualizada = {
      ...logosActuales[imagenIndex],
      titulo: req.body.titulo || logosActuales[imagenIndex].titulo,
      descripcion: req.body.descripcion || logosActuales[imagenIndex].descripcion
    };
    
    logosActuales[imagenIndex] = imagenActualizada;
    await info.update({ logo_images: logosActuales });
    
    res.status(200).json({ 
      message: 'Logo actualizado correctamente',
      imagen: imagenActualizada
    });
  } catch (error) {
    console.error('Error al actualizar logo:', error);
    res.status(500).json({ error: 'Error al actualizar logo' });
  }
};

exports.reordenarImagenesLogo = async (req, res) => {
  try {
    const { id } = req.params;
    const { orden } = req.body;
    
    const info = await CatalogoInfo.findByPk(id);
    if (!info) {
      return res.status(404).json({ error: 'Información del catálogo no encontrada' });
    }

    const logosActuales = info.logo_images || [];
    const logosReordenados = [];
    
    orden.forEach((imagenId, index) => {
      const imagen = logosActuales.find(img => img.id === imagenId);
      if (imagen) {
        imagen.orden = index + 1;
        logosReordenados.push(imagen);
      }
    });
    
    await info.update({ logo_images: logosReordenados });
    
    res.status(200).json({ 
      message: 'Logos reordenados correctamente',
      imagenes: logosReordenados
    });
  } catch (error) {
    console.error('Error al reordenar logos:', error);
    res.status(500).json({ error: 'Error al reordenar logos' });
  }
}; 
