const db = require('./models');

async function syncSpecificTables() {
    try {
        await db.Caja.sync({ alter: true });
        await db.Egreso.sync({ alter: true });
        process.exit(0);
    } catch (error) {
        console.error('Error al sincronizar:', error);
        process.exit(1);
    }
}

syncSpecificTables();