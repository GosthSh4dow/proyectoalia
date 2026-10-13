module.exports = (sequelize, DataTypes) => {
  const ProductoMaestro = sequelize.define('ProductoMaestro', {
    nombre: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    descripcion_base: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    imagen_compartida: {
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
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  }, {
    tableName: 'producto_maestros',
    timestamps: true,
  });

  ProductoMaestro.associate = (models) => {
    ProductoMaestro.hasMany(models.Producto, {
      foreignKey: 'producto_maestro_id',
      as: 'instancias',
    });

    ProductoMaestro.belongsTo(models.Proveedor, {
      foreignKey: 'proveedor_id',
      as: 'proveedor',
    });

    ProductoMaestro.belongsTo(models.Categoria, {
      foreignKey: 'categoria_id',
      as: 'categoria',
    });
  };

  return ProductoMaestro;
};
