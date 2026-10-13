const db = require('../models');
const { Op } = require('sequelize');

// GET /api/catalogo/feed — feed CSV para Commerce Manager (catálogo oficial de Meta).
// retailer_id = id interno de Producto: así los pedidos "order" de WhatsApp
// se enlazan directo al backend. Solo productos con stock > 0.
// Formato: id,title,description,availability,condition,price,link,image_link
exports.feedCsv = async (req, res) => {
  try {
    const base = (process.env.PUBLIC_BASE_URL || '').replace(/\/$/, '');
    const productos = await db.Producto.findAll({
      where: { stock: { [Op.gt]: 0 } },
      attributes: ['id', 'nombre', 'descripcion', 'precio_venta', 'imagen', 'stock'],
      order: [['id', 'ASC']],
      limit: 5000,
    });
    const esc = (v) => `"${String(v == null ? '' : v).replace(/"/g, '""')}"`;
    const filas = ['id,title,description,availability,condition,price,link,image_link'];
    for (const p of productos) {
      const disp = p.stock > 0 ? 'in stock' : 'out of stock';
      const precio = `${Number(p.precio_venta).toFixed(2)} BOB`;
      let img = '';
      if (p.imagen) {
        img = /^https?:\/\//i.test(p.imagen) ? p.imagen : (base ? base + '/' + String(p.imagen).replace(/\\/g, '/').replace(/^\/+/, '') : '');
      }
      filas.push([p.id, esc(p.nombre), esc(p.descripcion), disp, 'new', precio, '', img].join(','));
    }
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.status(200).send('\ufeff' + filas.join('\n'));
  } catch (error) {
    console.error('Error en feed del catálogo:', error.message);
    res.status(500).json({ error: 'No se pudo generar el feed' });
  }
};
