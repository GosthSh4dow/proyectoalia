const { DataTypes } = require('sequelize');

module.exports = {
    up: async (queryInterface, Sequelize) => {
        await queryInterface.createTable('producto_maestros', {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            nombre: {
                type: DataTypes.STRING,
                allowNull: false
            },
            descripcion_base: {
                type: DataTypes.TEXT,
                allowNull: true
            },
            imagen_compartida: {
                type: DataTypes.STRING,
                allowNull: true,
                defaultValue: null
            },
            proveedor_id: {
                type: DataTypes.INTEGER,
                allowNull: false,
                references: {
                    model: 'Proveedors',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'RESTRICT'
            },
            categoria_id: {
                type: DataTypes.INTEGER,
                allowNull: false,
                references: {
                    model: 'Categoria',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'RESTRICT'
            },
            activo: {
                type: DataTypes.BOOLEAN,
                allowNull: false,
                defaultValue: true
            },
            createdAt: {
                type: DataTypes.DATE,
                allowNull: false,
                defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
            },
            updatedAt: {
                type: DataTypes.DATE,
                allowNull: false,
                defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
            }
        });
    },

    down: async (queryInterface, Sequelize) => {
        await queryInterface.dropTable('producto_maestros');
    }
};
