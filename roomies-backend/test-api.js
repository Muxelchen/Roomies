#!/usr/bin/env node

const http = require('http');

// Test API endpoints
const tests = [
  { name: 'Health Check', path: '/health', expectedStatus: 200 },
  { name: 'Auth Routes', path: '/api/auth/register', method: 'POST', expectedStatus: 400 },
  { name: 'User Routes', path: '/api/users/profile', expectedStatus: 401 },
  { name: 'Household Routes', path: '/api/households', expectedStatus: 401 },
];

console.log('🧪 Testing Roomies API Endpoints...\n');

function makeRequest(test) {
  return new Promise((resolve) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: test.path,
      method: test.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        const success = res.statusCode === test.expectedStatus;
        console.log(`${success ? '✅' : '❌'} ${test.name}: ${res.statusCode} (expected ${test.expectedStatus})`);
        if (!success) {
          console.log(`   Response: ${data.substring(0, 100)}...`);
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
    await new Promise(resolve => setTimeout(resolve, 500)); // Small delay between tests
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

// Check if server is running
const healthCheck = http.request({
  hostname: 'localhost',
  port: 3000,
  path: '/health',
  method: 'GET'
}, (res) => {
  console.log('🚀 Server is running, starting tests...\n');
  runTests();
});

healthCheck.on('error', () => {
  console.log('❌ Server is not running on port 3000');
  console.log('💡 Start the server with: npm run dev');
});

healthCheck.end();
