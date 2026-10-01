const { spawn } = require('child_process');
const readline = require('readline');
const path = require('path');

console.log('🚀 Đang khởi động AloT Server & Cloudflare Tunnel...');

// 1. Chạy Backend Server
const serverProcess = spawn('node', ['server.js'], {
  cwd: __dirname,
  stdio: 'inherit',
  shell: true
});

// 2. Chạy Cloudflare Tunnel
setTimeout(() => {
  console.log('\n🌐 Đang mở đường truyền Cloudflare Tunnel...');
  const tunnelProcess = spawn('cloudflared', ['tunnel', '--url', 'http://localhost:3000'], {
    cwd: __dirname,
    shell: true
  });

  const rl = readline.createInterface({
    input: tunnelProcess.stderr,
    terminal: false
  });

  rl.on('line', (line) => {
    if (line.includes('trycloudflare.com')) {
      const match = line.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
      if (match) {
        const tunnelUrl = match[0];
        const wsUrl = tunnelUrl.replace('https://', 'wss://') + '/mqtt';
        console.log('\n================================================================');
        console.log('🎉 CLOUDFLARE TUNNEL THÀNH CÔNG!');
        console.log(`🌐 Public API URL:  ${tunnelUrl}/api`);
        console.log(`⚡ Public MQTT WSS: ${wsUrl}`);
        console.log('================================================================\n');
      }
    }
  });

  tunnelProcess.on('close', (code) => {
    console.log(`⚠️ Cloudflare Tunnel đã ngắt (code: ${code})`);
  });
}, 2000);

process.on('SIGINT', () => {
  console.log('👋 Đang dừng hệ thống...');
  process.exit();
});
