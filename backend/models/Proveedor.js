module.exports = (sequelize, DataTypes) => {
  const Proveedor = sequelize.define('Proveedor', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    nombre: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    contacto: {
      type: DataTypes.STRING,
    },
    email: {
      type: DataTypes.STRING,
    },
  }, {
    tableName: 'proveedors',
    freezeTableName: true,
    underscored: false,
    timestamps: true,
  });

  Proveedor.associate = (models) => {
    Proveedor.hasMany(models.Producto, {
      foreignKey: 'proveedor_id',
      as: 'productos',
    });
  };

  return Proveedor;
};
