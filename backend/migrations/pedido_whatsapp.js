// Migración flujo WhatsApp: estados pago_pendiente/pagado + campos de pago/recojo.
// Idempotente: solo agrega lo que falte. Ejecutar: npm run migrate:pedido-whatsapp
// Reversible con ROLLBACK=1.
const db = require('../models');

const NUEVOS_ESTADOS = "'pendiente', 'aprobado', 'rechazado', 'cancelado', 'hecho', 'pago_pendiente', 'pagado'";
const ESTADOS_BASE = "'pendiente', 'aprobado', 'rechazado', 'cancelado', 'hecho'";

async function columnaExiste(table, column) {
  const [rows] = await db.sequelize.query(
    `SELECT COUNT(*) AS n FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    { replacements: [table, column] }
  );
  return Number(rows[0].n) > 0;
}

async function migrate() {
  await db.sequelize.query(
    `ALTER TABLE pedidos MODIFY COLUMN estado ENUM(${NUEVOS_ESTADOS}) NOT NULL DEFAULT 'pendiente'`
  );
  const nuevas = [
    ['comprobante_url', 'VARCHAR(255) NULL'],
    ['codigo_recojo', 'VARCHAR(255) NULL'],
    ['expira_en', 'DATETIME NULL'],
    ['origen', "ENUM('app', 'whatsapp') NOT NULL DEFAULT 'app'"],
  ];
  for (const [col, def] of nuevas) {
    if (!(await columnaExiste('pedidos', col))) {
      await db.sequelize.query(`ALTER TABLE pedidos ADD COLUMN ${col} ${def}`);
      console.log(`Columna agregada: ${col}`);
    } else {
      console.log(`Columna ya existe: ${col}`);
    }
  }
  // Relleno: codigo_recojo = codigo donde esté vacío
  await db.sequelize.query(
    `UPDATE pedidos SET codigo_recojo = codigo WHERE codigo_recojo IS NULL`
  );
  console.log('Migración pedido-whatsapp OK');
}

async function rollback() {
  await db.sequelize.query(
    `UPDATE pedidos SET estado = 'cancelado' WHERE estado IN ('pago_pendiente', 'pagado')`
  );
  await db.sequelize.query(
    `ALTER TABLE pedidos MODIFY COLUMN estado ENUM(${ESTADOS_BASE}) NOT NULL DEFAULT 'pendiente'`
  );
  for (const col of ['comprobante_url', 'codigo_recojo', 'expira_en', 'origen']) {
    if (await columnaExiste('pedidos', col)) {
      await db.sequelize.query(`ALTER TABLE pedidos DROP COLUMN ${col}`);
      console.log(`Columna eliminada: ${col}`);
    }
  }
  console.log('Rollback pedido-whatsapp OK');
}

(async () => {
  try {
    if (process.env.ROLLBACK === '1') await rollback();
    else await migrate();
  } catch (error) {
    console.error('Error en migración pedido-whatsapp:', error.message);
    process.exitCode = 1;
  } finally {
    process.exit();
  }
})();
