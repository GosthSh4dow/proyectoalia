const { DataTypes } = require('sequelize');

module.exports = {
    up: async (queryInterface, Sequelize) => {
        await queryInterface.createTable('producto_codigos', {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            producto_id: {
                type: DataTypes.INTEGER,
                allowNull: false,
                references: {
                    model: 'Productos',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            codigo: {
                type: DataTypes.STRING,
                allowNull: false
            },
            tipo: {
                type: DataTypes.ENUM('barras', 'sku', 'interno', 'otro'),
                allowNull: false,
                defaultValue: 'barras'
            },
            es_principal: {
                type: DataTypes.BOOLEAN,
                allowNull: false,
                defaultValue: false
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

        await queryInterface.addIndex('producto_codigos', ['producto_id', 'codigo'], {
            unique: true,
            name: 'unique_producto_codigo'
        });

        await queryInterface.addIndex('producto_codigos', ['codigo'], {
            name: 'idx_codigo'
        });
    },

    down: async (queryInterface, Sequelize) => {
        await queryInterface.dropTable('producto_codigos');
    }
};
