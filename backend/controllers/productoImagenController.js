const db = require('../models');
const ProductoImagen = db.ProductoImagen;
const Producto = db.Producto;
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

exports.agregarImagenes = async (req, res) => {
  try {
    const { id } = req.params;
    const producto = await Producto.findByPk(id);
    if (!producto) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    if (!req.files || !req.files.imagenes) {
      return res.status(400).json({ error: 'No se han enviado imágenes' });
    }

    const imagenes = Array.isArray(req.files.imagenes) ? req.files.imagenes : [req.files.imagenes];

    const imagenesExistentes = await ProductoImagen.findAll({
      where: { producto_id: id }
    });

    const rutasExistentes = new Set(imagenesExistentes.map(img => img.ruta_imagen));

    const imagenesNuevas = [];
    const imagenesVistas = new Set();

    for (const img of imagenes) {
      const key = `${img.name}_${img.size}_${img.lastModified}`;
      if (imagenesVistas.has(key)) {
        continue;
      }
      imagenesVistas.add(key);
      imagenesNuevas.push(img);
    }

    if (imagenesNuevas.length === 0) {
      return res.status(400).json({ error: 'No hay imágenes nuevas para procesar' });
    }

    const imagenesGuardadas = [];

    const ultimaImagen = await ProductoImagen.findOne({
      where: { producto_id: id },
      order: [['orden', 'DESC']]
    });

    let ordenInicial = ultimaImagen ? ultimaImagen.orden + 1 : 1;

    for (let i = 0; i < imagenesNuevas.length; i++) {
      try {
        const rutaImagen = await procesarImagen(imagenesNuevas[i]);
        if (rutasExistentes.has(rutaImagen)) {
          continue;
        }
        const nuevaImagen = await ProductoImagen.create({
          producto_id: id,
          ruta_imagen: rutaImagen,
          es_principal: false,
          orden: ordenInicial + i
        });
        imagenesGuardadas.push(nuevaImagen);
        rutasExistentes.add(rutaImagen);
      } catch (error) {
        console.error(`Error al procesar imagen ${i}:`, error);
      }
    }

    res.status(200).json({
      message: `${imagenesGuardadas.length} imágenes agregadas con éxito`,
      imagenes: imagenesGuardadas
    });
  } catch (error) {
    console.error('Error al agregar imágenes:', error);
    res.status(500).json({ error: 'Error al procesar las imágenes' });
  }
};

exports.obtenerImagenes = async (req, res) => {
  try {
    const { id } = req.params;
    const imagenes = await ProductoImagen.findAll({
      where: { producto_id: id },
      order: [['es_principal', 'DESC'], ['orden', 'ASC']]
    });
    if (imagenes.length === 0) {
      const producto = await Producto.findByPk(id);
      if (producto && producto.imagen) {
        const imagenPrincipal = await ProductoImagen.create({
          producto_id: id,
          ruta_imagen: producto.imagen,
          es_principal: true,
          orden: 0
        });
        return res.status(200).json([imagenPrincipal]);
      }
    }
    res.status(200).json(imagenes);
  } catch (error) {
    console.error('Error al obtener imágenes:', error);
    res.status(500).json({ error: 'Error al obtener las imágenes' });
  }
};

exports.establecerImagenPrincipal = async (req, res) => {
  try {
    const { id, imagen_id } = req.params;
    const producto = await Producto.findByPk(id);
    if (!producto) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    const imagen = await ProductoImagen.findOne({
      where: {
        id: imagen_id,
        producto_id: id
      }
    });
    if (!imagen) {
      return res.status(404).json({ error: 'Imagen no encontrada' });
    }
    await ProductoImagen.update(
      { es_principal: false },
      { where: { producto_id: id } }
    );
    await imagen.update({ es_principal: true });
    await producto.update({ imagen: imagen.ruta_imagen });
    res.status(200).json({
      message: 'Imagen principal establecida correctamente',
      imagen
    });
  } catch (error) {
    console.error('Error al establecer imagen principal:', error);
    res.status(500).json({ error: 'Error al actualizar la imagen principal' });
  }
};

exports.eliminarImagen = async (req, res) => {
  try {
    const { id, imagen_id } = req.params;
    const imagen = await ProductoImagen.findOne({
      where: {
        id: imagen_id,
        producto_id: id
      }
    });
    if (!imagen) {
      return res.status(404).json({ error: 'Imagen no encontrada' });
    }
    if (imagen.es_principal) {
      return res.status(400).json({ error: 'No se puede eliminar la imagen principal. Establece otra imagen como principal primero.' });
    }
    try {
      const rutaCompleta = path.join(__dirname, '..', imagen.ruta_imagen);
      if (fs.existsSync(rutaCompleta)) {
        fs.unlinkSync(rutaCompleta);
      }
    } catch (fileError) {
      console.error('Error al eliminar archivo físico:', fileError);
    }
    await imagen.destroy();
    res.status(200).json({
      message: 'Imagen eliminada correctamente'
    });
  } catch (error) {
    console.error('Error al eliminar imagen:', error);
    res.status(500).json({ error: 'Error al eliminar la imagen' });
  }
};

exports.reordenarImagenes = async (req, res) => {
  try {
    const { id } = req.params;
    const { orden } = req.body;
    if (!orden || !Array.isArray(orden)) {
      return res.status(400).json({ error: 'Se requiere un array de orden válido' });
    }
    for (const item of orden) {
      await ProductoImagen.update(
        { orden: item.orden },
        { where: { id: item.id_imagen, producto_id: id } }
      );
    }
    const imagenesActualizadas = await ProductoImagen.findAll({
      where: { producto_id: id },
      order: [['es_principal', 'DESC'], ['orden', 'ASC']]
    });
    res.status(200).json({
      message: 'Orden actualizado correctamente',
      imagenes: imagenesActualizadas
    });
  } catch (error) {
    console.error('Error al reordenar imágenes:', error);
    res.status(500).json({ error: 'Error al actualizar el orden de las imágenes' });
  }
};
