const express = require('express');
const router = express.Router();
const DescripcionController = require('../controllers/DescripcionController');

router.post('/', DescripcionController.generarDescripcion);

module.exports = router;
