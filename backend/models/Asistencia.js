module.exports = (sequelize, DataTypes) => {
    const asistencia = sequelize.define('asistencia', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
        },
        id_usuario: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'usuarios',
                key: 'id',
            },
        },
        fecha: {
            type: DataTypes.DATEONLY,
            allowNull: false,
        },
        ingreso: {
            type: DataTypes.TIME,
            allowNull: false,
        },
        salida: {
            type: DataTypes.TIME,
            allowNull: true,
        },
        estado: {
            type: DataTypes.ENUM('Asistido', 'Falta', 'Reemplazo'),
            allowNull: true,
        },
        justificado: {
            type: DataTypes.BOOLEAN,
            allowNull: true,
        },
        reemplazo_id: {
            type: DataTypes.INTEGER,
            references: {
                model: 'usuarios',
                key: 'id',
            },
            allowNull: true,
        },
    }, {
        tableName: 'asistencias',
        freezeTableName: true,
        timestamps: true,
        underscored: false
    });

    asistencia.associate = (models) => {
    };

    return asistencia;
};
