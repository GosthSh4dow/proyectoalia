const axios = require('axios');
const fs = require('fs');
const path = require('path');
const db = require('../models');

const API_VERSION = process.env.WHATSAPP_API_VERSION || 'v21.0';
const PHONE_NUMBER_ID = () => process.env.WHATSAPP_PHONE_NUMBER_ID;
const ACCESS_TOKEN = () => process.env.WHATSAPP_ACCESS_TOKEN;
const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN;
const PUBLIC_BASE_URL = () => (process.env.PUBLIC_BASE_URL || '').replace(/\/$/, '');

function graphUrl() {
  return `https://graph.facebook.com/${API_VERSION}/${PHONE_NUMBER_ID()}/messages`;
}

function exigirConfig() {
  if (!PHONE_NUMBER_ID() || !ACCESS_TOKEN()) {
    throw new Error('WhatsApp no configurado. Define WHATSAPP_PHONE_NUMBER_ID y WHATSAPP_ACCESS_TOKEN en el .env');
  }
}

// Convierte ruta /uploads/... a URL pública. Las URL absolutas se devuelven igual.
function aUrlPublica(ruta) {
  if (!ruta) return null;
  if (/^https?:\/\//i.test(ruta)) return ruta;
  const base = PUBLIC_BASE_URL();
  if (!base) return null;
  const limpia = '/' + String(ruta).replace(/\\/g, '/').replace(/^\/+/, '');
  return base + limpia;
}

async function postGraph(payload) {
  exigirConfig();
  const response = await axios.post(graphUrl(), { messaging_product: 'whatsapp', ...payload }, {
    headers: { Authorization: `Bearer ${ACCESS_TOKEN()}`, 'Content-Type': 'application/json' },
    timeout: 15000,
  });
  const msgs = response.data && response.data.messages;
  return msgs && msgs[0] ? msgs[0].id : null;
}

// ---- Envíos de bajo nivel (usables desde otros controllers, sin req/res) ----
async function enviarTexto(para, mensaje) {
  return postGraph({ to: depurarTelefono(para), type: 'text', text: { body: String(mensaje) } });
}

async function enviarImagen(para, imagenUrl, caption) {
  const link = aUrlPublica(imagenUrl);
  if (!link) throw new Error('Sin URL pública para la imagen. Define PUBLIC_BASE_URL o usa URL absoluta.');
  const image = { link };
  if (caption) image.caption = String(caption).slice(0, 1024);
  return postGraph({ to: depurarTelefono(para), type: 'image', image });
}

async function enviarDocumento(para, docUrl, filename, caption) {
  const link = aUrlPublica(docUrl);
  if (!link) throw new Error('Sin URL pública para el documento. Define PUBLIC_BASE_URL.');
  const document = { link, filename: filename || 'documento.pdf' };
  if (caption) document.caption = String(caption).slice(0, 1024);
  return postGraph({ to: depurarTelefono(para), type: 'document', document });
}

function depurarTelefono(para) {
  return String(para || '').replace(/\D/g, '');
}

// QR fijo del negocio: vale NEGOCIO_QR_IMAGE_URL (.env) o el archivo
// subido a uploads/qr/negocio-qr.* (se puede cambiar desde la APK).
function rutaQrNegocio() {
  if (process.env.NEGOCIO_QR_IMAGE_URL) return process.env.NEGOCIO_QR_IMAGE_URL;
  const dir = path.join(__dirname, '..', 'uploads', 'qr');
  if (fs.existsSync(dir)) {
    const f = fs.readdirSync(dir).find((x) => /^negocio-qr\.(jpg|jpeg|png|webp)$/i.test(x));
    if (f) return '/uploads/qr/' + f;
  }
  return null;
}

// Descarga un media de Meta (foto de comprobante) a uploads/comprobantes/
async function descargarMedia(mediaId, nombreArchivo) {
  exigirConfig();
  const meta = await axios.get(`https://graph.facebook.com/${API_VERSION}/${mediaId}`, {
    headers: { Authorization: `Bearer ${ACCESS_TOKEN()}` },
    timeout: 15000,
  });
  const url = meta.data && meta.data.url;
  if (!url) throw new Error('Meta no devolvió URL del media');
  const dir = path.join(__dirname, '..', 'uploads', 'comprobantes');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const destino = path.join(dir, nombreArchivo);
  const resp = await axios.get(url, {
    headers: { Authorization: `Bearer ${ACCESS_TOKEN()}` },
    responseType: 'stream',
    timeout: 30000,
  });
  await new Promise((resolve, reject) => {
    const w = fs.createWriteStream(destino);
    resp.data.pipe(w);
    w.on('finish', resolve);
    w.on('error', reject);
  });
  return '/uploads/comprobantes/' + nombreArchivo;
}

function generarCodigoPedido() {
  const fecha = new Date();
  const year = fecha.getFullYear().toString().slice(-2);
  const month = (fecha.getMonth() + 1).toString().padStart(2, '0');
  const day = fecha.getDate().toString().padStart(2, '0');
  const randomPart = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `PED-${year}${month}${day}-${randomPart}`;
}

// Crea un Pedido desde un mensaje type:"order" de Meta.
// product_retailer_id del catálogo = id interno de Producto (ver /api/catalogo/feed).
async function crearPedidoDesdeOrden({ from, nombre, items }) {
  const { Pedido, DetallePedido, Producto } = db;
  const transaction = await db.sequelize.transaction();
  try {
    let montoTotal = 0;
    const lineas = [];
    const desconocidos = [];
    for (const it of items) {
      const prodId = parseInt(it.product_retailer_id, 10);
      const cantidad = Math.max(1, parseInt(it.quantity || '1', 10));
      const producto = Number.isFinite(prodId) ? await Producto.findByPk(prodId, { transaction }) : null;
      if (!producto) {
        desconocidos.push(it.product_retailer_id);
        continue;
      }
      const precio = parseFloat(producto.precio_venta);
      const subtotal = precio * cantidad;
      montoTotal += subtotal;
      lineas.push({ producto, cantidad, precio, subtotal });
    }
    if (!lineas.length) {
      await transaction.rollback();
      return { error: 'Ningún producto del pedido existe en el catálogo' };
    }
    const codigo = generarCodigoPedido();
    const pedido = await Pedido.create({
      codigo,
      codigo_recojo: codigo,
      nombre_cliente: nombre || 'Cliente WhatsApp',
      telefono: String(from),
      tipo_entrega: 'recojo',
      estado: 'pendiente',
      monto_total: montoTotal.toFixed(2),
      comentarios: 'Pedido desde WhatsApp (catálogo)' + (desconocidos.length ? ` | Ítems no encontrados: ${desconocidos.join(',')}` : ''),
      origen: 'whatsapp',
    }, { transaction });
    for (const l of lineas) {
      await DetallePedido.create({
        pedido_id: pedido.id,
        producto_id: l.producto.id,
        cantidad: l.cantidad,
        precio_unitario: l.precio,
        subtotal: l.subtotal,
      }, { transaction });
    }
    await transaction.commit();
    return { pedido, total: montoTotal, items: lineas.length };
  } catch (error) {
    await transaction.rollback();
    return { error: error.message };
  }
}

// Busca el pedido abierto más reciente de un teléfono (para "pagado"/comprobante)
async function pedidoAbiertoPorTelefono(telefono) {
  const { Pedido } = db;
  return Pedido.findOne({
    where: { telefono: String(telefono), estado: ['pendiente', 'aprobado', 'pago_pendiente'] },
    order: [['createdAt', 'DESC']],
  });
}

async function marcarPagoPendiente(pedido, comprobanteUrl) {
  pedido.estado = 'pago_pendiente';
  if (comprobanteUrl) pedido.comprobante_url = comprobanteUrl;
  await pedido.save();
  return pedido;
}

// GET /api/whatsapp/webhook — verificación de Meta (sin auth)
exports.verificarWebhook = (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && token === VERIFY_TOKEN && challenge) {
    return res.status(200).send(challenge);
  }
  return res.status(403).json({ error: 'Token de verificación inválido' });
};

