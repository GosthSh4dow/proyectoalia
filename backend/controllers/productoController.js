const db = require('../models');
const Producto = db.Producto;
const ProductoImagen = db.ProductoImagen;
const path = require('path');
const fs = require('fs').promises;

const parseId = (value) => {
    if (value === '' || value === 'null' || value === undefined || value === null) {
        return null;
    }
    const parsed = parseInt(value, 10);
    if (isNaN(parsed)) {
        return null;
    }
    return parsed;
};

const parseDate = (value) => {
    if (!value || value === '' || value === 'null' || value === 'undefined' || value === 'Invalid date') {
        return null;
    }
    return value;
};

exports.crearProducto = async (req, res) => {
    const t = await db.sequelize.transaction();
    try {
        if (!req.files || !req.files.imagen) {
            await t.rollback();
            return res.status(400).json({ error: 'La imagen principal es requerida.' });
        }

        const { nombre, descripcion, costo, stock, codigo_barras, precio_venta } = req.body;
        const proveedor_id = parseId(req.body.proveedor_id);
        const categoria_id = parseId(req.body.categoria_id);
        const id_sucursal = parseId(req.body.id_sucursal);
        const fecha_caducidad = parseDate(req.body.fecha_caducidad);

        let { colores } = req.body;
        if (typeof colores === 'string') {
            try { colores = JSON.parse(colores); } catch (e) { colores = []; }
        }

        const productoExistente = await Producto.findOne({ where: { codigo_barras } });
        if (productoExistente) {
            await t.rollback();
            return res.status(400).json({ error: 'Ya existe un producto con este código de barras.' });
        }

        const imagen = req.files.imagen;
        const imagenNombre = `${Date.now()}_main${path.extname(imagen.name)}`;
        const imagenPath = path.join(__dirname, '..', 'uploads', imagenNombre);
        const imagenUrl = '/uploads/' + imagenNombre;

        await imagen.mv(imagenPath);

        const producto = await Producto.create({
            nombre,
            descripcion,
            costo,
            precio_venta,
            stock,
            proveedor_id,
            fecha_caducidad,
            codigo_barras,
            categoria_id,
            id_sucursal,
            imagen: imagenUrl,
            colores: colores || [],
        }, { transaction: t });

        await ProductoImagen.create({
            producto_id: producto.id,
            ruta_imagen: imagenUrl,
            es_principal: true,
            orden: 0
        }, { transaction: t });

        if (req.files.imagenes_adicionales) {
            const imagenesAdicionales = Array.isArray(req.files.imagenes_adicionales)
                ? req.files.imagenes_adicionales
                : [req.files.imagenes_adicionales];

            const promesas = imagenesAdicionales.map(async (img, i) => {
                const imgNombre = `${Date.now()}_add_${i}${path.extname(img.name)}`;
                const imgPath = path.join(__dirname, '..', 'uploads', imgNombre);
                await img.mv(imgPath);

                return ProductoImagen.create({
                    producto_id: producto.id,
                    ruta_imagen: '/uploads/' + imgNombre,
                    es_principal: false,
                    orden: i + 1
                }, { transaction: t });
            });
            await Promise.all(promesas);
        }

        await t.commit();
        res.status(201).json({ message: 'Producto creado correctamente', producto });

    } catch (error) {
        await t.rollback();
        console.error('Error al crear producto:', error);
        res.status(500).json({ error: 'Error al crear el producto: ' + error.message });
    }
};

