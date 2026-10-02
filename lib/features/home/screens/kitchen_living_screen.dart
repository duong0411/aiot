import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/models/node_model.dart';
import '../../../core/utils/responsive.dart';

class KitchenLivingScreen extends StatelessWidget {
  final String nodeId;

  const KitchenLivingScreen({super.key, required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090C1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF11142A),
              Color(0xFF090C1A),
              Color(0xFF050711),
            ],
            stops: [0.0, 0.5, 1.0],
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
                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Không tìm thấy thiết bị phòng khách.',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Quay lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
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
                  _buildHeader(context, node, devices),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: R.scrollPadding(context, extra: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),

                          // ── 1. CẢNH BÁO KHẨN CẤP (NẾU CÓ GAS HOẶC LỬA) ────────
                          if (isBuzzerActive || node.rainDetector) ...[
                            _buildEmergencyBanner(node, isBuzzerActive),
                            const SizedBox(height: 18),
                          ],

                          // ── 2. KHÍ HẬU & THỜI TIẾT (BENTO CLIMATE CARD) ───────
                          _buildClimateHeroCard(node)
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, duration: 400.ms),
                          const SizedBox(height: 20),

                          // ── 3. TRUNG TÂM AN TOÀN & BÁO ĐỘNG (3 PILLS) ─────────
                          _sectionHeader(
                            title: 'Hệ thống an toàn & Cảm biến',
                            icon: Icons.shield_rounded,
                            accentColor: const Color(0xFF38EF7D),
                          ),
                          const SizedBox(height: 12),
                          _buildSafetyRow(isGasAlert, isFireAlert, isBuzzerActive),
                          const SizedBox(height: 24),

                          // ── 4. ĐIỀU KHIỂN THIẾT BỊ PHÒNG KHÁCH ────────────────
                          _sectionHeader(
                            title: 'Điều khiển thiết bị',
                            icon: Icons.tune_rounded,
                            accentColor: AppTheme.primaryLight,
                            subtitle: '${node.kitchenLivingActiveCount} thiết bị đang bật',
                          ),
                          const SizedBox(height: 14),

                          // Hàng 2 thiết bị: Đèn (D25) & Quạt (D26)
                          Row(
                            children: [
                              Expanded(
                                child: _buildLightCard(node, devices),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildFanCard(node, devices),
                              ),
                            ],
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                          const SizedBox(height: 14),

                          // Cửa thông minh (Servo D13)
                          _buildDoorCard(context, node, devices)
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.15),

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

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. APP HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, NodeModel node, DeviceProvider devices) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1326).withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Nút Quay lại
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B33),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Tên Phòng & Trạng thái
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.name.isNotEmpty ? node.name : 'Phòng Khách',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live Online Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: node.isOnline 
                            ? const Color(0xFF00E676).withValues(alpha: 0.12)
                            : AppTheme.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: node.isOnline ? const Color(0xFF00E676) : AppTheme.danger,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: node.isOnline ? const Color(0xFF00E676) : AppTheme.danger,
                              shape: BoxShape.circle,
                              boxShadow: node.isOnline ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            node.isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              color: node.isOnline ? const Color(0xFF00E676) : AppTheme.danger,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Trạm ESP32 #${node.chipId} • Cloudflare WSS SSL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Icon Phòng Khách Gradient
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7F00FF).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.weekend_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. EMERGENCY BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmergencyBanner(NodeModel node, bool isBuzzerActive) {
    String message = '';
    Color glowColor = AppTheme.danger;
    IconData icon = Icons.warning_amber_rounded;

    if (node.fireDetector && node.gasDetector) {
      message = '🔥 NGUY HIỂM: PHÁT HIỆN CẢ LỬA VÀ KHÍ GAS RÒ RỈ! CÒI ĐANG HÚ!';
      glowColor = const Color(0xFFFF1744);
      icon = Icons.local_fire_department_rounded;
    } else if (node.fireDetector) {
      message = '🔥 BÁO ĐỘNG CHÁY: PHÁT HIỆN CÓ LỬA TẠI PHÒNG KHÁCH!';
      glowColor = const Color(0xFFFF3D00);
      icon = Icons.local_fire_department_rounded;
    } else if (node.gasDetector) {
      message = '⚠️ CẢNH BÁO: PHÁT HIỆN RÒ RỈ KHÍ GAS (MQ-2)! HÃY MỞ THOÁNG CỬA!';
      glowColor = const Color(0xFFFF9100);
      icon = Icons.gas_meter_rounded;
    } else if (node.rainDetector) {
      message = '🌧️ Ngoài trời đang có mưa (Cảm biến D18 kích hoạt).';
      glowColor = const Color(0xFF00B0FF);
      icon = Icons.water_drop_rounded;
    }

    final bool isCritical = isBuzzerActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: isCritical ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: glowColor, width: isCritical ? 1.6 : 1.2),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isCritical ? 0.35 : 0.15),
            blurRadius: 18,
            spreadRadius: isCritical ? 2 : 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: glowColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) {
      if (isCritical) controller.repeat(reverse: true);
    }).scaleXY(end: isCritical ? 1.02 : 1.0, duration: 800.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. BENTO CLIMATE CARD (Nhiệt độ & Độ ẩm & Mưa)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildClimateHeroCard(NodeModel node) {
    final bool isRain = node.rainDetector;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1F3D),
            Color(0xFF12152B),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row chứa 2 thông số chính: Nhiệt độ & Độ ẩm
          Row(
            children: [
              // Cột Nhiệt độ
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.thermostat_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhiệt độ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.temperature > 0 ? node.temperature.toStringAsFixed(1) : '--',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              ' °C',
                              style: TextStyle(
                                color: Color(0xFFFF7A00),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Đường chia mờ giữa 2 cột
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 16),

              // Cột Độ ẩm
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFF0072FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Độ ẩm',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.humidity > 0 ? node.humidity.toStringAsFixed(0) : '--',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              ' %',
                              style: TextStyle(
                                color: Color(0xFF00D2FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Dải thời tiết & cảm biến mưa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRain 
                  ? const Color(0xFF00B0FF).withValues(alpha: 0.15) 
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRain ? const Color(0xFF00B0FF) : Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isRain ? Icons.thunderstorm_rounded : Icons.wb_sunny_rounded,
                  size: 18,
                  color: isRain ? const Color(0xFF40C4FF) : const Color(0xFFFFD54F),
                ),
                const SizedBox(width: 8),
                Text(
                  isRain ? 'Trời đang có mưa (Cảm biến D18)' : 'Thời tiết tạnh ráo • Không có mưa',
                  style: TextStyle(
                    color: isRain ? const Color(0xFFB3E5FC) : Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isRain ? const Color(0xFF00B0FF) : Colors.white).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isRain ? 'MƯA' : 'KHÔ RÁO',
                    style: TextStyle(
                      color: isRain ? const Color(0xFF40C4FF) : const Color(0xFF81C784),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. AN TOÀN & BÁO ĐỘNG (GAS, LỬA, CÒI)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSafetyRow(bool isGasAlert, bool isFireAlert, bool isBuzzerActive) {
    return Row(
      children: [
        // 1. Gas MQ-2 (D34)
        Expanded(
          child: _buildSafetyCard(
            title: 'Khí Gas MQ-2',
            status: isGasAlert ? 'RÒ RỈ GAS!' : 'An toàn',
            icon: Icons.gas_meter_rounded,
            isAlert: isGasAlert,
            alertColor: const Color(0xFFFF9100),
            normalColor: const Color(0xFF00E676),
          ),
        ),
        const SizedBox(width: 10),

        // 2. Lửa (D19)
        Expanded(
          child: _buildSafetyCard(
            title: 'Cảm biến Lửa',
            status: isFireAlert ? 'CÓ LỬA!' : 'An toàn',
            icon: Icons.local_fire_department_rounded,
            isAlert: isFireAlert,
            alertColor: const Color(0xFFFF1744),
            normalColor: const Color(0xFF00E676),
          ),
        ),
        const SizedBox(width: 10),

        // 3. Còi Báo Động (D14)
        Expanded(
          child: _buildSafetyCard(
            title: 'Còi hú (D14)',
            status: isBuzzerActive ? 'ĐANG KÊU' : 'Yên lặng',
            icon: isBuzzerActive ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            isAlert: isBuzzerActive,
            alertColor: const Color(0xFFFF1744),
            normalColor: const Color(0xFF7C8BA6),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyCard({
    required String title,
    required String status,
    required IconData icon,
    required bool isAlert,
    required Color alertColor,
    required Color normalColor,
  }) {
    final activeColor = isAlert ? alertColor : normalColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: isAlert ? alertColor.withValues(alpha: 0.15) : const Color(0xFF13172E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAlert ? alertColor : Colors.white.withValues(alpha: 0.08),
          width: isAlert ? 1.5 : 1.0,
        ),
        boxShadow: isAlert ? [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: isAlert ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: activeColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: activeColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  5. ĐIỀU KHIỂN ĐÈN (D25) & QUẠT (D26)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLightCard(NodeModel node, DeviceProvider devices) {
    final bool isOn = node.light;
    const Color activeColor = Color(0xFFFFB300);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (node.isOnline) devices.toggleKitchenLight(node.id);
        },
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isOn ? const Color(0xFF2A2314) : const Color(0xFF13172E),
            border: Border.all(
              color: isOn ? activeColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.07),
              width: isOn ? 1.5 : 1.0,
            ),
            boxShadow: isOn ? [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOn ? activeColor : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      boxShadow: isOn ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      Icons.lightbulb_rounded,
                      color: isOn ? Colors.black87 : Colors.white.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                  _buildCustomSwitch(isOn, activeColor),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Đèn phòng khách',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                isOn ? 'Bật • Relay D25' : 'Đang tắt • D25',
                style: TextStyle(
                  color: isOn ? activeColor : Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFanCard(NodeModel node, DeviceProvider devices) {
    final bool isOn = node.fan;
    const Color activeColor = Color(0xFF00E5FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (node.isOnline) devices.toggleKitchenFan(node.id);
        },
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isOn ? const Color(0xFF0F2633) : const Color(0xFF13172E),
            border: Border.all(
              color: isOn ? activeColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.07),
              width: isOn ? 1.5 : 1.0,
            ),
            boxShadow: isOn ? [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOn ? activeColor : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      boxShadow: isOn ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      Icons.air_rounded,
                      color: isOn ? Colors.black87 : Colors.white.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                  _buildCustomSwitch(isOn, activeColor),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Quạt làm mát',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                isOn ? 'Bật • Relay D26' : 'Đang tắt • D26',
                style: TextStyle(
                  color: isOn ? activeColor : Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  6. CỬA THÔNG MINH (SERVO D13)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDoorCard(BuildContext context, NodeModel node, DeviceProvider devices) {
    final bool isOpen = node.door;
    final double angle = node.doorAngle;
    const Color activeColor = Color(0xFF7C4DFF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13172E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpen ? activeColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isOpen ? activeColor.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isOpen ? Icons.door_sliding_rounded : Icons.sensor_door_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cửa thông minh (Servo D13)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOpen ? 'Trạng thái: Đang mở (${angle.round()}°)' : 'Trạng thái: Đang đóng (0°)',
                      style: TextStyle(
                        color: isOpen ? const Color(0xFFB388FF) : Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (node.isOnline) devices.toggleKitchenDoor(node.id);
                },
                child: _buildCustomSwitch(isOpen, activeColor),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider góc mở Servo
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: activeColor.withValues(alpha: 0.25),
              trackHeight: 5,
              valueIndicatorColor: activeColor,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: angle.clamp(0.0, 180.0),
              min: 0,
              max: 180,
              divisions: 180,
              label: '${angle.round()}°',
              onChanged: (val) {},
              onChangeEnd: (val) {
                devices.setKitchenDoorAngle(node.id, val);
              },
            ),
          ),

          // 3 Nút Preset Góc Cửa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildDoorPresetChip(
                  label: 'Đóng (0°)',
                  isSelected: angle <= 5,
                  onTap: () => devices.setKitchenDoorAngle(node.id, 0),
                ),
                const SizedBox(width: 8),
                _buildDoorPresetChip(
                  label: 'Mở 90°',
                  isSelected: (angle - 90).abs() <= 5,
                  onTap: () => devices.setKitchenDoorAngle(node.id, 90),
                ),
                const SizedBox(width: 8),
                _buildDoorPresetChip(
                  label: 'Mở hết (180°)',
                  isSelected: angle >= 175,
                  onTap: () => devices.setKitchenDoorAngle(node.id, 180),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF7C4DFF) : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xFFB388FF) : Colors.white.withValues(alpha: 0.65),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCustomSwitch(bool isOn, Color activeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isOn ? activeColor : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required Color accentColor,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
