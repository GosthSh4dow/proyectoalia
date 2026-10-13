module.exports = (sequelize, DataTypes) => {
    const Asistencia = sequelize.define('Asistencia', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
        },
        id_usuario: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'Usuarios',
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
                model: 'Usuarios',
                key: 'id',
            },
            allowNull: true,
        },
    },{
    tableName: 'asistencia',
  });

    Asistencia.associate = (models) => {
        Asistencia.belongsTo(models.Usuario, { foreignKey: 'id_usuario', as: 'usuario' });
        Asistencia.belongsTo(models.Usuario, { foreignKey: 'reemplazo_id', as: 'reemplazo' });
    };

    return Asistencia;
};