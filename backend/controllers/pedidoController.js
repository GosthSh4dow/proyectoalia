const db = require('../models');
const { Pedido, DetallePedido, Producto, Sucursal, Venta } = db;
const { Op } = require('sequelize');
const rateLimit = require('express-rate-limit');

const generarCodigoPedido = () => {
  const fecha = new Date();
  const year = fecha.getFullYear().toString().slice(-2);
  const month = (fecha.getMonth() + 1).toString().padStart(2, '0');
  const day = fecha.getDate().toString().padStart(2, '0');
  const randomPart = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `PED-${year}${month}${day}-${randomPart}`;
};

exports.pedidoLimiter = rateLimit({
  windowMs: 30 * 1000,
  max: 200,
  message: { error: 'Demasiados pedidos. Por favor, intente más tarde.' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const clientIp = req.headers['x-forwarded-for'] || req.ip;
    const userAgent = req.headers['user-agent'] || '';
    const hasValidUserAgent = userAgent.length > 10;
    if (hasValidUserAgent) {
      return clientIp + '_' + userAgent.substring(0, 30) + '_' + (req.headers['accept-language'] || '').substring(0, 5);
    }
    return clientIp;
  },
  skip: (req) => {
    const userAgent = (req.headers['user-agent'] || '').toLowerCase();
    const isMobileDevice =
      userAgent.includes('android') ||
      userAgent.includes('iphone') ||
      userAgent.includes('mobile') ||
      userAgent.includes('samsung') ||
      userAgent.includes('huawei');
    return isMobileDevice;
  },
  requestWasSuccessful: (req, res) => {
    return res.statusCode === 201;
  }
});

