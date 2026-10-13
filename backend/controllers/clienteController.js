const db = require('../models');
const Cliente = db.Cliente;

exports.obtenerClientes = async (req, res) => {
    try {
        const { ci } = req.query;
        let clientes;
        if (ci) {
            clientes = await Cliente.findOne({ where: { ci } });
            if (!clientes) {
                return res.status(404).json({ error: 'Cliente no encontrado' });
            }
        } else {
            clientes = await Cliente.findAll();
        }
        res.status(200).json(clientes);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener los clientes' });
    }
};

exports.obtenerCliente = async (req, res) => {
    try {
        const cliente = await Cliente.findByPk(req.params.id, {
            include: [{
                model: db.ClienteFidelidad,
                as: 'fidelidad',
                required: false
            }]
        });
        if (!cliente) {
            return res.status(404).json({ error: 'Cliente no encontrado' });
        }
        res.status(200).json(cliente);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener el cliente' });
    }
};

exports.crearCliente = async (req, res) => {
    try {
        const { nombre_completo, ci } = req.body;

        if (!nombre_completo || !ci) {
            return res.status(400).json({ error: 'Nombre completo y CI son obligatorios.' });
        }

        const existingCliente = await Cliente.findOne({ where: { ci } });
        if (existingCliente) {
            return res.status(400).json({ error: 'El CI ya está registrado.', cliente: existingCliente });
        }

        const cliente = await Cliente.create({
            nombre_completo,
            ci,
        });

        res.status(201).json(cliente);
    } catch (error) {
        console.error('Error al crear cliente:', error);
        res.status(500).json({ error: 'Error al crear el cliente.' });
    }
};

exports.actualizarCliente = async (req, res) => {
    try {
        const cliente = await Cliente.findByPk(req.params.id);
        if (!cliente) {
            return res.status(404).json({ error: 'Cliente no encontrado' });
        }

        const { nombre_completo, ci } = req.body;
        await cliente.update({ nombre_completo, ci });
        res.status(200).json(cliente);
    } catch (error) {
        res.status(500).json({ error: 'Error al actualizar el cliente' });
    }
};

exports.eliminarCliente = async (req, res) => {
    try {
        const cliente = await Cliente.findByPk(req.params.id);
        if (!cliente) {
            return res.status(404).json({ error: 'Cliente no encontrado' });
        }

        await cliente.destroy();
        res.status(200).json({ message: 'Cliente eliminado correctamente' });
    } catch (error) {
        res.status(500).json({ error: 'Error al eliminar el cliente' });
    }
};