exports.obtenerProductos = async (req, res) => {
    try {
        const { id_sucursal } = req.query;
        const whereCondition = {};
        if (id_sucursal) whereCondition.id_sucursal = id_sucursal;

        const productos = await Producto.findAll({
            where: whereCondition,
            attributes: [
                'id', 'nombre', 'descripcion', 'costo', 'precio_venta',
                'stock', 'fecha_caducidad', 'codigo_barras', 'imagen',
                'proveedor_id', 'categoria_id', 'id_sucursal', 'producto_maestro_id', 'colores'
            ],
            include: [
                { model: db.Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
                { model: db.Categoria, as: 'categoria', attributes: ['id', 'nombre'] },
                { model: db.Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] },
                {
                    model: db.ProductoImagen,
                    as: 'imagenes',
                    attributes: ['id', 'ruta_imagen', 'es_principal', 'orden']
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        res.json(productos);
    } catch (error) {
        console.error('Error al obtener productos:', error);
        res.status(500).json({ error: 'Error al obtener productos' });
    }
};

exports.obtenerProducto = async (req, res) => {
    try {
        const productoBase = await Producto.findByPk(req.params.id, {
            include: [
                { model: db.Proveedor, as: 'proveedor' },
                { model: db.Promocion, as: 'promociones' },
                { model: db.Categoria, as: 'categoria' },
                { model: db.Sucursal, as: 'sucursal' },
                {
                    model: db.ProductoImagen,
                    as: 'imagenes',
                    order: [['es_principal', 'DESC'], ['orden', 'ASC']]
                }
            ],
        });

        if (!productoBase) return res.status(404).json({ error: 'Producto no encontrado' });

        if (productoBase.imagenes?.length > 0) {
            const principal = productoBase.imagenes.find(img => img.es_principal);
            if (principal && productoBase.imagen !== principal.ruta_imagen) {
                productoBase.imagen = principal.ruta_imagen;
            }
        }

        let siblings = [];
        if (productoBase.codigo_barras) {
            siblings = await Producto.findAll({
                where: { codigo_barras: productoBase.codigo_barras },
                include: [
                    { model: db.Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] },
                    { model: db.ProductoVariante, as: 'variantes' }
                ]
            });
        }

        const sucursalesDisponibles = [];
        let coloresDisponibles = new Set();
        let totalStockGlobal = 0;

        for (const sibling of siblings) {
            if (sibling.stock > 0) {
                sucursalesDisponibles.push({
                    sucursal_id: sibling.id_sucursal,
                    sucursal_nombre: sibling.sucursal?.nombre || `Sucursal ${sibling.id_sucursal}`,
                    stock: sibling.stock,
                    producto_id: sibling.id
                });
            }
            totalStockGlobal += sibling.stock;

            let siblingColores = sibling.colores;
            if (typeof siblingColores === 'string') {
                try {
                    const cleanStr = siblingColores.replace(/'/g, '"');
                    siblingColores = JSON.parse(cleanStr);
                } catch (e) { }
            }
            if (siblingColores && Array.isArray(siblingColores)) {
                siblingColores.forEach(c => coloresDisponibles.add(c));
            }

            if (sibling.variantes && Array.isArray(sibling.variantes)) {
                sibling.variantes.forEach(v => {
                    if (v.cantidad > 0) coloresDisponibles.add(v.color);
                });
            }
        }

        const responseProducto = productoBase.toJSON();
        responseProducto.sucursalesDisponibles = sucursalesDisponibles;
        responseProducto.coloresAgrupados = Array.from(coloresDisponibles);
        responseProducto.stockGrupal = totalStockGlobal;

        res.status(200).json(responseProducto);
    } catch (error) {
        console.error('Error al obtener producto:', error);
        res.status(500).json({ error: 'Error al obtener el producto' });
    }
};

exports.obtenerProductoPorCodigoBarras = async (req, res) => {
    try {
        const producto = await Producto.findOne({
            where: { codigo_barras: req.params.codigo_barras },
            include: [
                { model: db.Proveedor, as: 'proveedor' },
                { model: db.Promocion, as: 'promociones' },
                { model: db.Categoria, as: 'categoria' }
            ],
        });

        if (!producto) return res.status(404).json({ error: 'Producto no encontrado' });
        res.status(200).json(producto);
    } catch (error) {
        console.error('Error búsqueda por código:', error);
        res.status(500).json({ error: 'Error al buscar producto' });
    }
};

exports.actualizarProducto = async (req, res) => {
    const t = await db.sequelize.transaction();
    try {
        const producto = await Producto.findByPk(req.params.id);
        if (!producto) {
            await t.rollback();
            return res.status(404).json({ error: 'Producto no encontrado' });
        }

        let { nombre, descripcion, costo, precio_venta, stock, codigo_barras, distribuciones } = req.body;
        const originalBarcode = producto.codigo_barras;

        if (typeof distribuciones === 'string') {
            try { distribuciones = JSON.parse(distribuciones); } catch (e) { distribuciones = []; }
        }

        let { colores } = req.body;
        if (typeof colores === 'string') {
            try { colores = JSON.parse(colores); } catch (e) { colores = []; }
        }

        const proveedor_id = parseId(req.body.proveedor_id);
        const categoria_id = parseId(req.body.categoria_id);
        const id_sucursal = parseId(req.body.id_sucursal);
        const fecha_caducidad = parseDate(req.body.fecha_caducidad);

        let imagenUrl = producto.imagen;

        if (req.files && req.files.imagen) {
            const imagen = req.files.imagen;
            const imagenNombre = `${Date.now()}_upd${path.extname(imagen.name)}`;
            const imagenPath = path.join(__dirname, '..', 'uploads', imagenNombre);

            await imagen.mv(imagenPath);
            imagenUrl = '/uploads/' + imagenNombre;

            await ProductoImagen.update(
                { es_principal: false },
                { where: { producto_id: producto.id, es_principal: true }, transaction: t }
            );

            await ProductoImagen.create({
                producto_id: producto.id,
                ruta_imagen: imagenUrl,
                es_principal: true,
                orden: 0
            }, { transaction: t });
        }

        if (req.files && req.files.imagenes_adicionales) {
            const imagenesAdicionales = Array.isArray(req.files.imagenes_adicionales)
                ? req.files.imagenes_adicionales : [req.files.imagenes_adicionales];

            const ultimaImagen = await ProductoImagen.findOne({
                where: { producto_id: producto.id },
                order: [['orden', 'DESC']],
                transaction: t
            });
            let ordenInicial = ultimaImagen ? ultimaImagen.orden + 1 : 1;

            const promesas = imagenesAdicionales.map(async (img, i) => {
                const imgNombre = `${Date.now()}_add_${i}${path.extname(img.name)}`;
                const imgPath = path.join(__dirname, '..', 'uploads', imgNombre);
                await img.mv(imgPath);

                return ProductoImagen.create({
                    producto_id: producto.id,
                    ruta_imagen: '/uploads/' + imgNombre,
                    es_principal: false,
                    orden: ordenInicial + i
                }, { transaction: t });
            });
            await Promise.all(promesas);
        }

        let { imagenes_eliminar } = req.body;
        if (typeof imagenes_eliminar === 'string') {
            try { imagenes_eliminar = JSON.parse(imagenes_eliminar); } catch (e) { imagenes_eliminar = []; }
        }

        if (imagenes_eliminar && Array.isArray(imagenes_eliminar) && imagenes_eliminar.length > 0) {
            const imagesToDelete = await ProductoImagen.findAll({
                where: {
                    producto_id: producto.id,
                    ruta_imagen: { [db.Sequelize.Op.in]: imagenes_eliminar }
                },
                transaction: t
            });

            for (const img of imagesToDelete) {
                try {
                    const filePath = path.join(__dirname, '..', img.ruta_imagen);
                    await fs.unlink(filePath);
                } catch (err) {
                    if (err.code !== 'ENOENT') console.error("Error deleting file:", err);
                }
                await img.destroy({ transaction: t });
            }

            if (imagenes_eliminar.includes(producto.imagen)) {
                if (!(req.files && req.files.imagen)) {
                    const nextImage = await ProductoImagen.findOne({
                        where: { producto_id: producto.id },
                        order: [['orden', 'ASC']],
                        transaction: t
                    });

                    if (nextImage) {
                        imagenUrl = nextImage.ruta_imagen;
                        await nextImage.update({ es_principal: true }, { transaction: t });
                    } else {
                        imagenUrl = null;
                    }
                }
            }
        }

        await Producto.update({
            nombre, descripcion, costo, precio_venta, proveedor_id,
            fecha_caducidad, categoria_id, imagen: imagenUrl,
            codigo_barras: codigo_barras,
            colores: colores
        }, {
            where: { codigo_barras: originalBarcode },
            transaction: t
        });

        if (distribuciones && Array.isArray(distribuciones) && distribuciones.length > 0) {
            const promises = distribuciones.map(async (dist) => {
                const targetSucursal = dist.id_sucursal;
                const targetStock = dist.cantidad;
                const targetBarcode = codigo_barras || originalBarcode;

                const existingProd = await Producto.findOne({
                    where: { codigo_barras: targetBarcode, id_sucursal: targetSucursal },
                    transaction: t
                });

                if (existingProd) {
                    return existingProd.update({ stock: targetStock }, { transaction: t });
                } else {
                    return Producto.create({
                        nombre, descripcion, costo, precio_venta, stock: targetStock,
                        proveedor_id, fecha_caducidad, categoria_id,
                        id_sucursal: targetSucursal,
                        codigo_barras: targetBarcode,
                        imagen: imagenUrl
                    }, { transaction: t });
                }
            });
            await Promise.all(promises);
        } else {
            await producto.update({ stock }, { transaction: t });
        }

        await t.commit();
        res.status(200).json({ message: 'Producto actualizado correctamente', producto });

    } catch (error) {
        await t.rollback();
        console.error('Error al actualizar:', error);
        res.status(500).json({ error: 'Error al actualizar el producto ' + error.message });
    }
};

exports.eliminarProducto = async (req, res) => {
    const t = await db.sequelize.transaction();
    try {
        const { id } = req.params;
        const producto = await Producto.findByPk(id);
        if (!producto) {
            await t.rollback();
            return res.status(404).json({ error: 'Producto no encontrado' });
        }

        const imagenesAsociadas = await ProductoImagen.findAll({
            where: { producto_id: id }
        });

        await ProductoImagen.destroy({
            where: { producto_id: id },
            transaction: t
        });

        await producto.destroy({ transaction: t });
        await t.commit();

        const promesasBorrado = imagenesAsociadas.map(async (img) => {
            const filePath = path.join(__dirname, '..', img.ruta_imagen);
            try {
                await fs.unlink(filePath);
            } catch (err) {}
        });

        await Promise.allSettled(promesasBorrado);
        res.status(200).json({ message: 'Producto eliminado correctamente' });

    } catch (error) {
        await t.rollback();
        console.error('Error al eliminar producto:', error);
        if (error.name === 'SequelizeForeignKeyConstraintError') {
            return res.status(409).json({ error: 'No se puede eliminar: tiene ventas o registros asociados.' });
        }
        res.status(500).json({ error: 'Error al eliminar el producto' });
    }
};

exports.exportarParaSync = async (req, res) => {
    try {
        const productos = await Producto.findAll({
            attributes: ['id', 'nombre', 'codigo_barras', 'id_sucursal', 'imagen', 'descripcion', 'stock', 'precio_venta', 'costo'],
            include: [
                { model: db.Categoria, as: 'categoria', attributes: ['id', 'nombre'] },
                { model: db.Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] },
                { model: db.Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
                { model: db.ProductoImagen, as: 'imagenes', attributes: ['ruta_imagen', 'es_principal'] }
            ]
        });

        const protocol = req.protocol || 'http';
        const host = req.get('host');
        const baseUrl = `${protocol}://${host}`;

        const productosConUrls = productos.map(p => {
            const producto = p.toJSON();
            if (producto.imagen && !producto.imagen.startsWith('http')) {
                producto.imagen_url = `${baseUrl}/api${producto.imagen}`;
            } else {
                producto.imagen_url = producto.imagen;
            }
            return producto;
        });

        res.status(200).json(productosConUrls);
    } catch (error) {
        console.error('Error exportarParaSync:', error);
        res.status(500).json({ error: 'Error al exportar catálogo' });
    }
};

exports.crearProductoConDistribucion = async (req, res) => {
    const t = await db.sequelize.transaction();
    try {
        const { nombre, descripcion, costo, precio_venta } = req.body;
        let { distribuciones, crear_maestro } = req.body;

        if (typeof distribuciones === 'string') {
            try {
                distribuciones = JSON.parse(distribuciones);
            } catch (e) {
                distribuciones = [];
            }
        }

        if (typeof crear_maestro === 'string') {
            crear_maestro = crear_maestro === 'true';
        }

        if (!nombre || !distribuciones || !Array.isArray(distribuciones) || distribuciones.length === 0) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                error: 'Nombre y distribuciones son requeridos'
            });
        }

        const proveedor_id = parseId(req.body.proveedor_id);
        const categoria_id = parseId(req.body.categoria_id);

        let producto_maestro_id = null;
        let imagen_compartida = null;

        if (crear_maestro) {
            if (req.files && req.files.imagen) {
                const imagen = req.files.imagen;
                const imagenNombre = `${Date.now()}_master${path.extname(imagen.name)}`;
                const imagenPath = path.join(__dirname, '..', 'uploads', imagenNombre);
                imagen_compartida = '/uploads/' + imagenNombre;
                await imagen.mv(imagenPath);
            }

            const productoMaestro = await db.ProductoMaestro.create({
                nombre,
                descripcion_base: descripcion || null,
                proveedor_id,
                categoria_id,
                imagen_compartida,
                activo: true
            }, { transaction: t });

            producto_maestro_id = productoMaestro.id;
        }

        const promisesCreacion = distribuciones.map(async (dist) => {
            const { id_sucursal, cantidad, codigo_barras, codigos_alternativos } = dist;

            if (!id_sucursal || cantidad === undefined || !codigo_barras) {
                throw new Error('Datos de distribución incompletos');
            }

            const producto = await Producto.create({
                nombre,
                descripcion,
                costo,
                precio_venta,
                stock: cantidad,
                proveedor_id,
                codigo_barras,
                categoria_id,
                id_sucursal: parseId(id_sucursal),
                producto_maestro_id,
                imagen: imagen_compartida,
                fecha_caducidad: parseDate(req.body.fecha_caducidad)
            }, { transaction: t });

            const auxPromises = [];

            if (imagen_compartida) {
                auxPromises.push(ProductoImagen.create({
                    producto_id: producto.id,
                    ruta_imagen: imagen_compartida,
                    es_principal: true,
                    orden: 0
                }, { transaction: t }));
            }

            auxPromises.push(db.ProductoCodigo.create({
                producto_id: producto.id,
                codigo: codigo_barras,
                tipo: 'barras',
                es_principal: true
            }, { transaction: t }));

            if (codigos_alternativos && Array.isArray(codigos_alternativos)) {
                for (const codigoAlt of codigos_alternativos) {
                    if (codigoAlt.codigo) {
                        auxPromises.push(db.ProductoCodigo.create({
                            producto_id: producto.id,
                            codigo: codigoAlt.codigo,
                            tipo: codigoAlt.tipo || 'otro',
                            es_principal: false
                        }, { transaction: t }));
                    }
                }
            }

            if (dist.variantes && Array.isArray(dist.variantes)) {
                for (const variante of dist.variantes) {
                    if (variante.color && variante.cantidad !== undefined) {
                        auxPromises.push(db.ProductoVariante.create({
                            producto_id: producto.id,
                            color: variante.color,
                            cantidad: variante.cantidad,
                            imagen_url: variante.imagen_url || null
                        }, { transaction: t }));
                    }
                }
            }

            await Promise.all(auxPromises);
            return producto;
        });

        const productosCreados = await Promise.all(promisesCreacion);
        await t.commit();

        res.status(201).json({
            success: true,
            message: 'Productos distribuidos correctamente',
            data: {
                producto_maestro_id,
                productos: productosCreados
            }
        });

    } catch (error) {
        await t.rollback();
        console.error('Error al crear producto con distribución:', error);
        res.status(500).json({
            success: false,
            error: 'Error al crear el producto con distribución: ' + error.message
        });
    }
};

exports.obtenerTodos = exports.obtenerProductos;
exports.buscarPorCodigo = exports.obtenerProductoPorCodigoBarras;
exports.detalle = exports.obtenerProducto;
