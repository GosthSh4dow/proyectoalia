process.env.TZ = 'America/La_Paz';

const express = require('express');
const app = express();
const dotenv = require('dotenv');
const cors = require('cors');
const fileUpload = require('express-fileupload');
const winston = require('winston');
const path = require('path');
const fs = require('fs');

dotenv.config();
const db = require('./models');

const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'warn' : 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'error.log'),
      level: 'warn',
      maxsize: 5242880,
      maxFiles: 5,
    }),
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'combined.log'),
      maxsize: 10485760,
      maxFiles: 5,
    })
  ]
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({ format: winston.format.simple() }));
}

app.use(express.json());
// Detrás de nginx: IP real del cliente en X-Forwarded-For (rate-limit y logs).
app.set('trust proxy', 1);
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-requested-with'],
}));

app.use(fileUpload({
  createParentPath: true,
  limits: { fileSize: 10 * 1024 * 1024 },
}));

const uploadsDir = path.join(__dirname, 'uploads');
const animacionesDir = path.join(uploadsDir, 'animaciones');
const logsDir = path.join(__dirname, 'logs');

[uploadsDir, animacionesDir, logsDir].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

app.use('/uploads', express.static(uploadsDir));
app.use('/api/uploads', express.static(uploadsDir));
app.use('/api/uploads/animaciones', express.static(animacionesDir));

const skipLogging = ['/api/uploads/', '/api/ping', '/api/health', '/api/productos'];
app.use((req, res, next) => {
  const shouldSkip = skipLogging.some(route => req.originalUrl.startsWith(route));
  if (!shouldSkip) logger.info(`${req.method} ${req.originalUrl} - IP: ${req.ip}`);
  next();
});

const routes = {
  clientes: require('./routes/clientes'),
  sucursales: require('./routes/sucursales'),
  usuarios: require('./routes/usuarios'),
  proveedores: require('./routes/proveedores'),
  productos: require('./routes/productos'),
  productoMaestro: require('./routes/productoMaestro'),
  productoCodigo: require('./routes/productoCodigo'),
  promociones: require('./routes/promociones'),
  ventas: require('./routes/ventas'),
  auth: require('./routes/auth'),
  categoria: require('./routes/categoria'),
  caja: require('./routes/caja'),
  boleta: require('./routes/boleta'),
  asistencias: require('./routes/asistenciaRoutes'),
  reportes: require('./routes/reportesRoutes'),
  descripcion: require('./routes/descripcionRoutes'),
  pedidos: require('./routes/pedidos'),
  imagenes: require('./routes/productoImagenes'),
  fidelidad: require('./routes/fidelidad'),
  anuncios: require('./routes/anuncios'),
  catalogo: require('./routes/catalogoInfo'),
  catalogoFeed: require('./routes/catalogoFeed'),
  whatsapp: require('./routes/whatsapp')
};

app.get('/', (req, res) => res.send('Backend funcionando con exito!'));
// Salud del API (sin auth): la APK lo usa para verificar conexión al backend.
app.get('/api/health', (req, res) => res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() }));
app.use('/api/clientes', routes.clientes);
app.use('/api/sucursales', routes.sucursales);
app.use('/api/usuarios', routes.usuarios);
app.use('/api/proveedores', routes.proveedores);
app.use('/api/productos', routes.productos);
app.use('/api/productos-maestros', routes.productoMaestro);
app.use('/api/codigos', routes.productoCodigo);
app.use('/api/promociones', routes.promociones);
app.use('/api/ventas', routes.ventas);
app.use('/api/categorias', routes.categoria);
app.use('/api/auth', routes.auth);
app.use('/api/cajas', routes.caja);
app.use('/api/boletas', routes.boleta);
app.use('/api/asistencias', routes.asistencias);
app.use('/api/reportes', routes.reportes);
app.use('/api/generar-descripcion', routes.descripcion);
app.use('/api/pedidos', routes.pedidos);
app.use('/api', routes.imagenes);
app.use('/api/fidelidad', routes.fidelidad);
app.use('/api/anuncios', routes.anuncios);
app.use('/api/catalogo-info', routes.catalogo);
app.use('/api/catalogo', routes.catalogoFeed);
app.use('/api/whatsapp', routes.whatsapp);

const syncDb = async () => {
  try {
    logger.info('Sincronizando base de datos...');
    await db.Sucursal.sync({ alter: false });
    await db.Usuario.sync({ alter: false });
    await db.Caja.sync({ alter: false });
    logger.info('Base de datos sincronizada');
  } catch (err) {
    logger.error('Error al sincronizar BD:', err);
  }
};
syncDb();

app.use((err, req, res, next) => {
  logger.error(`Error en ${req.path}: ${err.message}`, { stack: err.stack });
  res.status(err.status || 500).json({
    error: err.message || 'Error interno del servidor',
    path: req.path,
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3009;
app.listen(PORT, () => logger.info(`Servidor API corriendo en puerto ${PORT}`));

// Expirador de pedidos sin pago: cancela aprobados/pago_pendiente vencidos cada 5 min.
try {
  const pedidoController = require('./controllers/pedidoController');
  setInterval(() => {
    pedidoController.expirarPedidosVencidos().catch((e) => logger.error(`Expirador: ${e.message}`));
  }, 5 * 60 * 1000);
} catch (e) {
  logger.error(`No se pudo iniciar el expirador de pedidos: ${e.message}`);
}

const levantarServidorSecundario = (nombre, puerto, carpeta) => {
  const rutaBuild = path.join(__dirname, carpeta);
  if (fs.existsSync(rutaBuild)) {
    const subApp = express();
    subApp.use(express.static(rutaBuild));
    subApp.get('*', (req, res) => res.sendFile(path.join(rutaBuild, 'index.html')));
    subApp.listen(puerto, () => logger.info(`${nombre} servido en puerto ${puerto}`))
          .on('error', (e) => logger.error(`Error en puerto ${puerto}: ${e.message}`));
  } else {
    logger.warn(`Carpeta ${carpeta} no encontrada. No se inicio el ${nombre}.`);
  }
};

levantarServidorSecundario('Frontend Principal', 4001, 'frontend-build');
levantarServidorSecundario('Catalogo Publico', 4242, 'catalogo-build');