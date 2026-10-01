import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/node_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/device_provider.dart';

class NodeCard extends StatelessWidget {
  final NodeModel node;
  final VoidCallback onTapManage;
  final VoidCallback onDelete;

  const NodeCard({
    super.key,
    required this.node,
    required this.onTapManage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final devices = context.read<DeviceProvider>();
    final isLivingRoom = node.templateType == 'kitchen_living';
    final hasAlert = node.gasDetector || node.fireDetector;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAlert 
              ? AppTheme.danger 
              : (node.isOnline ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.textMuted.withValues(alpha: 0.2)),
          width: hasAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasAlert ? AppTheme.danger.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Name + Status + Delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLivingRoom 
                        ? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)]
                        : [AppTheme.primary, AppTheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLivingRoom ? Icons.weekend_rounded : Icons.bed_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Chip ID: ${node.chipId}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: node.isOnline 
                      ? AppTheme.success.withValues(alpha: 0.15) 
                      : AppTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: node.isOnline ? AppTheme.success : AppTheme.danger,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: node.isOnline ? AppTheme.success : AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      node.isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: node.isOnline ? AppTheme.success : AppTheme.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          
          const SizedBox(height: 14),

          // Sensors Row: DHT11 Nhiệt độ & Độ ẩm
          if (isLivingRoom)
            Row(
              children: [
                Expanded(
                  child: _buildSensorBox(
                    'Nhiệt độ (DHT11)',
                    '${node.temperature.toStringAsFixed(1)} °C',
                    Icons.thermostat_rounded,
                    const Color(0xFFFF7043),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSensorBox(
                    'Độ ẩm (DHT11)',
                    '${node.humidity.toStringAsFixed(0)} %',
                    Icons.water_drop_rounded,
                    const Color(0xFF29B6F6),
                  ),
                ),
              ],
            ),

          // Cảnh báo khẩn cấp nếu có
          if (hasAlert) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    node.fireDetector ? 'BÁO ĐỘNG: PHÁT HIỆN LỬA!' : 'CẢNH BÁO: RÒ RỈ GAS!',
                    style: const TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Footer: Quick Controls (Đèn, Quạt) & Nút Quản lý
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quick Actions
              Row(
                children: [
                  // Đèn (Relay D25)
                  _buildQuickToggle(
                    icon: Icons.lightbulb_rounded,
                    isOn: node.light,
                    isOnline: node.isOnline,
                    activeColor: const Color(0xFFFFD54F),
                    onTap: () {
                      if (node.isOnline) devices.toggleKitchenLight(node.id);
                    },
                    label: 'Đèn (D25)',
                  ),
                  const SizedBox(width: 8),
                  // Quạt (Relay D26)
                  _buildQuickToggle(
                    icon: Icons.air_rounded,
                    isOn: node.fan,
                    isOnline: node.isOnline,
                    activeColor: const Color(0xFF26A69A),
                    onTap: () {
                      if (node.isOnline) devices.toggleKitchenFan(node.id);
                    },
                    label: 'Quạt (D26)',
                  ),
                ],
              ),

              // Manage Button
              GestureDetector(
                onTap: onTapManage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Chi tiết',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToggle({
    required IconData icon,
    required bool isOn,
    required bool isOnline,
    required Color activeColor,
    required VoidCallback onTap,
    required String label,
  }) {
    final effectiveColor = isOn ? activeColor : AppTheme.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOn ? activeColor.withValues(alpha: 0.15) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOn ? activeColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isOnline ? effectiveColor : AppTheme.textMuted, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isOnline ? (isOn ? Colors.white : AppTheme.textMuted) : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