exports.crearPedido = async (req, res) => {
  const transaction = await db.sequelize.transaction();
  try {
    const { nombre_cliente, telefono, direccion, tipo_entrega, items, comentarios } = req.body;

    if (!nombre_cliente || !telefono || !items || !items.length) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }

    let montoTotal = 0;
    const codigo = generarCodigoPedido();
    const pedido = await Pedido.create({
      codigo,
      nombre_cliente,
      telefono,
      direccion: direccion || null,
      tipo_entrega,
      estado: 'pendiente',
      comentarios: comentarios || null,
      venta_realizada: false
    }, { transaction });

    const detallesPromises = items.map(async item => {
      let producto = await db.Producto.findByPk(item.producto_id);
      if (!producto) {
        const productosSibl = await db.Producto.findAll({
          where: { codigo_barras: String(item.producto_id) }
        });
        if (productosSibl.length > 0) {
          producto = productosSibl.find(p => p.stock >= item.cantidad) || productosSibl[0];
        }
      }
      if (!producto) {
        throw new Error(`Producto con id/código ${item.producto_id} no encontrado`);
      }
      const subtotal = producto.precio_venta * item.cantidad;
      montoTotal += subtotal;
      return DetallePedido.create({
        pedido_id: pedido.id,
        producto_id: producto.id,
        cantidad: item.cantidad,
        precio_unitario: producto.precio_venta,
        subtotal: subtotal
      }, { transaction });
    });

    await Promise.all(detallesPromises);
    await pedido.update({ monto_total: montoTotal }, { transaction });
    await transaction.commit();

    res.status(201).json({
      mensaje: 'Pedido creado exitosamente',
      codigo: pedido.codigo,
      id: pedido.id
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Error al crear pedido:', error);
    res.status(500).json({ error: error.message });
  }
};

exports.obtenerPedidos = async (req, res) => {
  try {
    const pedidos = await Pedido.findAll({
      include: [{
        model: DetallePedido,
        as: 'detalles',
        include: [{
          model: Producto,
          as: 'producto',
          attributes: ['id', 'nombre', 'imagen', 'precio_venta']
        }]
      }],
      order: [['createdAt', 'DESC']]
    });

    const pedidosFormateados = pedidos.map(pedido => {
      const pedidoJSON = pedido.toJSON();
      pedidoJSON.detalles = pedidoJSON.detalles.map(detalle => ({
        ...detalle,
        nombre_producto: detalle.producto.nombre,
        imagen_producto: detalle.producto.imagen
      }));
      return pedidoJSON;
    });

    res.status(200).json(pedidosFormateados);
  } catch (error) {
    console.error('Error al obtener pedidos:', error);
    res.status(500).json({ error: 'Error al obtener los pedidos' });
  }
};

exports.obtenerPedidoPorId = async (req, res) => {
  try {
    const { id } = req.params;
    const pedido = await Pedido.findByPk(id, {
      include: [{
        model: DetallePedido,
        as: 'detalles',
        include: [{
          model: Producto,
          as: 'producto',
          attributes: ['id', 'nombre', 'imagen', 'stock']
        }]
      }]
    });
    if (!pedido) {
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }
    res.status(200).json(pedido);
  } catch (error) {
    console.error('Error al obtener pedido por ID:', error);
    res.status(500).json({
      error: 'Error al obtener el pedido',
      detalle: error.message
    });
  }
};

exports.actualizarEstadoPedido = async (req, res) => {
  const transaction = await db.sequelize.transaction();
  try {
    const { id } = req.params;
    const { estado, motivo_rechazo, id_sucursal } = req.body;

    if (!['pendiente', 'aprobado', 'rechazado', 'cancelado', 'pago_pendiente', 'pagado'].includes(estado)) {
      return res.status(400).json({ error: 'Estado no válido' });
    }

    const pedido = await Pedido.findByPk(id, {
      include: [{ model: Sucursal, as: 'sucursal' }],
      transaction
    });

    if (!pedido) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    pedido.estado = estado;
    pedido.id_sucursal = id_sucursal;

    if (estado === 'rechazado' && motivo_rechazo) {
      pedido.motivo_rechazo = motivo_rechazo;
    }

    await pedido.save({ transaction });
    await transaction.commit();

    res.status(200).json({
      mensaje: `Pedido ${estado} exitosamente`,
      pedido
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Error al actualizar estado del pedido:', error);
    res.status(500).json({ error: error.message });
  }
};

// Núcleo reutilizable: crea Venta + DetalleVenta, descuenta stock, suma a caja
// y marca el pedido como hecho. Lanza Error si algo falla (el llamador maneja la transacción).
async function crearVentaDePedido(pedido, { id_usuario, id_sucursal }, transaction) {
  const cajaAbierta = await db.Caja.findOne({
    where: { id_sucursal, estado: 'abierta' },
    order: [['createdAt', 'DESC']],
    transaction
  });
  if (!cajaAbierta) {
    throw new Error('No hay una caja abierta para esta sucursal.');
  }
  if (pedido.venta_realizada) {
    throw new Error('La venta ya fue realizada para este pedido');
  }
  const venta = await db.Venta.create({
    id_usuario,
    id_sucursal,
    tipo_pago: 'qr',
    monto_total: pedido.monto_total,
    fecha: new Date()
  }, { transaction });

  for (const detalle of pedido.detalles) {
    await db.DetalleVenta.create({
      id_venta: venta.id,
      id_producto: detalle.producto_id,
      cantidad: detalle.cantidad,
      precio_unitario: detalle.precio_unitario,
      subtotal: detalle.subtotal
    }, { transaction });

    const producto = await Producto.findByPk(detalle.producto_id, { transaction });
    if (!producto) {
      throw new Error(`Producto con ID ${detalle.producto_id} no encontrado`);
    }
    producto.stock -= detalle.cantidad;
    await producto.save({ transaction });
  }

  cajaAbierta.ingresos = parseFloat(cajaAbierta.ingresos) + parseFloat(pedido.monto_total);
  cajaAbierta.saldo_final = (
    parseFloat(cajaAbierta.saldo_inicial) +
    parseFloat(cajaAbierta.ingresos) -
    parseFloat(cajaAbierta.egresos)
  ).toFixed(2);
  await cajaAbierta.save({ transaction });

  pedido.venta_realizada = true;
  pedido.estado = 'hecho';
  await pedido.save({ transaction });
  return venta;
}

async function cargarPedidoConDetalles(id_pedido, transaction) {
  const pedido = await Pedido.findByPk(id_pedido, {
    include: [{
      model: DetallePedido,
      as: 'detalles',
      include: [{ model: Producto, as: 'producto' }]
    }],
    transaction
  });
  return pedido;
}

exports.realizarVenta = async (req, res) => {
  const transaction = await db.sequelize.transaction();
  try {
    const { id_pedido, id_usuario, id_sucursal } = req.body;

    if (!id_pedido || !id_usuario || !id_sucursal) {
      await transaction.rollback();
      return res.status(400).json({
        error: 'Faltan datos necesarios para realizar la venta. Se requiere id_pedido, id_usuario y id_sucursal.'
      });
    }

    const pedido = await cargarPedidoConDetalles(id_pedido, transaction);
    if (!pedido) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    if (pedido.estado !== 'aprobado') {
      await transaction.rollback();
      return res.status(400).json({ error: 'El pedido debe estar aprobado para realizar la venta' });
    }

    const venta = await crearVentaDePedido(pedido, { id_usuario, id_sucursal }, transaction);
    await transaction.commit();

    res.status(200).json({
      mensaje: 'Venta realizada exitosamente',
      venta
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Error al realizar venta:', error);
    res.status(500).json({ error: error.message });
  }
};

// POST /api/pedidos/:id/aprobar-enviar-qr (auth).
// Aprueba el pedido, fija vencimiento de pago y envía por WhatsApp
// la imagen del QR fijo del negocio + monto + plazo.
exports.aprobarEnviarQr = async (req, res) => {
  try {
    const { id } = req.params;
    const { id_sucursal } = req.body;
    const pedido = await cargarPedidoConDetalles(id, null);
    if (!pedido) return res.status(404).json({ error: 'Pedido no encontrado' });
    if (pedido.estado !== 'pendiente') {
      return res.status(400).json({ error: `Solo se puede aprobar un pedido pendiente (actual: ${pedido.estado})` });
    }
    const minutos = parseInt(process.env.PEDIDO_EXPIRY_MINUTES || '60', 10);
    pedido.estado = 'aprobado';
    if (id_sucursal) pedido.id_sucursal = id_sucursal;
    pedido.expira_en = new Date(Date.now() + minutos * 60 * 1000);
    await pedido.save();

    const wa = require('./whatsappController');
    const qr = wa.rutaQrNegocio();
    if (!qr) {
      return res.status(200).json({
        mensaje: 'Pedido aprobado. QR no enviado: sube el QR del negocio desde la app o define NEGOCIO_QR_IMAGE_URL en el .env',
        pedido
      });
    }
    const caption =
      `¡Pedido ${pedido.codigo} aprobado!\n` +
      `Total a pagar: Bs. ${pedido.monto_total}\n` +
      `Escanea el QR para pagar. Tienes ${minutos} minutos; si no se confirma el pago, el pedido se cancela.\n` +
      `Cuando pagues, responde "pagado" o envíanos la foto del comprobante.`;
    try {
      await wa.enviarImagen(pedido.telefono, qr, caption);
    } catch (werr) {
      console.error('[pedido] QR no enviado por WhatsApp:', werr.message);
      return res.status(200).json({
        mensaje: 'Pedido aprobado, pero el QR no se pudo enviar por WhatsApp',
        detalle: werr.message,
        pedido
      });
    }
    return res.status(200).json({ mensaje: 'Pedido aprobado y QR enviado por WhatsApp', pedido });
  } catch (error) {
    console.error('Error al aprobar y enviar QR:', error);
    return res.status(500).json({ error: error.message });
  }
};

// POST /api/pedidos/:id/confirmar-pago (auth). Body: { id_usuario, id_sucursal }.
// El operador confirma que el pago llegó: crea la venta, genera el ticket PDF
// con el código de recojo y lo envía por WhatsApp.
exports.confirmarPago = async (req, res) => {
  const transaction = await db.sequelize.transaction();
  try {
    const { id } = req.params;
    const { id_usuario, id_sucursal } = req.body;
    if (!id_usuario || !id_sucursal) {
      await transaction.rollback();
      return res.status(400).json({ error: 'Se requiere id_usuario e id_sucursal' });
    }
    const pedido = await cargarPedidoConDetalles(id, transaction);
    if (!pedido) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }
    if (!['pago_pendiente', 'aprobado'].includes(pedido.estado)) {
      await transaction.rollback();
      return res.status(400).json({ error: `El pedido debe estar en pago_pendiente o aprobado (actual: ${pedido.estado})` });
    }
    pedido.estado = 'pagado';
    await pedido.save({ transaction });
    const venta = await crearVentaDePedido(pedido, { id_usuario, id_sucursal }, transaction);
    await transaction.commit();

    // Ticket PDF + envío (si algo falla aquí, la venta ya quedó registrada)
    let ticketUrl = null;
    try {
      const { generarTicketPdf } = require('../servicios/ticketService');
      if (!pedido.codigo_recojo) {
        pedido.codigo_recojo = pedido.codigo;
        await pedido.save();
      }
      ticketUrl = await generarTicketPdf(pedido);
      const wa = require('./whatsappController');
      await wa.enviarDocumento(
        pedido.telefono, ticketUrl,
        `ticket-${pedido.codigo}.pdf`,
        `¡Pago confirmado! Tu código de recojo es *${pedido.codigo_recojo}*. Preséntalo para recoger tu pedido.`
      );
    } catch (werr) {
      console.error('[pedido] ticket no enviado por WhatsApp:', werr.message);
    }
    return res.status(200).json({
      mensaje: 'Pago confirmado. Venta registrada y ticket enviado.',
      pedido, venta, ticket: ticketUrl
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Error al confirmar pago:', error);
    return res.status(500).json({ error: error.message });
  }
};

// Expirador: cancela pedidos vencidos sin pago y avisa al cliente.
// Lo llama server.js cada 5 minutos. Sin req/res.
exports.expirarPedidosVencidos = async () => {
  try {
    const vencidos = await Pedido.findAll({
      where: {
        estado: ['aprobado', 'pago_pendiente'],
        expira_en: { [Op.lt]: new Date() },
      },
    });
    let cancelados = 0;
    const wa = require('./whatsappController');
    for (const p of vencidos) {
      p.estado = 'cancelado';
      p.motivo_rechazo = 'Pago no confirmado dentro del plazo (60 min)';
      await p.save();
      cancelados++;
      try {
        await wa.enviarTexto(p.telefono,
          `Tu pedido ${p.codigo} fue cancelado porque no se confirmó el pago a tiempo. Puedes hacer un nuevo pedido cuando quieras.`);
      } catch (werr) {
        console.error('[pedido] aviso de cancelación no enviado:', werr.message);
      }
    }
    if (cancelados) console.log(`[pedido] ${cancelados} pedido(s) vencidos cancelados`);
    return cancelados;
  } catch (error) {
    console.error('[pedido] error en expirador:', error.message);
    return 0;
  }
};
