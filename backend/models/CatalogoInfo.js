'use strict';
const { Model, DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  class CatalogoInfo extends Model {
    static associate(models) {
    }
  }

  CatalogoInfo.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    telefono: {
      type: DataTypes.STRING(20),
      allowNull: true
    },
    email: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    direccion: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    horarios_semana: {
      type: DataTypes.STRING(200),
      allowNull: true
    },
    horarios_domingo: {
      type: DataTypes.STRING(200),
      allowNull: true
    },
    descripcion_empresa: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    facebook_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    instagram_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    tiktok_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    whatsapp_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    grupos_whatsapp: {
      type: DataTypes.TEXT,
      allowNull: true,
      get() {
        const rawValue = this.getDataValue('grupos_whatsapp');
        if (!rawValue) return [];
        try {
          return JSON.parse(rawValue);
        } catch (error) {
          console.error('Error parsing grupos_whatsapp:', error);
          return [];
        }
      },
      set(value) {
        this.setDataValue('grupos_whatsapp', JSON.stringify(value));
      }
    },
    titulo_banner: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: "Channel's"
    },
    subtitulo_banner: {
      type: DataTypes.STRING(200),
      allowNull: true,
      defaultValue: "Bisutería & Accesorios que Expresan tu Estilo Único"
    },
    descripcion_banner: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    boton_banner: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: "Explorar Colección"
    },
    url_boton_banner: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: "#catalogo"
    },
    banner_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    banner_images: {
      type: DataTypes.TEXT,
      allowNull: true,
      get() {
        const rawValue = this.getDataValue('banner_images');
        if (!rawValue) return [];
        try {
          return JSON.parse(rawValue);
        } catch (error) {
          console.error('Error parsing banner_images:', error);
          return [];
        }
      },
      set(value) {
        this.setDataValue('banner_images', JSON.stringify(value));
      }
    },
    logo_url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    logo_images: {
      type: DataTypes.TEXT,
      allowNull: true,
      get() {
        const rawValue = this.getDataValue('logo_images');
        if (!rawValue) return [];
        try {
          return JSON.parse(rawValue);
        } catch (error) {
          console.error('Error parsing logo_images:', error);
          return [];
        }
      },
      set(value) {
        this.setDataValue('logo_images', JSON.stringify(value));
      }
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    }
  }, {
    sequelize,
    modelName: 'CatalogoInfo',
    tableName: 'catalogo_info',
    timestamps: true,
    underscored: true
  });

  return CatalogoInfo;
};
