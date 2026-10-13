const { DataTypes } = require('sequelize');

module.exports = {
    up: async (queryInterface, Sequelize) => {
        await queryInterface.addColumn('Productos', 'producto_maestro_id', {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: {
                model: 'producto_maestros',
                key: 'id'
            },
            onUpdate: 'CASCADE',
            onDelete: 'SET NULL'
        });

        await queryInterface.addIndex('Productos', ['producto_maestro_id'], {
            name: 'idx_producto_maestro_id'
        });
    },

    down: async (queryInterface, Sequelize) => {
        await queryInterface.removeIndex('Productos', 'idx_producto_maestro_id');
        await queryInterface.removeColumn('Productos', 'producto_maestro_id');
    }
};
