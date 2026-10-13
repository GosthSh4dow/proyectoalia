const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class DetallePedido extends Model {}

  DetallePedido.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    pedido_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    producto_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    cantidad: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    precio_unitario: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    subtotal: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    }
  }, {
    sequelize,
    modelName: 'DetallePedido',
    tableName: 'detalle_pedidos',
    timestamps: true,
  });

  return DetallePedido;
};
