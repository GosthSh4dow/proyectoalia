module.exports = (sequelize, DataTypes) => {
  const ProductoImagen = sequelize.define('ProductoImagen', {
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
    ruta_imagen: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    es_principal: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    orden: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
  }, {
    tableName: 'producto_imagenes',
    timestamps: true,
  });

  ProductoImagen.associate = (models) => {
    ProductoImagen.belongsTo(models.Producto, {
      foreignKey: 'producto_id',
      as: 'producto',
    });
  };

  return ProductoImagen;
};