// POST /api/whatsapp/webhook — eventos de Meta (sin auth). Siempre 200.
exports.recibirWebhook = async (req, res) => {
  try {
    const entries = (req.body && req.body.entry) || [];
    for (const e of entries) {
      for (const c of e.changes || []) {
        const value = c.value || {};
        const contacto = (value.contacts && value.contacts[0]) || {};
        const nombre = (contacto.profile && contacto.profile.name) || null;
        for (const m of value.messages || []) {
          try {
            if (m.type === 'order' && m.order) {
              const r = await crearPedidoDesdeOrden({ from: m.from, nombre, items: m.order.product_items || [] });
              if (r.error) {
                console.error('[whatsapp] pedido descartado:', r.error);
              } else {
                console.log(`[whatsapp] pedido ${r.pedido.codigo} creado (${r.items} ítems, Bs. ${r.total})`);
              }
            } else if (m.type === 'image' && m.image) {
              const pedido = await pedidoAbiertoPorTelefono(m.from);
              if (pedido) {
                const ext = (m.image.mime_type === 'image/png') ? 'png' : 'jpg';
                const ruta = await descargarMedia(m.image.id, `comp-${pedido.codigo}-${Date.now()}.${ext}`);
                await marcarPagoPendiente(pedido, ruta);
                console.log(`[whatsapp] comprobante de ${m.from} -> pedido ${pedido.codigo}`);
              }
            } else if (m.type === 'text' && m.text && /pagad/i.test(m.text.body || '')) {
              const pedido = await pedidoAbiertoPorTelefono(m.from);
              if (pedido) {
                await marcarPagoPendiente(pedido, null);
                console.log(`[whatsapp] "${m.text.body}" de ${m.from} -> pedido ${pedido.codigo} en pago_pendiente`);
              }
            } else {
              console.log(`[whatsapp] mensaje de ${m.from}: ${(m.text && m.text.body) || m.type}`);
            }
          } catch (inner) {
            console.error('[whatsapp] error con mensaje:', inner.message);
          }
        }
        for (const s of value.statuses || []) {
          console.log(`[whatsapp] estado ${s.status} mensaje ${s.id} -> ${s.recipient_id}`);
        }
      }
    }
  } catch (error) {
    console.error('[whatsapp] error al procesar webhook:', error.message);
  }
  return res.status(200).json({ status: 'ok' });
};

