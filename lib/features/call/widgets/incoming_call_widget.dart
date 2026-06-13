import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../auth/models/user_model.dart';

class IncomingCallWidget extends StatelessWidget {
  final User caller;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallWidget({
    super.key,
    required this.caller,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مكالمة واردة...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 30,
              child: Text(caller.username.substring(0, 1).toUpperCase()),
            ),
            const SizedBox(height: 12),
            Text(
              caller.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCallButton(
                  icon: Iconsax.call_remove,
                  label: 'رفض',
                  color: Colors.red,
                  onPressed: onReject,
                ),
                _buildCallButton(
                  icon: Iconsax.call_add,
                  label: 'قبول',
                  color: Colors.green,
                  onPressed: onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 28),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
