module.exports = (sequelize, DataTypes) => {
  const Promocion = sequelize.define('Promocion', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    tipo: {
      type: DataTypes.ENUM('descuento', '2x1'),
      allowNull: false,
    },
    descripcion: {
      type: DataTypes.TEXT,
    },
    valor: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    fecha_inicio: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    fecha_fin: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  }, {
    tableName: 'promocions',
    freezeTableName: true,
    timestamps: true,
    underscored: false,
  });

  Promocion.associate = () => {};

  return Promocion;
};
