module.exports = (sequelize, DataTypes) => {
  const Anuncio = sequelize.define('Anuncio', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    titulo: {
      type: DataTypes.STRING,
      allowNull: false
    },
    mensaje: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    tipo: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'info'
    },
    imagen: {
      type: DataTypes.STRING,
      allowNull: true
    },
    fecha_inicio: {
      type: DataTypes.DATE,
      allowNull: false
    },
    fecha_expiracion: {
      type: DataTypes.DATE,
      allowNull: false
    },
    activo: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    bloqueante: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    boton_texto: {
      type: DataTypes.STRING,
      allowNull: true
    },
    boton_url: {
      type: DataTypes.STRING,
      allowNull: true
    },
    lottie_json: {
      type: DataTypes.STRING,
      allowNull: true
    },
    id_usuario_creador: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    tableName: 'anuncios',
    freezeTableName: true,
    timestamps: true,
    underscored: true
  });

  Anuncio.associate = function(models) {
    Anuncio.belongsTo(models.Usuario, {
      foreignKey: 'id_usuario_creador',
      as: 'creador'
    });
  };

  return Anuncio;
};
