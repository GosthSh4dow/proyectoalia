module.exports = (sequelize, DataTypes) => {
  const detalleventa = sequelize.define('detalleventa', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
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
    },
  }, {
    tableName: 'detalleventa',
    freezeTableName: true,
    timestamps: true,
    underscored: false,
  });

  detalleventa.associate = () => {};

  return detalleventa;
};
