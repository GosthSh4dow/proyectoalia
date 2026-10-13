module.exports = (sequelize, DataTypes) => {
  const Usuario = sequelize.define('Usuario', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    nombre: {
      type: DataTypes.STRING,
      allowNull: false
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      }
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false
    },
    rol: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'user'
    },
    estado: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'activado'
    },
    id_sucursal: {
      type: DataTypes.INTEGER,
      allowNull: true
    },
    hora_entrada: {
      type: DataTypes.TIME,
      allowNull: true
    },
    hora_salida: {
      type: DataTypes.TIME,
      allowNull: true
    },
    turno: {
      type: DataTypes.STRING,
      allowNull: true
    }
  }, {
    tableName: 'usuarios',
    timestamps: true,
    underscored: true
  });

  Usuario.associate = function(models) {
    Usuario.belongsTo(models.Sucursal, {
      foreignKey: 'id_sucursal',
      as: 'sucursal'
    });

    Usuario.hasMany(models.RefreshToken, {
      foreignKey: 'user_id',
      as: 'refreshTokens',
      onDelete: 'CASCADE'
    });
  };

  return Usuario;
};
