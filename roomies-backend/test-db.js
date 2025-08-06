#!/usr/bin/env node

// Simple test to debug database connection and table creation
const { execSync } = require('child_process');
const path = require('path');

console.log('🔍 Testing TypeORM Database Connection...\n');

try {
  // Run a simple TypeORM command to test connection
  console.log('1️⃣  Testing TypeORM connection...');
  
  const result = execSync('npx ts-node -r tsconfig-paths/register -e "import { AppDataSource } from \'./src/config/database\'; AppDataSource.initialize().then(async () => { console.log(\'Connected!\'); console.log(\'Entity metadata:\', AppDataSource.entityMetadatas.map(m => m.name)); await AppDataSource.synchronize(); console.log(\'Tables synchronized!\'); await AppDataSource.destroy(); });"', {
    encoding: 'utf8',
    cwd: __dirname
  });
  
  console.log(result);
  
} catch (error) {
  console.error('❌ TypeORM test failed:');
  console.error(error.message);
  console.error('\nStderr:', error.stderr);
}
