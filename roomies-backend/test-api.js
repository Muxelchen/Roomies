#!/usr/bin/env node

const http = require('http');
const https = require('https');

// Allow running against any base via env
// API_URL should include the /api suffix, e.g. http://localhost:3000/api or https://your-host/api
const API = process.env.API_URL || 'http://localhost:3000/api';
const BASE = API.replace(/\/$/, '').replace(/\/api$/, '');

// Test API endpoints
const tests = [
  { name: 'Health Check', scope: 'base', path: '/health', expectedStatus: 200 },
  { name: 'Auth Routes', scope: 'api', path: '/auth/register', method: 'POST', expectedStatus: 400 },
  { name: 'User Routes', scope: 'api', path: '/users/profile', expectedStatus: 401 },
  { name: 'Household Routes', scope: 'api', path: '/households', expectedStatus: 401 },
];

console.log('🧪 Testing Roomies API Endpoints...\n');

function makeRequest(test) {
  return new Promise((resolve) => {
    const target = test.scope === 'api' ? `${API}${test.path}` : `${BASE}${test.path}`;
    const url = new URL(target);
    const mod = url.protocol === 'https:' ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + (url.search || ''),
      method: test.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const req = mod.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        const success = res.statusCode === test.expectedStatus;
        console.log(`${success ? '✅' : '❌'} ${test.name}: ${res.statusCode} (expected ${test.expectedStatus})`);
        if (!success) {
          console.log(`   Response: ${data.substring(0, 200)}...`);
        }
        resolve({ test: test.name, success, statusCode: res.statusCode });
      });
    });

    req.on('error', (err) => {
      console.log(`❌ ${test.name}: Connection failed - ${err.message}`);
      resolve({ test: test.name, success: false, error: err.message });
    });

    if (test.method === 'POST') {
      req.write('{}');
    }
    
    req.end();
  });
}

async function runTests() {
  const results = [];
  
  for (const test of tests) {
    const result = await makeRequest(test);
    results.push(result);
    await new Promise(resolve => setTimeout(resolve, 300)); // Small delay between tests
  }
  
  console.log('\n📊 Test Summary:');
  const passed = results.filter(r => r.success).length;
  console.log(`✅ Passed: ${passed}/${results.length}`);
  
  if (passed === results.length) {
    console.log('🎉 All API endpoints are responding correctly!');
  } else {
    console.log('⚠️  Some endpoints may need attention.');
  }
}

// Check if server is running (health)
(async () => {
  const health = await makeRequest({ name: 'Health Check', scope: 'base', path: '/health', expectedStatus: 200 });
  if (health.success) {
    console.log('🚀 Server is reachable at', API, '\n');
    await runTests();
  } else {
    console.log(`❌ Server is not reachable at ${API}`);
    console.log('💡 Start the server or verify the API_URL');
  }
})();
