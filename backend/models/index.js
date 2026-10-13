const { Sequelize } = require('sequelize');
const dotenv = require('dotenv');

dotenv.config();

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASSWORD,
  {
    host: process.env.DB_HOST,
    dialect: 'mysql',
    logging: false,
    timezone: '-04:00',
    define: {
      underscored: false,
      freezeTableName: true,
      timestamps: true,
    },
  }
);

const db = {};
db.Sequelize = Sequelize;
db.sequelize = sequelize;

db.Categoria = require('./Categoria')(sequelize, Sequelize.DataTypes);
db.Sucursal = require('./Sucursal')(sequelize, Sequelize.DataTypes);
db.Usuario = require('./Usuario')(sequelize, Sequelize.DataTypes);
db.Proveedor = require('./Proveedor')(sequelize, Sequelize.DataTypes);
db.Producto = require('./Producto')(sequelize, Sequelize.DataTypes);
db.Promocion = require('./Promocion')(sequelize, Sequelize.DataTypes);
db.ProductoPromocion = require('./ProductoPromocion')(sequelize, Sequelize.DataTypes);
db.Cliente = require('./Cliente')(sequelize, Sequelize.DataTypes);
db.Venta = require('./Venta')(sequelize, Sequelize.DataTypes);
db.DetalleVenta = require('./DetalleVenta')(sequelize, Sequelize.DataTypes);
db.Asistencia = require('./Asistencia')(sequelize, Sequelize.DataTypes);
db.Boleta = require('./Boleta')(sequelize, Sequelize.DataTypes);
db.Caja = require('./Caja')(sequelize, Sequelize.DataTypes);
db.Pedido = require('./Pedido')(sequelize, Sequelize.DataTypes);
db.DetallePedido = require('./DetallePedido')(sequelize, Sequelize.DataTypes);
db.ProductoImagen = require('./ProductoImagen')(sequelize, Sequelize.DataTypes);
db.RefreshToken = require('./refreshToken')(sequelize, Sequelize.DataTypes);
db.ClienteFidelidad = require('./ClienteFidelidad')(sequelize, Sequelize.DataTypes);
db.Anuncio = require('./Anuncio')(sequelize, Sequelize.DataTypes);
db.CatalogoInfo = require('./CatalogoInfo')(sequelize, Sequelize.DataTypes);
db.ProductoMaestro = require('./ProductoMaestro')(sequelize, Sequelize.DataTypes);
db.ProductoCodigo = require('./ProductoCodigo')(sequelize, Sequelize.DataTypes);
db.Egreso = require('./Egreso')(sequelize, Sequelize.DataTypes);
db.ProductoVariante = require('./ProductoVariante')(sequelize, Sequelize.DataTypes);

Object.keys(db).forEach((modelName) => {
  if (db[modelName].associate) {
    db[modelName].associate(db);
  }
});

db.Sucursal.hasMany(db.Usuario, { foreignKey: 'id_sucursal', as: 'usuarios' });
db.Usuario.hasMany(db.Egreso, { foreignKey: 'id_usuario', as: 'egresos' });
db.Caja.hasMany(db.Egreso, { foreignKey: 'id_caja', as: 'egresos_detalle' });
db.Producto.hasMany(db.ProductoVariante, { foreignKey: 'producto_id', as: 'variantes' });

db.Usuario.hasMany(db.Venta, { foreignKey: 'id_usuario', as: 'ventas' });
db.Sucursal.hasMany(db.Venta, { foreignKey: 'id_sucursal', as: 'ventas' });
db.Venta.belongsTo(db.Usuario, { foreignKey: 'id_usuario', as: 'usuario' });
db.Venta.belongsTo(db.Sucursal, { foreignKey: 'id_sucursal', as: 'sucursal' });

