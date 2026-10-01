const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth.routes');
const nodeRoutes = require('./routes/node.routes');
const brokerService = require('./services/broker.service');
const mqttService = require('./services/mqtt.service');
const XiaoZhiService = require('./services/xiaozhi.service');

const app = express();
const server = http.createServer(app);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 1. Khởi chạy Broker MQTT & WebSockets nội bộ
const MQTT_TCP_PORT = process.env.MQTT_TCP_PORT || 1883;
const MQTT_WS_PORT = process.env.MQTT_WS_PORT || 8083;
brokerService.start(MQTT_TCP_PORT, MQTT_WS_PORT);
brokerService.attachToExpress(server);

// 2. Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/alot_db')
  .then(() => {
    console.log('✅ Kết nối MongoDB thành công!');
    
    // Khởi tạo MQTT Backend Client sau khi broker sẵn sàng
    setTimeout(() => {
      mqttService.connect();
      XiaoZhiService.connect();
    }, 1000);
  })
  .catch((err) => {
    console.error('❌ Lỗi kết nối MongoDB:', err.message);
  });

// 3. API Routes
app.use('/api/auth', authRoutes);
app.use('/api/nodes', nodeRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({
    message: '🏠 AloT Smart Home API & MQTT Broker đang chạy!',
    version: '2.0.0',
    services: {
      api: `http://localhost:${process.env.PORT || 3000}/api`,
      mqtt_tcp: `mqtt://localhost:${MQTT_TCP_PORT}`,
      mqtt_ws: `ws://localhost:${MQTT_WS_PORT}`,
      mqtt_ws_express: `ws://localhost:${process.env.PORT || 3000}/mqtt`
    },
    endpoints: {
      auth: {
        register: 'POST /api/auth/register',
        login: 'POST /api/auth/login',
        resetPassword: 'POST /api/auth/reset-password',
        profile: 'GET /api/auth/profile (Bearer token)'
      }
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Endpoint không tồn tại' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Lỗi server nội bộ' });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`🚀 AloT Localhost Server đang chạy tại port: ${PORT}`);
  console.log(`🌐 Domain Public API:  https://duynguyen.io.vn/api`);
  console.log(`⚡ Domain Public MQTT: wss://mqtt.duynguyen.io.vn`);
  console.log(`📡 Localhost MQTT TCP: 1883`);
  console.log(`====================================================`);
});
