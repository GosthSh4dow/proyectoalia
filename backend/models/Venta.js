module.exports = (sequelize, DataTypes) => {
  const venta = sequelize.define('venta', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    fecha: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
    monto_total: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    id_cliente: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'clientes',
        key: 'id_cliente',
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
    id_sucursal: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'sucursales',
        key: 'id',
      },
    },
    tipo_pago: {
      type: DataTypes.ENUM('efectivo', 'qr'),
      allowNull: false,
      defaultValue: 'efectivo',
    },
  }, {
    tableName: 'venta',
    freezeTableName: true,
    timestamps: true,
    underscored: false,
  });

  venta.associate = () => {};

  return venta;
};
