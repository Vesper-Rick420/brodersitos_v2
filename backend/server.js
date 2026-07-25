const express = require("express");
const os = require("os");

const app = express();
const PORT = 3000;

// Cada réplica reporta su propio hostname (= container ID de Docker).
// Al hacer varias llamadas seguidas contra nginx, el hostname debe ir
// cambiando entre las 3 réplicas: esa es la evidencia de balanceo.
app.get("/", (req, res) => {
  res.json({
    message: "Hello from FinFlow backend",
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get("/health", (req, res) => {
  res.status(200).send("ok");
});

app.listen(PORT, () => {
  console.log(`FinFlow backend listening on port ${PORT} (host: ${os.hostname()})`);
});
