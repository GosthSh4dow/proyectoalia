module.exports = (sequelize, DataTypes) => {
    const Sucursal = sequelize.define('Sucursal', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
        },
        nombre: {
            type: DataTypes.STRING,
            allowNull: false,
        },
        direccion: {
            type: DataTypes.STRING,
        },
        estado: {
            type: DataTypes.ENUM('activa', 'inactiva'),
            defaultValue: 'activa',
        },
        hwid: {
            type: DataTypes.STRING,
            unique: true,
            allowNull: false,
        }
    },
    {
        tableName: 'sucursales',
        timestamps: true,
    });

    Sucursal.associate = (models) => {
    };

    return Sucursal;
};
