const db = require('../models');
const { ProductoMaestro, Producto, Proveedor, Categoria, ProductoCodigo } = db;

exports.crearProductoMaestro = async (req, res) => {
    try {
        const { nombre, descripcion_base, proveedor_id, categoria_id, imagen_compartida } = req.body;

        if (!nombre || !proveedor_id || !categoria_id) {
            return res.status(400).json({
                success: false,
                message: 'Nombre, proveedor_id y categoria_id son requeridos'
            });
        }

        const productoMaestro = await ProductoMaestro.create({
            nombre,
            descripcion_base,
            proveedor_id,
            categoria_id,
            imagen_compartida: imagen_compartida || null,
            activo: true
        });

        res.status(201).json({
            success: true,
            message: 'Producto maestro creado exitosamente',
            data: productoMaestro
        });
    } catch (error) {
        console.error('Error al crear producto maestro:', error);
        res.status(500).json({
            success: false,
            message: 'Error al crear producto maestro',
            error: error.message
        });
    }
};

exports.obtenerProductosMaestros = async (req, res) => {
    try {
        const { activo, categoria_id, proveedor_id } = req.query;

        const whereCondition = {};
        if (activo !== undefined) whereCondition.activo = activo === 'true';
        if (categoria_id) whereCondition.categoria_id = categoria_id;
        if (proveedor_id) whereCondition.proveedor_id = proveedor_id;

        const productosMaestros = await ProductoMaestro.findAll({
            where: whereCondition,
            include: [
                {
                    model: Proveedor,
                    as: 'proveedor',
                    attributes: ['id', 'nombre']
                },
                {
                    model: Categoria,
                    as: 'categoria',
                    attributes: ['id', 'nombre']
                },
                {
                    model: Producto,
                    as: 'instancias',
                    attributes: ['id', 'stock', 'id_sucursal', 'codigo_barras'],
                    include: [
                        {
                            model: db.Sucursal,
                            as: 'sucursal',
                            attributes: ['id', 'nombre']
                        }
                    ]
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        res.json({
            success: true,
            data: productosMaestros
        });
    } catch (error) {
        console.error('Error al obtener productos maestros:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener productos maestros',
            error: error.message
        });
    }
};

exports.obtenerProductoMaestro = async (req, res) => {
    try {
        const { id } = req.params;

        const productoMaestro = await ProductoMaestro.findByPk(id, {
            include: [
                {
                    model: Proveedor,
                    as: 'proveedor',
                    attributes: ['id', 'nombre']
                },
                {
                    model: Categoria,
                    as: 'categoria',
                    attributes: ['id', 'nombre']
                },
                {
                    model: Producto,
                    as: 'instancias',
                    include: [
                        {
                            model: db.Sucursal,
                            as: 'sucursal',
                            attributes: ['id', 'nombre']
                        },
                        {
                            model: ProductoCodigo,
                            as: 'codigos',
                            attributes: ['id', 'codigo', 'tipo', 'es_principal']
                        }
                    ]
                }
            ]
        });

        if (!productoMaestro) {
            return res.status(404).json({
                success: false,
                message: 'Producto maestro no encontrado'
            });
        }

        res.json({
            success: true,
            data: productoMaestro
        });
    } catch (error) {
        console.error('Error al obtener producto maestro:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener producto maestro',
            error: error.message
        });
    }
};

exports.actualizarProductoMaestro = async (req, res) => {
    try {
        const { id } = req.params;
        const { nombre, descripcion_base, proveedor_id, categoria_id, imagen_compartida, activo } = req.body;

        const productoMaestro = await ProductoMaestro.findByPk(id);

        if (!productoMaestro) {
            return res.status(404).json({
                success: false,
                message: 'Producto maestro no encontrado'
            });
        }

        await productoMaestro.update({
            nombre: nombre || productoMaestro.nombre,
            descripcion_base: descripcion_base !== undefined ? descripcion_base : productoMaestro.descripcion_base,
            proveedor_id: proveedor_id || productoMaestro.proveedor_id,
            categoria_id: categoria_id || productoMaestro.categoria_id,
            imagen_compartida: imagen_compartida !== undefined ? imagen_compartida : productoMaestro.imagen_compartida,
            activo: activo !== undefined ? activo : productoMaestro.activo
        });

        res.json({
            success: true,
            message: 'Producto maestro actualizado exitosamente',
            data: productoMaestro
        });
    } catch (error) {
        console.error('Error al actualizar producto maestro:', error);
        res.status(500).json({
            success: false,
            message: 'Error al actualizar producto maestro',
            error: error.message
        });
    }
};

exports.eliminarProductoMaestro = async (req, res) => {
    try {
        const { id } = req.params;

        const productoMaestro = await ProductoMaestro.findByPk(id);

        if (!productoMaestro) {
            return res.status(404).json({
                success: false,
                message: 'Producto maestro no encontrado'
            });
        }

        await productoMaestro.update({ activo: false });

        res.json({
            success: true,
            message: 'Producto maestro desactivado exitosamente'
        });
    } catch (error) {
        console.error('Error al eliminar producto maestro:', error);
        res.status(500).json({
            success: false,
            message: 'Error al eliminar producto maestro',
            error: error.message
        });
    }
};

exports.obtenerInstanciasProductoMaestro = async (req, res) => {
    try {
        const { id } = req.params;

        const productos = await Producto.findAll({
            where: { producto_maestro_id: id },
            include: [
                {
                    model: db.Sucursal,
                    as: 'sucursal',
                    attributes: ['id', 'nombre']
                },
                {
                    model: ProductoCodigo,
                    as: 'codigos',
                    attributes: ['id', 'codigo', 'tipo', 'es_principal']
                },
                {
                    model: ProductoMaestro,
                    as: 'productoMaestro',
                    attributes: ['id', 'nombre', 'imagen_compartida']
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        res.json({
            success: true,
            data: productos
        });
    } catch (error) {
        console.error('Error al obtener instancias:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener instancias del producto maestro',
            error: error.message
        });
    }
};
