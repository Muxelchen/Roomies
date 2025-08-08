module.exports = {
  apps: [
    {
      name: 'roomies-backend',
      script: './dist/server.js',
      instances: 'max', // Use all available CPU cores
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      error_file: '/opt/roomies/logs/err.log',
      out_file: '/opt/roomies/logs/out.log',
      log_file: '/opt/roomies/logs/combined.log',
      time: true,
      merge_logs: true,
      max_memory_restart: '1G',
      autorestart: true,
      watch: false,
      max_restarts: 10,
      min_uptime: '10s',
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001
      }
    }
  ]
};
