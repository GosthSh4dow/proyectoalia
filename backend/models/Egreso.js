module.exports = (sequelize, DataTypes) => {
    const Egreso = sequelize.define('Egreso', {
        monto: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
        },
        justificacion: {
            type: DataTypes.STRING,
            allowNull: true,
        },
        fecha: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW,
        },
        id_caja: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'cajas',
                key: 'id',
            },
        },
        id_usuario: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'usuarios',
                key: 'id',
            },
        },
    }, {
        tableName: 'egresos',
        timestamps: true,
    });

    Egreso.associate = (models) => {
        Egreso.belongsTo(models.Caja, {
            foreignKey: 'id_caja',
            as: 'caja',
        });
        Egreso.belongsTo(models.Usuario, {
            foreignKey: 'id_usuario',
            as: 'usuario',
        });
    };

    return Egreso;
};
