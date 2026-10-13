'use strict';

module.exports = (sequelize, DataTypes) => {
  const RefreshToken = sequelize.define('RefreshToken', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    token: {
      type: DataTypes.STRING(512),
      allowNull: false
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    expires_at: {
      type: DataTypes.DATE,
      allowNull: false
    },
    revoked: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    }
  }, {
    tableName: 'refresh_tokens',
    timestamps: true,
    underscored: true
  });

  RefreshToken.associate = function(models) {
    RefreshToken.belongsTo(models.Usuario, {
      foreignKey: 'user_id',
      as: 'usuario'
    });
  };

  return RefreshToken;
};
