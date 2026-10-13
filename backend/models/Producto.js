module.exports = (sequelize, DataTypes) => {
  const Producto = sequelize.define('Producto', {
    nombre: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    descripcion: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    costo: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    precio_venta: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    stock: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    fecha_caducidad: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    codigo_barras: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    colores: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: [],
    },
    imagen: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null,
    },
    proveedor_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Proveedors',
        key: 'id',
      },
    },
    categoria_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Categoria',
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
    producto_maestro_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'producto_maestros',
        key: 'id',
      },
    }
  }, {
    tableName: 'productos',
    freezeTableName: true,
    underscored: false
  });

  Producto.associate = (models) => {
    Producto.belongsTo(models.ProductoMaestro, {
      foreignKey: 'producto_maestro_id',
      as: 'productoMaestro',
    });

    Producto.hasMany(models.ProductoCodigo, {
      foreignKey: 'producto_id',
      as: 'codigos',
    });
  };

  return Producto;
};
