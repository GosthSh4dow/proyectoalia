const db = require('../models');
const Promocion = db.Promocion;
const Producto = db.Producto;

exports.obtenerPromociones = async (req, res) => {
  try {
    const promociones = await Promocion.findAll({ include: ['productos'] });
    res.status(200).json(promociones);
  } catch (error) {
    console.error('Error al obtener promociones:', error);
    res.status(500).json({ error: 'Error al obtener promociones' });
  }
};

exports.obtenerPromocion = async (req, res) => {
  try {
    const promocion = await Promocion.findByPk(req.params.id, { include: ['productos'] });
    if (!promocion) {
      return res.status(404).json({ error: 'Promoción no encontrada' });
    }
    res.status(200).json(promocion);
  } catch (error) {
    console.error('Error al obtener la promoción:', error);
    res.status(500).json({ error: 'Error al obtener la promoción' });
  }
};

exports.crearPromocion = async (req, res) => {
  try {
    const { tipo, descripcion, valor, fecha_inicio, fecha_fin, id_productos } = req.body;

    if (!tipo || !descripcion || valor === undefined || !fecha_inicio || !fecha_fin) {
      return res.status(400).json({ error: 'Campos obligatorios faltantes.' });
    }

    if (tipo === '2x1' && valor !== 0) {
      return res.status(400).json({ error: 'El valor para el tipo 2x1 debe ser 0.' });
    }

    if (id_productos && Array.isArray(id_productos) && id_productos.length > 0) {
      const productosExistentes = await Producto.findAll({
        where: { id: id_productos },
      });

      if (productosExistentes.length !== id_productos.length) {
        return res.status(400).json({ error: 'Algunos productos no existen.' });
      }
    } else {
      return res.status(400).json({ error: 'Debe asociar al menos un producto.' });
    }

    const promocion = await Promocion.create({
      tipo,
      descripcion,
      valor,
      fecha_inicio,
      fecha_fin,
    });

    await promocion.setProductos(id_productos);

    res.status(201).json(promocion);
  } catch (error) {
    console.error('Error al crear promoción:', error);
    res.status(500).json({ error: 'Error al crear la promoción. Verifique los datos enviados.' });
  }
};

exports.actualizarPromocion = async (req, res) => {
  try {
    const promocion = await Promocion.findByPk(req.params.id);
    if (!promocion) {
      return res.status(404).json({ error: 'Promoción no encontrada' });
    }

    const { tipo, descripcion, valor, fecha_inicio, fecha_fin, id_productos } = req.body;

    if (!tipo || !descripcion || valor === undefined || !fecha_inicio || !fecha_fin) {
      return res.status(400).json({ error: 'Todos los campos obligatorios deben estar llenos.' });
    }

    if (tipo === '2x1' && valor !== 0) {
      return res.status(400).json({ error: 'El valor para el tipo 2x1 debe ser 0.' });
    }

    await promocion.update({
      tipo,
      descripcion,
      valor,
      fecha_inicio,
      fecha_fin,
    });

    if (id_productos && Array.isArray(id_productos) && id_productos.length > 0) {
      await promocion.setProductos(id_productos);
    }

    res.status(200).json(promocion);
  } catch (error) {
    console.error('Error al actualizar promoción:', error);
    res.status(500).json({ error: 'Error al actualizar la promoción' });
  }
};

exports.eliminarPromocion = async (req, res) => {
  try {
    const promocion = await Promocion.findByPk(req.params.id);
    if (!promocion) {
      return res.status(404).json({ error: 'Promoción no encontrada' });
    }

    await promocion.destroy();
    res.status(200).json({ message: 'Promoción eliminada correctamente' });
  } catch (error) {
    console.error('Error al eliminar promoción:', error);
    res.status(500).json({ error: 'Error al eliminar la promoción' });
  }
};

exports.actualizarPromocionesExpiradas = async (req, res) => {
  try {
    const now = new Date();

    const promocionesExpiradas = await Promocion.findAll({
      where: {
        fecha_fin: {
          [db.Sequelize.Op.lt]: now,
        },
      },
      include: ['productos'],
    });

    for (const promocion of promocionesExpiradas) {
      await promocion.setProductos([]);
    }

    res.status(200).json({ message: 'Promociones expiradas actualizadas correctamente' });
  } catch (error) {
    console.error('Error al actualizar promociones expiradas:', error);
    res.status(500).json({ error: 'Error al actualizar promociones expiradas' });
  }
};

exports.eliminarProductoDePromocion = async (req, res) => {
  try {
    const { id, id_producto } = req.params;

    const promocion = await Promocion.findByPk(id);
    if (!promocion) {
      return res.status(404).json({ error: 'Promoción no encontrada' });
    }

    const resultado = await promocion.removeProducto(id_producto);

    if (!resultado) {
      return res.status(400).json({ error: 'No se pudo eliminar el producto de la promoción' });
    }

    res.status(200).json({ message: 'Producto eliminado de la promoción' });
  } catch (error) {
    console.error('Error al eliminar producto de la promoción:', error);
    res.status(500).json({ error: 'Error al eliminar producto de la promoción' });
  }
};
