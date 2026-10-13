const { DataTypes } = require('sequelize');

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('catalogo_info', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      telefono: {
        type: DataTypes.STRING,
        allowNull: false
      },
      email: {
        type: DataTypes.STRING,
        allowNull: false
      },
      direccion: {
        type: DataTypes.TEXT,
        allowNull: false
      },
      horarios_semana: {
        type: DataTypes.STRING,
        allowNull: false,
        defaultValue: 'Lun-Sáb: 8:00-20:00'
      },
      horarios_domingo: {
        type: DataTypes.STRING,
        allowNull: false,
        defaultValue: 'Dom: 9:00-14:00'
      },
      facebook_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      instagram_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      tiktok_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      whatsapp_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      grupos_whatsapp: {
        type: DataTypes.JSON,
        allowNull: true,
        defaultValue: []
      },
      descripcion_empresa: {
        type: DataTypes.TEXT,
        allowNull: true
      },
      logo_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      banner_url: {
        type: DataTypes.STRING,
        allowNull: true
      },
      activo: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updated_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
      }
    });

    await queryInterface.bulkInsert('catalogo_info', [{
      telefono: '+591 74842996',
      email: 'info@channels.com',
      direccion: 'Calle Omiste entre Sucre, frente a Impuestos Nacionales',
      horarios_semana: 'Lun-Sáb: 8:00-20:00',
      horarios_domingo: 'Dom: 9:00-14:00',
      facebook_url: 'https://www.facebook.com/share/1BJs4XPzVu/',
      instagram_url: 'https://www.instagram.com',
      tiktok_url: 'https://www.tiktok.com/@accesorioschannels',
      whatsapp_url: 'https://wa.me/59174842996',
      grupos_whatsapp: JSON.stringify([
        { name: "Grupo 1", link: "https://chat.whatsapp.com/LqwALOUhgol9k9uFSgkijy", members: "250+", status: "activo" },
        { name: "Grupo 2", link: "https://chat.whatsapp.com/D8Z4wfqn730A2MXEqxLIT3", members: "230+", status: "activo" },
        { name: "Grupo 3", link: "https://chat.whatsapp.com/CToEbetZpr0KCdffPK3W4A", members: "200+", status: "activo" },
        { name: "Grupo 4", link: "https://chat.whatsapp.com/C9bLWNAGXwYIO82AtOG98E", members: "245+", status: "activo" },
        { name: "Grupo 5", link: "https://chat.whatsapp.com/Gqn3BZSy9a5JQpBZBH2G53", members: "210+", status: "nuevo" },
        { name: "Grupo 6", link: "https://chat.whatsapp.com/BUQSFdzGQQ4FS0Abp4HjJs", members: "190+", status: "activo" }
      ]),
      descripcion_empresa: 'Bisutería Channels - Los mejores accesorios para ti',
      logo_url: null,
      banner_url: null,
      activo: true,
      created_at: new Date(),
      updated_at: new Date()
    }]);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('catalogo_info');
  }
}; 