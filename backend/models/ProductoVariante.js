module.exports = (sequelize, DataTypes) => {
    const ProductoVariante = sequelize.define('ProductoVariante', {
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
            onDelete: 'CASCADE'
        },
        color: {
            type: DataTypes.STRING,
            allowNull: false
        },
        cantidad: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0,
            validate: {
                min: 0
            }
        },
        imagen_url: {
            type: DataTypes.STRING,
            allowNull: true,
            defaultValue: null
        },
        activo: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'producto_variantes',
        timestamps: true
    });

    ProductoVariante.associate = function (models) {
        ProductoVariante.belongsTo(models.Producto, {
            foreignKey: 'producto_id',
            as: 'producto'
        });
    };

    return ProductoVariante;
};
