const mysql = require('mysql2/promise');
require('dotenv').config();

async function checkDb() {
    try {
        const connection = await mysql.createConnection({
            host: process.env.DB_HOST,
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            database: process.env.DB_NAME
        });

        console.log(`Conectado a la BD: ${process.env.DB_NAME}`);

        const [tables] = await connection.execute('SHOW TABLES');
        console.log('Tablas en la BD:', tables);

        if (tables.length > 0) {
            try {
                const [sucursales] = await connection.execute('DESCRIBE sucursales');
                console.log('\nEstructura de sucursales:', sucursales);
            } catch (e) {
                console.log('\n❌ Tabla sucursales no encontrada o error:', e.message);
            }

            try {
                const [usuarios] = await connection.execute('DESCRIBE usuarios');
                console.log('\nEstructura de usuarios:', usuarios);
            } catch (e) {
                console.log('\n❌ Tabla usuarios no encontrada o error:', e.message);
            }
        } else {
            console.log("⚠️ NO HAY TABLAS. La base de datos está vacía.");
        }

        await connection.end();
    } catch (error) {
        console.error('Error connecting:', error);
    }
}

checkDb();
