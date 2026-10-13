const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Pedido = sequelize.define('Pedido', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    codigo: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    nombre_cliente: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    telefono: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    direccion: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    tipo_entrega: {
      type: DataTypes.ENUM('delivery', 'recojo'),
      allowNull: false,
    },
    estado: {
      type: DataTypes.ENUM('pendiente', 'aprobado', 'rechazado', 'cancelado', 'hecho', 'pago_pendiente', 'pagado'),
      defaultValue: 'pendiente',
    },
    monto_total: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0.00,
    },
    comentarios: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    motivo_rechazo: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    // Flujo WhatsApp: comprobante de pago, código de recojo, vencimiento y origen
    comprobante_url: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    codigo_recojo: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    expira_en: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    origen: {
      type: DataTypes.ENUM('app', 'whatsapp'),
      defaultValue: 'app',
    },
    venta_realizada: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    id_sucursal: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'sucursales',
        key: 'id'
      }
    },
  }, {
    tableName: 'pedidos',
    timestamps: true,
  });

  Pedido.associate = (models) => {
  };

  return Pedido;
};
