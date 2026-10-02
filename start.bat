@echo off
title AloT Smart Home - API & MQTT Server
echo ====================================================
echo  Khoi dong AloT Smart Home (API Server + MQTT Broker)
echo ====================================================
cd /d "%~dp0backend"
npm start
pause
