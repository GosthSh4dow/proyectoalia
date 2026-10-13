const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

// Genera el ticket PDF de recojo de un pedido pagado.
// Guarda en uploads/tickets/ticket-<CODIGO>.pdf y devuelve la ruta pública (/uploads/...).
// El pedido debe venir con detalles + producto (ver pedidoController.cargarPedidoConDetalles).
async function generarTicketPdf(pedido) {
  const dir = path.join(__dirname, '..', 'uploads', 'tickets');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const nombre = `ticket-${pedido.codigo}.pdf`;
  const destino = path.join(dir, nombre);

  await new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A5', margin: 36 });
    const w = fs.createWriteStream(destino);
    doc.pipe(w);

    doc.fontSize(18).text('TICKET DE RECOJO', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(26).text(String(pedido.codigo_recojo || pedido.codigo), { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(11).text(`Pedido: ${pedido.codigo}`);
    doc.text(`Cliente: ${pedido.nombre_cliente || '-'}`);
    doc.text(`Teléfono: ${pedido.telefono || '-'}`);
    doc.text(`Fecha: ${new Date().toLocaleString('es-BO')}`);
    doc.moveDown(0.5);
    doc.text('----------------------------------------');
    let total = 0;
    for (const d of pedido.detalles || []) {
      const nombreProd = (d.producto && d.producto.nombre) || d.nombre_producto || `ID ${d.producto_id}`;
      const cant = Number(d.cantidad);
      const sub = Number(d.subtotal);
      total += sub;
      doc.text(`${cant} x ${nombreProd}`);
      doc.text(`Bs. ${sub.toFixed(2)}`, { align: 'right' });
    }
    doc.text('----------------------------------------');
    doc.fontSize(14).text(`TOTAL: Bs. ${Number(pedido.monto_total || total).toFixed(2)}`, { align: 'right' });
    doc.moveDown(0.5);
    doc.fontSize(11).text('Presenta este código para recoger tu pedido. ¡Gracias por tu compra!', { align: 'center' });
    doc.end();
    w.on('finish', resolve);
    w.on('error', reject);
  });

  return '/uploads/tickets/' + nombre;
}

module.exports = { generarTicketPdf };
