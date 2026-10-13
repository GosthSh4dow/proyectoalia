module.exports = (sequelize, DataTypes) => {
  const Boleta = sequelize.define('Boleta', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    id_usuario: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'usuarios',
        key: 'id',
      },
    },
    monto_turno: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    total: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    asistencias_count: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    faltas_injustificadas: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    faltas_justificadas: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    reemplazos_count: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    turnos_reemplazados: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    fecha_pago: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  }, {
    tableName: 'boleta',
    freezeTableName: true,
    underscored: true,
    timestamps: true
  });

  Boleta.associate = (models) => {
  };

  return Boleta;
};
