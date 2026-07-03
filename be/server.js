const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 5000;

app.get('/api/hello', (req, res) => {
  res.json({
    message: 'Hello from the backend!',
    timestamp: new Date().toISOString(),
    servedBy: os.hostname()
  });
});

// Used by docker healthcheck
app.get('/health', (req, res) => res.status(200).send('OK'));

app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT}`);
});
