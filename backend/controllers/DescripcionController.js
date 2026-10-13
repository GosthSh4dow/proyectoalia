const axios = require('axios');

module.exports = {
  async generarDescripcion(req, res) {
    try {
      const { nombre, precio } = req.body;

      if (!nombre || precio === undefined) {
        return res.status(400).json({ error: "Falta 'nombre' o 'precio' en el body" });
      }

      const prompt = `Descripción de producto: ${nombre}, precio $${parseFloat(precio).toFixed(2)}. Producto de Bishuteria Channels.`;

      const payload = {
        inputs: prompt,
        parameters: {
          max_new_tokens: 60,
          temperature: 0.7,
          do_sample: true
        }
      };

      const response = await axios.post(
        "https://router.huggingface.co/hf-inference/models/PlanTL-GOB-ES/gpt2-base-bne",
        payload,
        {
          headers: {
            "Authorization": `Bearer ${process.env.HF_TOKEN}`,
            "Content-Type": "application/json"
          }
        }
      );

      const descripcion = response.data?.[0]?.generated_text || "Descripción no generada.";
      res.status(200).json({ descripcion });

    } catch (error) {
      console.error("Error al generar descripción:", error.response?.data || error.message);
      res.status(500).json({ error: "Error al generar la descripción" });
    }
  },
};
