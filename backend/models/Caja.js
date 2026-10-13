module.exports = (sequelize, DataTypes) => {
    const Caja = sequelize.define('Caja', {
        id_sucursal: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'sucursales',
                key: 'id',
            },
        },
        fecha: {
            type: DataTypes.DATEONLY,
            allowNull: false,
        },
        saldo_inicial: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00,
        },
        monto_inicial: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00,
        },
        ingresos: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00,
        },
        egresos: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00,
        },
        saldo_final: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00,
        },
        estado: {
            type: DataTypes.ENUM('abierta', 'cerrada'),
            allowNull: false,
            defaultValue: 'abierta',
        },
        cerrado_por: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: {
                model: 'usuarios',
                key: 'id',
            },
        },
        abierto_por: {
            type: DataTypes.INTEGER,
            allowNull: true,
            references: {
                model: 'usuarios',
                key: 'id',
            },
        },
        fecha_cierre: {
            type: DataTypes.DATE,
            allowNull: true,
        },
        justificacion: {
            type: DataTypes.TEXT,
            allowNull: true,
        },
    }, {
        tableName: 'cajas',
        freezeTableName: true,
        timestamps: true,
        underscored: false

    });

    Caja.associate = (models) => {
    };

    return Caja;
};
