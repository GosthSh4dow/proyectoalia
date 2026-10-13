const express = require('express');
const router = express.Router();
const catalogoFeedController = require('../controllers/catalogoFeedController');

// Feed público para Commerce Manager (Meta lo descarga por horario con la URL).
router.get('/feed', catalogoFeedController.feedCsv);

module.exports = router;
