module.exports = (sequelize, DataTypes) => {
    const ProductoCodigo = sequelize.define('ProductoCodigo', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
        },
        producto_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: 'Productos',
                key: 'id',
            },
        },
        codigo: {
            type: DataTypes.STRING,
            allowNull: false,
        },
        tipo: {
            type: DataTypes.ENUM('barras', 'sku', 'interno', 'otro'),
            allowNull: false,
            defaultValue: 'barras',
        },
        es_principal: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
        },
    }, {
        tableName: 'producto_codigos',
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ['producto_id', 'codigo'],
                name: 'unique_producto_codigo',
            },
            {
                fields: ['codigo'],
                name: 'idx_codigo',
            },
        ],
    });

    ProductoCodigo.associate = (models) => {
        ProductoCodigo.belongsTo(models.Producto, {
            foreignKey: 'producto_id',
            as: 'producto',
        });
    };

    return ProductoCodigo;
};
