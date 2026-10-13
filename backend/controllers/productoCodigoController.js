const db = require('../models');
const { ProductoCodigo, Producto, Sucursal, ProductoMaestro } = db;

exports.crearCodigo = async (req, res) => {
    try {
        const { id: producto_id } = req.params;
        const { codigo, tipo, es_principal } = req.body;

        if (!codigo || !tipo) {
            return res.status(400).json({
                success: false,
                message: 'Código y tipo son requeridos'
            });
        }

        const producto = await Producto.findByPk(producto_id);
        if (!producto) {
            return res.status(404).json({
                success: false,
                message: 'Producto no encontrado'
            });
        }

        const codigoExistente = await ProductoCodigo.findOne({
            where: { producto_id, codigo }
        });

        if (codigoExistente) {
            return res.status(400).json({
                success: false,
                message: 'Este código ya existe para este producto'
            });
        }

        if (es_principal) {
            await ProductoCodigo.update(
                { es_principal: false },
                { where: { producto_id } }
            );
        }

        const productoCodigo = await ProductoCodigo.create({
            producto_id,
            codigo,
            tipo,
            es_principal: es_principal || false
        });

        res.status(201).json({
            success: true,
            message: 'Código alternativo creado exitosamente',
            data: productoCodigo
        });
    } catch (error) {
        console.error('Error al crear código alternativo:', error);
        res.status(500).json({
            success: false,
            message: 'Error al crear código alternativo',
            error: error.message
        });
    }
};

exports.obtenerCodigosProducto = async (req, res) => {
    try {
        const { id: producto_id } = req.params;

        const codigos = await ProductoCodigo.findAll({
            where: { producto_id },
            order: [
                ['es_principal', 'DESC'],
                ['createdAt', 'ASC']
            ]
        });

        res.json({
            success: true,
            data: codigos
        });
    } catch (error) {
        console.error('Error al obtener códigos:', error);
        res.status(500).json({
            success: false,
            message: 'Error al obtener códigos del producto',
            error: error.message
        });
    }
};

exports.actualizarCodigo = async (req, res) => {
    try {
        const { id } = req.params;
        const { codigo, tipo, es_principal } = req.body;

        const productoCodigo = await ProductoCodigo.findByPk(id);

        if (!productoCodigo) {
            return res.status(404).json({
                success: false,
                message: 'Código no encontrado'
            });
        }

        if (es_principal) {
            await ProductoCodigo.update(
                { es_principal: false },
                { where: { producto_id: productoCodigo.producto_id } }
            );
        }

        await productoCodigo.update({
            codigo: codigo || productoCodigo.codigo,
            tipo: tipo || productoCodigo.tipo,
            es_principal: es_principal !== undefined ? es_principal : productoCodigo.es_principal
        });

        res.json({
            success: true,
            message: 'Código actualizado exitosamente',
            data: productoCodigo
        });
    } catch (error) {
        console.error('Error al actualizar código:', error);
        res.status(500).json({
            success: false,
            message: 'Error al actualizar código',
            error: error.message
        });
    }
};

exports.eliminarCodigo = async (req, res) => {
    try {
        const { id } = req.params;

        const productoCodigo = await ProductoCodigo.findByPk(id);

        if (!productoCodigo) {
            return res.status(404).json({
                success: false,
                message: 'Código no encontrado'
            });
        }

        await productoCodigo.destroy();

        res.json({
            success: true,
            message: 'Código eliminado exitosamente'
        });
    } catch (error) {
        console.error('Error al eliminar código:', error);
        res.status(500).json({
            success: false,
            message: 'Error al eliminar código',
            error: error.message
        });
    }
};

exports.buscarPorCodigo = async (req, res) => {
    try {
        const { codigo } = req.params;

        const productoCodigo = await ProductoCodigo.findOne({
            where: { codigo },
            include: [
                {
                    model: Producto,
                    as: 'producto',
                    include: [
                        {
                            model: Sucursal,
                            as: 'sucursal',
                            attributes: ['id', 'nombre']
                        },
                        {
                            model: ProductoMaestro,
                            as: 'productoMaestro',
                            attributes: ['id', 'nombre', 'imagen_compartida', 'descripcion_base']
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

        if (productoCodigo) {
            return res.json({
                success: true,
                data: productoCodigo.producto,
                encontradoPor: 'codigo_alternativo'
            });
        }

        const producto = await Producto.findOne({
            where: { codigo_barras: codigo },
            include: [
                {
                    model: Sucursal,
                    as: 'sucursal',
                    attributes: ['id', 'nombre']
                },
                {
                    model: ProductoMaestro,
                    as: 'productoMaestro',
                    attributes: ['id', 'nombre', 'imagen_compartida', 'descripcion_base']
                },
                {
                    model: ProductoCodigo,
                    as: 'codigos',
                    attributes: ['id', 'codigo', 'tipo', 'es_principal']
                }
            ]
        });

        if (producto) {
            return res.json({
                success: true,
                data: producto,
                encontradoPor: 'codigo_barras'
            });
        }

        res.status(404).json({
            success: false,
            message: 'No se encontró ningún producto con ese código'
        });
    } catch (error) {
        console.error('Error al buscar por código:', error);
        res.status(500).json({
            success: false,
            message: 'Error al buscar producto por código',
            error: error.message
        });
    }
};
