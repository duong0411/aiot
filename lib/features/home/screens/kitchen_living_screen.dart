import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/models/node_model.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/device_control_card.dart';
import '../widgets/sensor_card.dart';

class KitchenLivingScreen extends StatelessWidget {
  final String nodeId;

  const KitchenLivingScreen({super.key, required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF140D2B), Color(0xFF0A0E21)],
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: Consumer<DeviceProvider>(
            builder: (context, devices, _) {
              final NodeModel? node = devices.getNodeById(nodeId);
              if (node == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                      const SizedBox(height: 16),
                      const Text('Không tìm thấy thiết bị phòng khách.', style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Quay lại', style: TextStyle(color: AppTheme.primary)),
                      ),
                    ],
                  ),
                );
              }

              final bool isGasAlert = node.gasDetector;
              final bool isFireAlert = node.fireDetector;
              final bool isBuzzerActive = isGasAlert || isFireAlert;

              return Column(
                children: [
                  _buildHeader(context, node),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: R.scrollPadding(context, extra: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // ── CẢNH BÁO KHẨN CẤP (NẾU CÓ GAS HOẶC LỬA) ────────
                          if (isBuzzerActive || node.rainDetector) ...[
                            _buildEmergencyBanner(node, isBuzzerActive),
                            const SizedBox(height: 16),
                          ],

                          // ── CẢM BIẾN MÔI TRƯỜNG & AN TOÀN ─────────────────
                          _sectionTitle('Thông số cảm biến phòng khách'),
                          const SizedBox(height: 12),
                          
                          // Hàng 1: Nhiệt độ & Độ ẩm (DHT11 - D27)
                          Row(
                            children: [
                              Expanded(
                                child: SensorCard(
                                  title: 'Nhiệt độ (DHT11)',
                                  icon: Icons.thermostat_rounded,
                                  value: node.temperature.toStringAsFixed(1),
                                  unit: '°C',
                                  color: const Color(0xFFFF7043),
                                ).animate(delay: 50.ms).fadeIn().slideY(begin: 0.2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SensorCard(
                                  title: 'Độ ẩm (DHT11)',
                                  icon: Icons.water_drop_rounded,
                                  value: node.humidity.toStringAsFixed(0),
                                  unit: '%',
                                  color: const Color(0xFF29B6F6),
                                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Hàng 2: Khí Gas (D34), Lửa (D19), Còi Buzzer (D14)
                          Row(
                            children: [
                              Expanded(
                                child: SensorCard(
                                  title: 'Khí Gas (MQ2)',
                                  icon: Icons.gas_meter_rounded,
                                  value: isGasAlert ? 'RÒ RỈ GAS!' : 'An toàn',
                                  unit: '',
                                  valueFontSize: 15,
                                  color: isGasAlert ? AppTheme.danger : AppTheme.success,
                                  isAlert: isGasAlert,
                                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SensorCard(
                                  title: 'Cảm biến Lửa',
                                  icon: Icons.local_fire_department_rounded,
                                  value: isFireAlert ? 'CÓ LỬA!' : 'An toàn',
                                  unit: '',
                                  valueFontSize: 15,
                                  color: isFireAlert ? AppTheme.danger : AppTheme.success,
                                  isAlert: isFireAlert,
                                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SensorCard(
                                  title: 'Còi báo (D14)',
                                  icon: Icons.notifications_active_rounded,
                                  value: isBuzzerActive ? 'ĐANG KÊU' : 'Yên lặng',
                                  unit: '',
                                  valueFontSize: 14,
                                  color: isBuzzerActive ? AppTheme.danger : Colors.grey,
                                  isAlert: isBuzzerActive,
                                ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── ĐIỀU KHIỂN THIẾT BỊ ────────────────────────────
                          _sectionTitle('Điều khiển thiết bị phòng khách'),
                          const SizedBox(height: 12),

                          // 1. Relay Đèn (D25)
                          DeviceControlCard(
                            title: 'Đèn phòng khách (Relay D25)',
                            icon: Icons.lightbulb_rounded,
                            isOn: node.light,
                            onToggle: () => devices.toggleKitchenLight(nodeId),
                            activeColor: const Color(0xFFFFD54F),
                            description: node.light ? 'Đang bật chiếu sáng' : 'Đang tắt',
                            isOffline: !node.isOnline,
                          ).animate(delay: 250.ms).fadeIn().slideX(begin: -0.2),
                          const SizedBox(height: 12),

                          // 2. Relay Quạt (D26)
                          DeviceControlCard(
                            title: 'Quạt làm mát (Relay D26)',
                            icon: Icons.air_rounded,
                            isOn: node.fan,
                            onToggle: () => devices.toggleKitchenFan(nodeId),
                            activeColor: const Color(0xFF26A69A),
                            description: node.fan ? 'Đang quay làm mát' : 'Đang tắt',
                            isOffline: !node.isOnline,
                          ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.2),
                          const SizedBox(height: 12),

                          // 3. Servo Cửa (D13)
                          DeviceControlCard(
                            title: 'Cửa thông minh (Servo D13)',
                            icon: Icons.sensor_door_rounded,
                            isOn: node.door,
                            onToggle: () => devices.toggleKitchenDoor(nodeId),
                            activeColor: AppTheme.primary,
                            description: node.door ? 'Cửa đang mở (${node.doorAngle.round()}°)' : 'Cửa đang đóng (0°)',
                            isOffline: !node.isOnline,
                            extra: Column(
                              children: [
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppTheme.primary,
                                    inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.2),
                                    thumbColor: AppTheme.primary,
                                    overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                                    valueIndicatorColor: AppTheme.primary,
                                    valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: node.doorAngle,
                                    min: 0,
                                    max: 180,
                                    divisions: 180,
                                    label: '${node.doorAngle.round()}°',
                                    onChanged: (val) {},
                                    onChangeEnd: (val) {
                                      devices.setKitchenDoorAngle(nodeId, val);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Đóng (0°)', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11)),
                                      Text('Mở vừa (90°)', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11)),
                                      Text('Mở tối đa (180°)', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 350.ms).fadeIn().slideX(begin: -0.2),
                          const SizedBox(height: 12),

                          // 4. Giàn phơi thông minh (Servo D15 & Mưa D18)
                          DeviceControlCard(
                            title: 'Giàn phơi thông minh (Servo D15)',
                            icon: Icons.dry_cleaning_rounded,
                            isOn: node.clothesDryer,
                            onToggle: () => devices.toggleClothesDryer(nodeId),
                            activeColor: const Color(0xFF4DD0E1),
                            description: node.clothesDryer ? 'Đang phơi đồ ngoài trời' : 'Đã thu vào hiên',
                            isOffline: !node.isOnline,
                            extra: Column(
                              children: [
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFF4DD0E1),
                                    inactiveTrackColor: const Color(0xFF4DD0E1).withValues(alpha: 0.2),
                                    thumbColor: const Color(0xFF4DD0E1),
                                    overlayColor: const Color(0xFF4DD0E1).withValues(alpha: 0.2),
                                    valueIndicatorColor: const Color(0xFF4DD0E1),
                                    valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: node.clothesDryerAngle,
                                    min: 0,
                                    max: 180,
                                    divisions: 180,
                                    label: '${node.clothesDryerAngle.round()}°',
                                    onChanged: (val) {},
                                    onChangeEnd: (val) {
                                      devices.setClothesDryerAngle(nodeId, val);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Thu vào (0°)', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11)),
                                      Text('Tự động khi mưa (D18)', style: TextStyle(color: node.rainDetector ? AppTheme.info : AppTheme.textMuted, fontSize: 11, fontWeight: node.rainDetector ? FontWeight.bold : FontWeight.normal)),
                                      Text('Phơi ra (180°)', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 400.ms).fadeIn().slideX(begin: 0.2),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner(NodeModel node, bool isBuzzerActive) {
    String message = '';
    Color bgColor = AppTheme.danger;
    IconData iconData = Icons.warning_amber_rounded;

    if (node.fireDetector) {
      message = '🔥 PHÁT HIỆN LỬA! CÒI BÁO ĐỘNG ĐANG KÍCH HOẠT!';
      bgColor = const Color(0xFFD32F2F);
      iconData = Icons.local_fire_department_rounded;
    } else if (node.gasDetector) {
      message = '⚠️ PHÁT HIỆN RÒ RỈ KHÍ GAS! HÃY MỞ CỬA THÔNG THOÁNG!';
      bgColor = const Color(0xFFE65100);
      iconData = Icons.gas_meter_rounded;
    } else if (node.rainDetector) {
      message = '🌧️ Trời đang mưa — Giàn phơi đã tự động thu vào hiên.';
      bgColor = const Color(0xFF0288D1);
      iconData = Icons.water_drop_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        border: Border.all(color: bgColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: bgColor == const Color(0xFF0288D1) ? const Color(0xFF81D4FA) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.02, duration: 1.seconds);
  }

  Widget _buildHeader(BuildContext context, NodeModel node) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.name.isNotEmpty ? node.name : 'Phòng Khách',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: node.isOnline 
                            ? AppTheme.success.withValues(alpha: 0.15) 
                            : AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: node.isOnline ? AppTheme.success : AppTheme.danger,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        node.isOnline ? 'ESP32 ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: node.isOnline ? AppTheme.success : AppTheme.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Mã trạm: ${node.chipId} • Cloudflare WSS',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.weekend_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
