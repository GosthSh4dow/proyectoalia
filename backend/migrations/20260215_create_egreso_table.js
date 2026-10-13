'use strict';

module.exports = {
    up: async (queryInterface, Sequelize) => {
        await queryInterface.createTable('Egresos', {
            id: {
                allowNull: false,
                autoIncrement: true,
                primaryKey: true,
                type: Sequelize.INTEGER
            },
            monto: {
                type: Sequelize.DECIMAL(10, 2),
                allowNull: false
            },
            justificacion: {
                type: Sequelize.STRING,
                allowNull: true
            },
            fecha: {
                type: Sequelize.DATE,
                defaultValue: Sequelize.NOW
            },
            id_caja: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'Cajas',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            id_usuario: {
                type: Sequelize.INTEGER,
                allowNull: false,
                references: {
                    model: 'Usuarios',
                    key: 'id'
                },
                onUpdate: 'CASCADE',
                onDelete: 'CASCADE'
            },
            createdAt: {
                allowNull: false,
                type: Sequelize.DATE
            },
            updatedAt: {
                allowNull: false,
                type: Sequelize.DATE
            }
        });
    },

    down: async (queryInterface, Sequelize) => {
        await queryInterface.dropTable('Egresos');
    }
};
