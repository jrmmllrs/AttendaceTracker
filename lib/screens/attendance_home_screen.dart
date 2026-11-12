import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../widgets/attendance_card.dart';
import '../helpers/attendance_sync.dart';

class AttendanceHomeScreen extends StatefulWidget {
  const AttendanceHomeScreen({super.key});

  @override
  State<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends State<AttendanceHomeScreen> {
  final AttendanceRepository _repository = AttendanceRepository();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _repository.getAll();

      if (!mounted) return;

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('Failed to load attendance: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatHours(Duration duration) {
    return '${duration.inHours}h '
        '${duration.inMinutes.remainder(60)}m';
  }

  List<AttendanceRecord> get _monthlyRecords {
    final now = DateTime.now();

    return _records.where((record) {
      final date = DateTime.parse(record.shiftDate);
      return date.year == now.year && date.month == now.month;
    }).toList();
  }

  Duration get _totalMonthlyHours {
    return _monthlyRecords.fold(
      Duration.zero,
      (total, record) => total + record.netDuration,
    );
  }

  int get _monthlyDaysWorked {
    return _monthlyRecords.map((record) => record.shiftDate).toSet().length;
  }

  Duration get _averageShiftHours {
    if (_monthlyRecords.isEmpty) return Duration.zero;
    return Duration(
      microseconds: _totalMonthlyHours.inMicroseconds ~/ _monthlyRecords.length,
    );
  }

  Duration get _totalMonthlyBreak {
    final minutes = _monthlyRecords.fold<int>(
      0,
      (total, record) => total + record.breakMinutes,
    );
    return Duration(minutes: minutes);
  }

  List<AttendanceRecord> get _todayRecords {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _records.where((record) => record.shiftDate == today).toList();
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20232C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttendanceForm({AttendanceRecord? existing}) async {
    final result = await showDialog<AttendanceRecord>(
      context: context,
      builder: (context) => AttendanceFormDialog(existing: existing),
    );

    if (result == null) return;

    try {
      if (existing == null) {
        await _repository.insert(result);
        AttendanceSync.notifyChanged();
        _showMessage('Attendance added successfully.');
      } else {
        final updated = AttendanceRecord(
          id: existing.id,
          shiftDate: result.shiftDate,
          timeIn: result.timeIn,
          timeOut: result.timeOut,
          breakMinutes: result.breakMinutes,
          notes: result.notes,
          createdAt: existing.createdAt,
        );

        await _repository.update(updated);
        _showMessage('Attendance updated successfully.');
      }

      await _loadRecords();
    } catch (e) {
      _showMessage('Failed to save attendance: $e');
    }
  }

  Future<void> _deleteAttendance(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: const Text(
          'This attendance record will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || record.id == null) return;

    try {
      await _repository.delete(record.id!);
      AttendanceSync.notifyChanged();
      await _loadRecords();
      _showMessage('Attendance deleted.');
    } catch (e) {
      _showMessage('Failed to delete attendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAttendanceForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Attendance'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecords,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, MMMM dd, yyyy').format(now),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loadRecords,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh attendance',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your attendance overview',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Monthly working-hours summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF164E49), Color(0xFF163A3B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL WORKING HOURS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatHours(_totalMonthlyHours),
                            style: const TextStyle(
                              color: Color(0xFF5EEAD4),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'For ${DateFormat('MMMM yyyy').format(now)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Monthly statistics
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statCard(
                          title: 'Days Worked',
                          value: '$_monthlyDaysWorked',
                          icon: Icons.calendar_month,
                          color: const Color(0xFF14B8A6),
                        ),
                        _statCard(
                          title: 'Average per Shift',
                          value: _formatHours(_averageShiftHours),
                          icon: Icons.trending_up,
                          color: Colors.blueAccent,
                        ),
                        _statCard(
                          title: 'Total Break Time',
                          value: _formatHours(_totalMonthlyBreak),
                          icon: Icons.coffee,
                          color: Colors.orangeAccent,
                        ),
                        _statCard(
                          title: 'Total Records',
                          value: '${_monthlyRecords.length}',
                          icon: Icons.receipt_long,
                          color: Colors.purpleAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Today's Attendance",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_todayRecords.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20232C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_available, color: Colors.white54),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No attendance recorded for today.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._todayRecords.map(
                        (record) => AttendanceCard(
                          record: record,
                          onEdit: () => _openAttendanceForm(existing: record),
                          onDelete: () => _deleteAttendance(record),
                        ),
                      ),

                    const SizedBox(height: 26),

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Attendance History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_records.length} records',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_records.isEmpty)
                      _emptyState()
                    else
                      ..._records.map(
                        (record) => AttendanceCard(
                          record: record,
                          onEdit: () => _openAttendanceForm(existing: record),
                          onDelete: () => _deleteAttendance(record),
                        ),
                      ),

                    const SizedBox(height: 90),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.event_note, size: 55, color: Colors.grey.shade600),
          const SizedBox(height: 14),
          const Text(
            'No attendance records yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Add Attendance to record your first shift.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

// Attendance form dialog
class AttendanceFormDialog extends StatefulWidget {
  final AttendanceRecord? existing;

  const AttendanceFormDialog({super.key, this.existing});

  @override
  State<AttendanceFormDialog> createState() => _AttendanceFormDialogState();
}

class _AttendanceFormDialogState extends State<AttendanceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _shiftDate;
  late TimeOfDay _timeIn;
  late TimeOfDay _timeOut;

  late TextEditingController _breakController;
  late TextEditingController _notesController;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _shiftDate = existing != null
        ? DateTime.parse(existing.shiftDate)
        : DateTime.now();

    _timeIn = existing != null
        ? TimeOfDay.fromDateTime(existing.timeIn)
        : const TimeOfDay(hour: 17, minute: 0);

    _timeOut = existing != null
        ? TimeOfDay.fromDateTime(existing.timeOut)
        : const TimeOfDay(hour: 2, minute: 0);

    _breakController = TextEditingController(
      text: (existing?.breakMinutes ?? 0).toString(),
    );

    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _breakController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _timeLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime get _calculatedTimeIn {
    return _combineDateAndTime(_shiftDate, _timeIn);
  }

  DateTime get _calculatedTimeOut {
    var result = _combineDateAndTime(_shiftDate, _timeOut);

    // If Time Out is earlier than or equal to Time In,
    // assume the shift ended the following day.
    if (!result.isAfter(_calculatedTimeIn)) {
      result = result.add(const Duration(days: 1));
    }

    return result;
  }

  String _clockOutDateLabel() {
    return DateFormat('MMMM dd, yyyy').format(_calculatedTimeOut);
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _shiftDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() => _shiftDate = result);
    }
  }

  Future<void> _selectTime({required bool isTimeIn}) async {
    final result = await showTimePicker(
      context: context,
      initialTime: isTimeIn ? _timeIn : _timeOut,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isTimeIn) {
          _timeIn = result;
        } else {
          _timeOut = result;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final timeIn = _calculatedTimeIn;
    final timeOut = _calculatedTimeOut;

    final breakMinutes = int.parse(_breakController.text);

    if (breakMinutes >= timeOut.difference(timeIn).inMinutes &&
        breakMinutes > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Break cannot exceed total shift duration.'),
        ),
      );
      return;
    }

    final record = AttendanceRecord(
      id: widget.existing?.id,
      shiftDate: DateFormat('yyyy-MM-dd').format(_shiftDate),
      timeIn: timeIn,
      timeOut: timeOut,
      breakMinutes: breakMinutes,
      notes: _notesController.text.trim(),
      createdAt: widget.existing?.createdAt,
    );

    Navigator.pop(context, record);
  }

  Widget _timePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF242832),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: Colors.tealAccent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _timeLabel(time),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to change',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Attendance' : 'Add Attendance'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SHIFT DATE',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('MMMM dd, yyyy').format(_shiftDate)),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _timePickerTile(
                        label: 'TIME IN',
                        time: _timeIn,
                        icon: Icons.login,
                        onTap: () => _selectTime(isTimeIn: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timePickerTile(
                        label: 'TIME OUT',
                        time: _timeOut,
                        icon: Icons.logout,
                        onTap: () => _selectTime(isTimeIn: false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(
                  'Time Out date: ${_clockOutDateLabel()}',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _breakController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Break duration (minutes)',
                    hintText: 'Example: 60',
                    prefixIcon: Icon(Icons.coffee),
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value ?? '');

                    if (minutes == null || minutes < 0) {
                      return 'Enter a valid break duration.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Add additional details...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF163A3B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NET WORKING HOURS',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _previewHours(),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  String _previewHours() {
    final duration = _calculatedTimeOut.difference(_calculatedTimeIn);

    final breakMinutes = int.tryParse(_breakController.text) ?? 0;

    final netMinutes = duration.inMinutes - breakMinutes;

    if (netMinutes < 0) return 'Invalid duration';

    return '${netMinutes ~/ 60}h ${netMinutes % 60}m';
  }
}
