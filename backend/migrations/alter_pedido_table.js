const db = require('../models');

const alterPedidoTable = async () => {
  try {
    await db.sequelize.query(`
      ALTER TABLE pedidos 
      MODIFY COLUMN estado ENUM('pendiente', 'aprobado', 'rechazado', 'cancelado', 'hecho') 
      NOT NULL DEFAULT 'pendiente'
    `);
  } catch (error) {
    console.error('Error al modificar la tabla pedidos:', error);
  } finally {
    process.exit();
  }
};

alterPedidoTable();
