module.exports = (sequelize, DataTypes) => {
  const ProductoPromocion = sequelize.define('ProductoPromocion', {
    id_producto: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      references: {
        model: 'productos',
        key: 'id',
      },
    },
    id_promocion: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      references: {
        model: 'promocions',
        key: 'id',
      },
    },
  }, {
    tableName: 'productopromocions',
    freezeTableName: true,
    timestamps: true,
    underscored: false,
  });

  return ProductoPromocion;
};
