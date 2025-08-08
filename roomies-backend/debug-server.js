// Minimal server test to debug startup issues
const express = require('express');

console.log('Starting minimal server test...');

const app = express();
const port = 3002;

// Basic middleware
app.use(express.json());

// Simple route
app.get('/test', (req, res) => {
  res.json({ status: 'working', timestamp: new Date().toISOString() });
});

app.get('/api/auth/health', (req, res) => {
  res.json({ success: true, data: { status: 'healthy' }, message: 'API is working' });
});

app.listen(port, () => {
  console.log(`✅ Minimal server running on http://localhost:${port}`);
  console.log('Testing /test and /api/auth/health endpoints');
});