db.Venta.hasMany(db.DetalleVenta, { foreignKey: 'id_venta', as: 'detalles' });
db.DetalleVenta.belongsTo(db.Venta, { foreignKey: 'id_venta', as: 'venta' });
db.DetalleVenta.belongsTo(db.Producto, { foreignKey: 'id_producto', as: 'producto' });

db.Proveedor.hasMany(db.Producto, { foreignKey: 'proveedor_id', as: 'productos_proveedor' });
db.Producto.belongsTo(db.Proveedor, { foreignKey: 'proveedor_id', as: 'proveedor' });

db.Producto.belongsToMany(db.Promocion, { through: db.ProductoPromocion, foreignKey: 'id_producto', as: 'promociones' });
db.Promocion.belongsToMany(db.Producto, { through: db.ProductoPromocion, foreignKey: 'id_promocion', as: 'productos' });

db.Cliente.hasMany(db.Venta, { foreignKey: 'id_cliente', as: 'ventas' });
db.Venta.belongsTo(db.Cliente, { foreignKey: 'id_cliente', as: 'cliente' });

db.Usuario.hasMany(db.Asistencia, { foreignKey: 'id_usuario', as: 'asistencias' });
db.Asistencia.belongsTo(db.Usuario, { foreignKey: 'id_usuario', as: 'usuario' });
db.Usuario.hasMany(db.Asistencia, { foreignKey: 'reemplazo_id', as: 'reemplazos' });
db.Asistencia.belongsTo(db.Usuario, { foreignKey: 'reemplazo_id', as: 'reemplazo' });

db.Usuario.hasMany(db.Boleta, { foreignKey: 'id_usuario', as: 'boletas' });
db.Boleta.belongsTo(db.Usuario, { foreignKey: 'id_usuario', as: 'usuario' });

db.Categoria.hasMany(db.Producto, { foreignKey: 'categoria_id', as: 'productos_categoria' });
db.Producto.belongsTo(db.Categoria, { foreignKey: 'categoria_id', as: 'categoria' });

db.Sucursal.hasMany(db.Producto, { foreignKey: 'id_sucursal', as: 'productos_sucursal' });
db.Producto.belongsTo(db.Sucursal, { foreignKey: 'id_sucursal', as: 'sucursal' });

db.Usuario.hasMany(db.Caja, { foreignKey: 'cerrado_por', as: 'cierres' });
db.Caja.belongsTo(db.Usuario, { foreignKey: 'cerrado_por', as: 'usuario_cierre' });
db.Usuario.hasMany(db.Caja, { foreignKey: 'abierto_por', as: 'aperturas' });
db.Caja.belongsTo(db.Usuario, { foreignKey: 'abierto_por', as: 'usuario_apertura' });

db.Sucursal.hasMany(db.Caja, { foreignKey: 'id_sucursal', as: 'cajas' });
db.Caja.belongsTo(db.Sucursal, { foreignKey: 'id_sucursal', as: 'sucursal' });

db.Pedido.hasMany(db.DetallePedido, { foreignKey: 'pedido_id', as: 'detalles' });
db.DetallePedido.belongsTo(db.Pedido, { foreignKey: 'pedido_id', as: 'pedido' });
db.DetallePedido.belongsTo(db.Producto, { foreignKey: 'producto_id', as: 'producto' });

db.Pedido.belongsTo(db.Sucursal, { foreignKey: 'id_sucursal', as: 'sucursal' });
db.Sucursal.hasMany(db.Pedido, { foreignKey: 'id_sucursal', as: 'pedidos' });

db.Producto.hasMany(db.ProductoImagen, {
  foreignKey: 'producto_id',
  as: 'imagenes',
  onDelete: 'CASCADE',
});

db.Cliente.hasOne(db.ClienteFidelidad, { foreignKey: 'cliente_id', as: 'fidelidad' });
db.ClienteFidelidad.belongsTo(db.Cliente, { foreignKey: 'cliente_id', as: 'cliente_fidelidad' });

module.exports = db;
