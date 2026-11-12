import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AttendanceCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(record.shiftDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit attendance'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete attendance'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeColumn(
                    'TIME IN',
                    DateFormat('HH:mm').format(record.timeIn),
                    Icons.login,
                    Colors.greenAccent,
                  ),
                ),
                Expanded(
                  child: _timeColumn(
                    'TIME OUT',
                    DateFormat('HH:mm').format(record.timeOut),
                    Icons.logout,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net working hours',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  formatDuration(record.netDuration),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
              ],
            ),
            if (record.breakMinutes > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Break: ${record.breakMinutes} minutes',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
            if (record.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(record.notes, style: const TextStyle(color: Colors.white60)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeColumn(String label, String time, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
