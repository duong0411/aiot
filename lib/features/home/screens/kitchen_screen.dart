import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/device_provider.dart';
import 'kitchen_living_screen.dart';

class KitchenScreen extends StatelessWidget {
  final String? nodeId;

  const KitchenScreen({super.key, this.nodeId});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, devices, _) {
        String targetId = nodeId ?? '';
        if (targetId.isEmpty && devices.nodes.isNotEmpty) {
          final livingNode = devices.nodes.firstWhere(
            (n) => n.templateType == 'kitchen_living',
            orElse: () => devices.nodes.first,
          );
          targetId = livingNode.id;
        }

        return KitchenLivingScreen(nodeId: targetId);
      },
    );
  }
}
