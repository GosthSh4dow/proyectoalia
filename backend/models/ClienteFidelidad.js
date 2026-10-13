module.exports = (sequelize, DataTypes) => {
    const ClienteFidelidad = sequelize.define('ClienteFidelidad', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        cliente_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'clientes',
                key: 'id_cliente'
            }
        },
        total_compras: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        monto_total_gastado: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        nivel: {
            type: DataTypes.ENUM('nuevo', 'frecuente', 'vip'),
            allowNull: false,
            defaultValue: 'nuevo'
        },
        primera_compra: {
            type: DataTypes.DATE,
            allowNull: true
        },
        ultima_compra: {
            type: DataTypes.DATE,
            allowNull: true
        }
    }, {
        tableName: 'cliente_fidelidad',
        timestamps: true
    });

    return ClienteFidelidad;
};
