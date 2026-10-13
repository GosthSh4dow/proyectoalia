const db = require('../models');

const addTipoPagoToVentas = async () => {
  try {
    await db.sequelize.query(`
      ALTER TABLE ventas 
      ADD COLUMN tipo_pago ENUM('efectivo', 'qr') NOT NULL DEFAULT 'efectivo'
    `);
  } catch (error) {
    console.error('Error al agregar la columna tipo_pago:', error);
  } finally {
    process.exit();
  }
};

addTipoPagoToVentas();
