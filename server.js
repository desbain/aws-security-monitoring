// ##############################################
// Portfolio API — connects webpage to PostgreSQL
// ##############################################

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ─────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Database Connection ────────────────────────
const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl:      { rejectUnauthorized: false }
});

// Test database connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Database connection error:', err.message);
  } else {
    console.log('✅ Connected to PostgreSQL RDS');
    release();
  }
});

// ── Routes ─────────────────────────────────────

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});

// Serve portfolio homepage
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html>
<head>
  <title>George Awa — DevSecOps Engineer</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
    .badge { background: #28a745; color: white; padding: 5px 10px; border-radius: 4px; }
  </style>
</head>
<body>
  <h1>George Awa</h1>
  <p><span class="badge">DevSecOps Engineer</span></p>
  <h2>AWS Portfolio Project</h2>
  <p>Production-grade cloud infrastructure built on AWS</p>
  <ul>
    <li>✅ VPC + Networking</li>
    <li>✅ Auto Scaling Group</li>
    <li>✅ RDS PostgreSQL</li>
    <li>✅ GuardDuty Security Monitoring</li>
    <li>✅ Terraform IaC</li>
    <li>✅ GitHub Actions CI/CD</li>
  </ul>
  <p><a href="/health">Health Check</a> | <a href="/api/visitors/count">Visitor Count</a></p>
</body>
</html>
  `);
});

// GET all projects
app.get('/api/projects', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM projects ORDER BY project_num'
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
});

// GET visitor count
app.get('/api/visitors/count', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT COUNT(*) as count FROM visitors'
    );
    res.json({ count: parseInt(result.rows[0].count) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch visitor count' });
  }
});

// POST record new visitor
app.post('/api/visitors', async (req, res) => {
  try {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    await pool.query(
      'INSERT INTO visitors (ip_address, user_agent) VALUES ($1, $2)',
      [ip, userAgent]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to record visitor' });
  }
});

// POST contact form
app.post('/api/contact', async (req, res) => {
  try {
    const { name, email, message } = req.body;
    if (!name || !email || !message) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    await pool.query(
      'INSERT INTO contacts (name, email, message) VALUES ($1, $2, $3)',
      [name, email, message]
    );
    res.json({ success: true, message: 'Message received!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to save contact' });
  }
});

// GET all contacts (admin)
app.get('/api/contacts', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM contacts ORDER BY submitted_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch contacts' });
  }
});

// ── Start Server ───────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 Portfolio API running on port ${PORT}`);
});
