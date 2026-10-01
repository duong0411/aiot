const Aedes = require('aedes');
const net = require('net');
const http = require('http');
const ws = require('ws');

class BrokerService {
  constructor() {
    this.aedes = Aedes();
    this.tcpServer = null;
    this.wsServer = null;
    this.expressWss = null;
  }

  start(mqttTcpPort = 1883, mqttWsPort = 8083) {
    // 1. MQTT Over TCP (Port 1883)
    this.tcpServer = net.createServer((socket) => {
      this.aedes.handle(socket);
    });
    this.tcpServer.listen(mqttTcpPort, () => {
      console.log(`🚀 Broker MQTT (TCP) đang lắng nghe tại port: ${mqttTcpPort}`);
    });

    // 2. MQTT Over WebSockets Server (Port 8083)
    this.wsServer = http.createServer();
    const wss = new ws.Server({ server: this.wsServer });
    wss.on('connection', (conn) => {
      const stream = ws.createWebSocketStream(conn);
      this.aedes.handle(stream);
    });

    this.wsServer.listen(mqttWsPort, () => {
      console.log(`🌐 Broker MQTT (WebSocket) đang lắng nghe tại port: ${mqttWsPort}`);
    });

    // Event loggers
    this.aedes.on('client', (client) => {
      console.log(`🟢 MQTT Client kết nối: ${client ? client.id : 'unknown'}`);
    });

    this.aedes.on('clientDisconnect', (client) => {
      console.log(`🔴 MQTT Client ngắt kết nối: ${client ? client.id : 'unknown'}`);
    });

    this.aedes.on('subscribe', (subscriptions, client) => {
      if (client) {
        console.log(`📡 [${client.id}] Subscribed:`, subscriptions.map(s => s.topic).join(', '));
      }
    });

    this.aedes.on('publish', (packet, client) => {
      if (client && packet && packet.topic && !packet.topic.startsWith('$SYS')) {
        // console.log(`📢 [${client.id}] -> ${packet.topic}: ${packet.payload.toString()}`);
      }
    });
  }

  // Integrates WebSockets directly into standard Express HTTP Server on /mqtt
  attachToExpress(httpServer) {
    this.expressWss = new ws.Server({ noServer: true });
    this.expressWss.on('connection', (conn) => {
      const stream = ws.createWebSocketStream(conn);
      this.aedes.handle(stream);
    });

    httpServer.on('upgrade', (request, socket, head) => {
      const pathname = new URL(request.url, `http://${request.headers.host || 'localhost'}`).pathname;
      if (pathname === '/mqtt' || pathname === '/ws') {
        this.expressWss.handleUpgrade(request, socket, head, (websocket) => {
          this.expressWss.emit('connection', websocket, request);
        });
      }
    });
    console.log('⚡ MQTT WebSocket endpoint đã sẵn sàng tại đường dẫn /mqtt trên cổng API HTTP!');
  }
}

module.exports = new BrokerService();
