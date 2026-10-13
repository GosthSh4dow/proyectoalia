const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const db = require('./models');
const app = express();

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
}));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

const productoRoutes = require('./routes/productos');
const productoImagenRoutes = require('./routes/productoImagenes');
const clienteRoutes = require('./routes/clientes');
const ventaRoutes = require('./routes/ventas');
const usuarioRoutes = require('./routes/usuarios');
const sucursalRoutes = require('./routes/sucursales');
const reportesRoutes = require('./routes/reportesRoutes');
const catalogoInfoRoutes = require('./routes/catalogoInfo');

app.use('/api/productos', productoRoutes);
app.use('/api', productoImagenRoutes);
app.use('/api/clientes', clienteRoutes);
app.use('/api/ventas', ventaRoutes);
app.use('/api/usuarios', usuarioRoutes);
app.use('/api/sucursales', sucursalRoutes);
app.use('/api/reportes', reportesRoutes);
app.use('/api/catalogo-info', catalogoInfoRoutes);

db.sequelize.sync({ force: false }).then(() => {
    console.log('Base de datos sincronizada');
    app.listen(3001, () => {
        console.log('Servidor corriendo en http://localhost:3001');
    });
}).catch((error) => {
    console.error('Error al sincronizar la base de datos:', error);
});