// POST /api/whatsapp/send — texto (requiere auth JWT). Body: { para, mensaje }
exports.enviarMensaje = async (req, res) => {
  try {
    const { para, mensaje } = req.body;
    if (!para || !mensaje) return res.status(400).json({ error: 'Faltan datos obligatorios: para, mensaje' });
    const id = await enviarTexto(para, mensaje);
    return res.status(200).json({ status: 'ok', id });
  } catch (error) {
    const detalle = error.response ? error.response.data : error.message;
    console.error('[whatsapp] error al enviar:', detalle);
    const code = /no configurado|URL pública/i.test(error.message) ? 500 : 502;
    return res.status(code).json({ error: 'No se pudo enviar el mensaje', detalle });
  }
};

// POST /api/whatsapp/send-imagen — (auth). Body: { para, imagen, caption? }
exports.enviarImagenRoute = async (req, res) => {
  try {
    const { para, imagen, caption } = req.body;
    if (!para || !imagen) return res.status(400).json({ error: 'Faltan datos obligatorios: para, imagen' });
    const id = await enviarImagen(para, imagen, caption);
    return res.status(200).json({ status: 'ok', id });
  } catch (error) {
    const detalle = error.response ? error.response.data : error.message;
    console.error('[whatsapp] error al enviar imagen:', detalle);
    const code = /no configurado|URL pública/i.test(error.message) ? 500 : 502;
    return res.status(code).json({ error: 'No se pudo enviar la imagen', detalle });
  }
};

// POST /api/whatsapp/send-documento — (auth). Body: { para, documento, filename?, caption? }
exports.enviarDocumentoRoute = async (req, res) => {
  try {
    const { para, documento, filename, caption } = req.body;
    if (!para || !documento) return res.status(400).json({ error: 'Faltan datos obligatorios: para, documento' });
    const id = await enviarDocumento(para, documento, filename, caption);
    return res.status(200).json({ status: 'ok', id });
  } catch (error) {
    const detalle = error.response ? error.response.data : error.message;
    console.error('[whatsapp] error al enviar documento:', detalle);
    const code = /no configurado|URL pública/i.test(error.message) ? 500 : 502;
    return res.status(code).json({ error: 'No se pudo enviar el documento', detalle });
  }
};

exports.enviarTexto = enviarTexto;
exports.enviarImagen = enviarImagen;
exports.enviarDocumento = enviarDocumento;
exports.crearPedidoDesdeOrden = crearPedidoDesdeOrden;
exports.pedidoAbiertoPorTelefono = pedidoAbiertoPorTelefono;
exports.rutaQrNegocio = rutaQrNegocio;

// GET /api/whatsapp/negocio-qr (auth). Devuelve el QR vigente en URL absoluta.
exports.negocioQr = (req, res) => {
  const ruta = rutaQrNegocio();
  if (!ruta) {
    return res.status(404).json({ error: 'No hay QR del negocio. Súbelo con POST /api/whatsapp/negocio-qr' });
  }
  const base = PUBLIC_BASE_URL();
  const url = /^https?:\/\//i.test(ruta) ? ruta : (base ? base + ruta : ruta);
  return res.status(200).json({ url });
};

// POST /api/whatsapp/negocio-qr (auth). Cambia el QR fijo del negocio.
// Multipart con campo "qr" (jpg/png/webp, máx 5MB). Reemplaza el anterior.
exports.subirQr = async (req, res) => {
  try {
    if (!req.files || !req.files.qr) {
      return res.status(400).json({ error: 'No se envió ningún archivo (campo "qr")' });
    }
    const archivo = req.files.qr;
    const ext = path.extname(archivo.name || '').toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].includes(ext)) {
      return res.status(400).json({ error: 'El QR debe ser imagen jpg, png o webp' });
    }
    if (archivo.size > 5 * 1024 * 1024) {
      return res.status(400).json({ error: 'La imagen supera 5MB' });
    }
    const dir = path.join(__dirname, '..', 'uploads', 'qr');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    // Limpia QR anterior para que solo exista uno vigente
    for (const f of fs.readdirSync(dir)) {
      if (/^negocio-qr\.(jpg|jpeg|png|webp)$/i.test(f)) fs.unlinkSync(path.join(dir, f));
    }
    const destino = path.join(dir, 'negocio-qr' + ext);
    await new Promise((resolve, reject) => {
      archivo.mv(destino, (err) => (err ? reject(err) : resolve()));
    });
    const ruta = '/uploads/qr/negocio-qr' + ext;
    const base = PUBLIC_BASE_URL();
    return res.status(200).json({ mensaje: 'QR del negocio actualizado', url: base ? base + ruta : ruta, ruta });
  } catch (error) {
    console.error('[whatsapp] error al subir QR:', error.message);
    return res.status(500).json({ error: 'No se pudo guardar el QR' });
  }
};
