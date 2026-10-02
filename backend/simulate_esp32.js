const mqtt = require('mqtt');

const client = mqtt.connect('mqtt://127.0.0.1:1883');

client.on('connect', () => {
  console.log('Test Publisher connected to broker.');

  // 1. ESP32 online
  client.publish('tele/123/status', 'online');
  console.log('-> Published: tele/123/status: online');

  // 2. Temp
  client.publish('tele/123_temp_livingroom/status', JSON.stringify({ value: 28.5 }));
  console.log('-> Published: tele/123_temp_livingroom/status: 28.5');

  // 3. Humidity
  client.publish('tele/123_humi_living_room/status', JSON.stringify({ value: 65 }));
  console.log('-> Published: tele/123_humi_living_room/status: 65');

  // 4. Light OFF
  client.publish('tele/123_led1/status', JSON.stringify({ value: 'OFF' }));
  console.log('-> Published: tele/123_led1/status: OFF');

  // 5. Fan OFF
  client.publish('tele/123_fan_livingroom/status', JSON.stringify({ value: 'OFF' }));
  console.log('-> Published: tele/123_fan_livingroom/status: OFF');

  // 6. Door 0
  client.publish('tele/123_door_livingroom1/status', JSON.stringify({ value: 0 }));
  console.log('-> Published: tele/123_door_livingroom1/status: 0');

  // 7. Gas OFF
  client.publish('tele/123_gas_livingroom/status', JSON.stringify({ value: 'OFF' }));
  console.log('-> Published: tele/123_gas_livingroom/status: OFF');

  // 8. Fire OFF
  client.publish('tele/123_fire_livingroom/status', JSON.stringify({ value: 'OFF' }));
  console.log('-> Published: tele/123_fire_livingroom/status: OFF');

  setTimeout(() => {
    client.end();
    console.log('Done test publish.');
    process.exit(0);
  }, 1000);
});
