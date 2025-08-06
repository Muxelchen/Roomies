#!/usr/bin/env node

const http = require('http');

console.log('🚀 Simple Roomies Backend Test\n');

function testEndpoint(path, expectedStatus, description) {
  return new Promise((resolve) => {
    const req = http.request({
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: 'GET'
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const success = res.statusCode === expectedStatus;
        console.log(`${success ? '✅' : '❌'} ${description}: ${res.statusCode} (expected ${expectedStatus})`);
        if (success && data) {
          try {
            const json = JSON.parse(data);
            console.log(`   Response: ${JSON.stringify(json).substring(0, 100)}...`);
          } catch (e) {
            console.log(`   Response: ${data.substring(0, 50)}...`);
          }
        }
        resolve(success);
      });
    });

    req.on('error', (err) => {
      console.log(`❌ ${description}: Connection failed - ${err.message}`);
      resolve(false);
    });

    req.end();
  });
}

async function runTests() {
  console.log('Testing basic connectivity...\n');

  const results = [
    await testEndpoint('/health', 200, 'Health Check'),
    await testEndpoint('/api/auth/register', 400, 'Auth Registration (no body - expect 400)'),
    await testEndpoint('/api/users/profile', 401, 'Protected Route (no auth - expect 401)')
  ];

  const passed = results.filter(r => r).length;
  console.log(`\n📊 Results: ${passed}/${results.length} tests passed`);

  if (passed === results.length) {
    console.log('🎉 Backend is responding correctly!');
    return true;
  } else {
    console.log('⚠️  Some endpoints may need attention.');
    return false;
  }
}

// Wait a moment and run tests
setTimeout(() => {
  runTests().then((success) => {
    if (success) {
      console.log('\n✅ Your Roomies backend is working!');
      console.log('🔗 You can now connect your iOS app to http://localhost:3000');
    } else {
      console.log('\n❌ Backend may need some fixes.');
    }
  });
}, 2000);
