const db = require('./models');

async function checkIndexes() {
    try {
        const [results] = await db.sequelize.query("SHOW INDEX FROM Productos");
        console.log("Indexes on Productos table:");
        results.forEach(idx => {
            console.log(`Key_name: ${idx.Key_name}, Column_name: ${idx.Column_name}, Non_unique: ${idx.Non_unique}`);
        });
    } catch (error) {
        console.error('Error:', error);
    } finally {
        await db.sequelize.close();
    }
}

checkIndexes();
