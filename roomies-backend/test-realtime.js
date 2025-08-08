#!/usr/bin/env node
// Real-time E2E quick test: registers/logs in, opens SSE and Socket.IO, creates a task, verifies events
const http = require('http');
const https = require('https');
const io = require('socket.io-client');

const API = process.env.API_URL || 'http://localhost:3000/api';
const BASE = API.replace(/\/api$/, '');

function request(method, path, body, token) {
  const url = new URL(path.startsWith('http') ? path : `${API}${path}`);
  const mod = url.protocol === 'https:' ? https : http;
  const payload = body ? JSON.stringify(body) : null;
  const opts = {
    method,
    hostname: url.hostname,
    port: url.port || (url.protocol === 'https:' ? 443 : 80),
    path: url.pathname + (url.search || ''),
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': payload ? Buffer.byteLength(payload) : 0,
    },
  };
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  return new Promise((resolve, reject) => {
    const req = mod.request(opts, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: data ? JSON.parse(data) : {} });
        } catch (e) {
          resolve({ status: res.statusCode, text: data });
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function main() {
  console.log('🔧 Real-time E2E Test starting...');
  // 1) Register or login
  const email = `rt_${Date.now()}@roomies.test`;
  const password = 'Testpass1';
  const name = 'RT User';

  const reg = await request('POST', '/auth/register', { email, password, name });
  let token;
  if (reg.status === 201 && reg.json?.data?.token) {
    token = reg.json.data.token;
    console.log('✅ Registered new test user');
  } else {
    const login = await request('POST', '/auth/login', { email, password });
    if (login.status === 200 && login.json?.data?.token) {
      token = login.json.data.token;
      console.log('ℹ️  Logged in existing user');
    } else {
      throw new Error('Failed to get JWT');
    }
  }

  // 2) Create a household
  const hh = await request('POST', '/households', { name: `RT HH ${Date.now()}` }, token);
  if (hh.status !== 201) throw new Error('Household creation failed');
  const householdId = hh.json?.data?.id;
  console.log('✅ Household created:', householdId);

  // 3) Open SSE stream
  const sseUrl = `${BASE}/api/events/household/${householdId}`;
  const sseModule = sseUrl.startsWith('https') ? https : http;
  let sseEventCount = 0;
  let sseBuffer = '';
  const sseReq = sseModule.request(sseUrl, {
    method: 'GET',
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${token}`,
    },
  });
  sseReq.on('response', (res) => {
    res.on('data', (chunk) => {
      sseBuffer += chunk.toString('utf8');
      let idx;
      while ((idx = sseBuffer.indexOf('\n\n')) >= 0) {
        const block = sseBuffer.slice(0, idx);
        sseBuffer = sseBuffer.slice(idx + 2);
        if (block.includes('event:') && block.includes('data:')) {
          sseEventCount++;
          // console.log('SSE block:', block);
        }
      }
    });
  });
  sseReq.end();
  console.log('🔗 SSE connected');

  // 4) Connect Socket.IO and join household
  const socket = io(BASE, { transports: ['websocket'], auth: { token } });
  await new Promise((resolve, reject) => {
    const to = setTimeout(() => reject(new Error('Socket connect timeout')), 5000);
    socket.on('connect', () => {
      clearTimeout(to);
      resolve(null);
    });
    socket.on('connect_error', reject);
  });
  socket.emit('join-household', householdId);
  console.log('🔗 Socket.IO connected and joined room');

  // Listen for task events
  let receivedSocketTaskCreated = false;
  socket.on('task_created', () => {
    receivedSocketTaskCreated = true;
  });

  // Small delay to allow initial SSE hello
  await new Promise((r) => setTimeout(r, 500));

  // 5) Create a task → should broadcast to both channels
  const taskRes = await request('POST', '/tasks', {
    title: 'RT Test Task',
    description: 'sync check',
    priority: 'medium',
    points: 5,
    householdId,
  }, token);
  if (taskRes.status !== 201) throw new Error('Task create failed');
  console.log('📝 Task created');

  // 6) Wait briefly for events to arrive
  await new Promise((r) => setTimeout(r, 1500));

  console.log('📡 Results: ', { sseEventCount, receivedSocketTaskCreated });
  if (!receivedSocketTaskCreated) throw new Error('Socket task_created not received');
  if (sseEventCount === 0) throw new Error('No SSE events received');

  console.log('🎉 Real-time E2E Test PASSED');
  socket.close();
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Real-time E2E Test FAILED:', e.message);
  process.exit(1);
});


