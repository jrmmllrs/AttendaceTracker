import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

// ---------------------------------------------------------------------------
// Design tokens: flat, solid colors only. One accent, used sparingly.
// ---------------------------------------------------------------------------
class _Ui {
  static const bg = Color(0xFF15171E);
  static const surface = Color(0xFF20232C);
  static const surfaceHigh = Color(0xFF282C37);
  static const border = Color(0x14FFFFFF); // white @ 8%
  static const accent = Color(0xFF2DD4BF);
  static const onAccent = Color(0xFF0B1F1C);
  static const textPrimary = Color(0xFFF1F3F7);
  static const textSecondary = Color(0xFF9AA0AE);
  static const textMuted = Color(0xFF6B7180);

  static const radius = 16.0;
  static const gap = 12.0;

  static BoxDecoration card({Color color = surface}) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );
}

class AttendanceHomeScreen extends StatefulWidget {
  const AttendanceHomeScreen({super.key});

  @override
  State<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends State<AttendanceHomeScreen> {
  static const int _recentLimit = 6;
  static const double _barMaxHeight = 92;
  static const Color _barMuted = Color(0xFF1F6F66); // solid, no gradient

  final AttendanceRepository _repository = AttendanceRepository();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AttendanceSync.version.addListener(_onAttendanceChanged);
    _loadRecords();
  }

  @override
  void dispose() {
    AttendanceSync.version.removeListener(_onAttendanceChanged);
    super.dispose();
  }

  // Refresh when another screen (e.g. Records) adds, edits or deletes data.
  void _onAttendanceChanged() => _loadRecords();

  // ----------------------------- Data --------------------------------------

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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatHours(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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

  List<AttendanceRecord> get _todayRecords {
    final today = _dateKey(DateTime.now());
    return _records.where((record) => record.shiftDate == today).toList();
  }

  /// Net minutes for each day of the current week, Monday to Sunday.
  List<int> get _weekMinutes {
    final now = DateTime.now();
    final monday =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = _dateKey(day);
      return _records
          .where((record) => record.shiftDate == key)
          .fold<int>(0, (sum, r) {
        final minutes = r.netDuration.inMinutes;
        return sum + (minutes < 0 ? 0 : minutes);
      });
    });
  }

  // ----------------------------- Actions -----------------------------------

  Future<void> _openAttendanceForm({AttendanceRecord? existing}) async {
    final result = await showModalBottomSheet<AttendanceRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AttendanceFormDialog(existing: existing),
    );

    if (result == null) return;

    try {
      if (existing == null) {
        await _repository.insert(result);
        _showMessage('Attendance added.');
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
        _showMessage('Attendance updated.');
      }

      AttendanceSync.notifyChanged();
      await _loadRecords();
    } catch (e) {
      _showMessage('Failed to save attendance: $e');
    }
  }

  Future<void> _deleteAttendance(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _Ui.surface,
        title: const Text('Delete attendance?'),
        content: const Text(
          'This record will be permanently deleted.',
          style: TextStyle(color: _Ui.textSecondary),
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

  // ----------------------------- Today card --------------------------------

  /// The one loud element on the screen: a solid teal card.
  Widget _todayCard() {
    final today = _todayRecords;
    const dark = _Ui.onAccent;
    final darkSoft = dark.withAlpha(170);

    if (today.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _Ui.accent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TODAY',
              style: TextStyle(
                color: darkSoft,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Not logged yet',
              style: TextStyle(
                color: dark,
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Record your shift so it counts toward this month.',
              style: TextStyle(color: darkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openAttendanceForm(),
              icon: const Icon(Icons.add),
              label: const Text(
                "Log today's shift",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: dark,
                foregroundColor: _Ui.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }

    final total = today.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + record.netDuration,
    );
    final first = today.first;
    final endsNextDay = first.timeOut.day != first.timeIn.day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _Ui.accent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY  ·  LOGGED',
                  style: TextStyle(
                    color: darkSoft,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, color: dark, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatHours(total),
            style: const TextStyle(
              color: dark,
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('HH:mm').format(first.timeIn)} – '
            '${DateFormat('HH:mm').format(first.timeOut)}'
            '${endsNextDay ? ' (+1 day)' : ''}'
            '  ·  ${first.breakMinutes}m break'
            '${today.length > 1 ? '  ·  +${today.length - 1} more' : ''}',
            style: TextStyle(color: darkSoft, fontSize: 13),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _openAttendanceForm(existing: first),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: dark,
              side: BorderSide(color: dark.withAlpha(120)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Week strip --------------------------------

  Widget _weekStrip() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final minutes = _weekMinutes;
    final todayIndex = DateTime.now().weekday - 1;

    // Scale to at least an 8h day so an empty week doesn't look full.
    final peak = minutes.fold<int>(8 * 60, (m, v) => v > m ? v : m);
    final weekTotal = minutes.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _Ui.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This week',
                  style: TextStyle(
                    color: _Ui.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatHours(Duration(minutes: weekTotal)),
                style: const TextStyle(
                  color: _Ui.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final value = minutes[i];
              final isToday = i == todayIndex;
              final height = value == 0
                  ? 4.0
                  : (value / peak * _barMaxHeight).clamp(8.0, _barMaxHeight);

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 16,
                      child: value == 0
                          ? null
                          : Text(
                              '${(value / 60).toStringAsFixed(value % 60 == 0 ? 0 : 1)}h',
                              style: TextStyle(
                                color: isToday
                                    ? _Ui.accent
                                    : _Ui.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: value == 0
                            ? _Ui.surfaceHigh
                            : (isToday ? _Ui.accent : _barMuted),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: isToday ? _Ui.textPrimary : _Ui.textMuted,
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Month numbers -----------------------------

  /// Open typography, no card: three big numbers on the page background.
  Widget _monthNumbers(DateTime now) {
    Widget number(String value, String label) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _Ui.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(
          width: 1,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: _Ui.border,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM').format(now).toUpperCase(),
          style: const TextStyle(
            color: _Ui.textSecondary,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            number(_formatHours(_totalMonthlyHours), 'Hours'),
            divider(),
            number('$_monthlyDaysWorked', 'Days worked'),
            divider(),
            number(_formatHours(_averageShiftHours), 'Avg / shift'),
          ],
        ),
      ],
    );
  }

  // ----------------------------- Timeline ----------------------------------

  Widget _timeline() {
    final recent = _records.take(_recentLimit).toList();

    if (recent.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: _Ui.card(),
        child: const Column(
          children: [
            Icon(Icons.event_note_outlined, size: 40, color: _Ui.textMuted),
            SizedBox(height: 12),
            Text(
              'No attendance yet',
              style: TextStyle(
                color: _Ui.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Your logged shifts will show up here.',
              style: TextStyle(color: _Ui.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < recent.length; i++)
          _timelineRow(recent[i], isLast: i == recent.length - 1),
      ],
    );
  }

  Widget _timelineRow(AttendanceRecord record, {required bool isLast}) {
    final date = DateTime.parse(record.shiftDate);
    final isToday = record.shiftDate == _dateKey(DateTime.now());
    final endsNextDay = record.timeOut.day != record.timeIn.day;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? _Ui.accent : _Ui.surfaceHigh,
                    border: Border.all(
                      color: isToday ? _Ui.accent : _Ui.textMuted,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: _Ui.surfaceHigh),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openAttendanceForm(existing: record),
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday
                                ? 'Today'
                                : DateFormat('EEEE, MMM d').format(date),
                            style: const TextStyle(
                              color: _Ui.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${DateFormat('HH:mm').format(record.timeIn)} – '
                            '${DateFormat('HH:mm').format(record.timeOut)}'
                            '${endsNextDay ? ' (+1)' : ''}'
                            '${record.breakMinutes > 0 ? '  ·  ${record.breakMinutes}m break' : ''}',
                            style: const TextStyle(
                              color: _Ui.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatHours(record.netDuration),
                      style: const TextStyle(
                        color: _Ui.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: _Ui.surfaceHigh,
                      icon: const Icon(
                        Icons.more_vert,
                        color: _Ui.textMuted,
                        size: 20,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openAttendanceForm(existing: record);
                        } else {
                          _deleteAttendance(record);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Ui.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(fontSize: 12, color: _Ui.textMuted),
            ),
        ],
      ),
    );
  }

  // ----------------------------- Build -------------------------------------

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _Ui.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAttendanceForm(),
        backgroundColor: _Ui.surfaceHigh,
        foregroundColor: _Ui.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _Ui.border),
        ),
        tooltip: 'Add attendance',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _Ui.accent,
          backgroundColor: _Ui.surface,
          onRefresh: _loadRecords,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _Ui.accent),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _Ui.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
                      style: const TextStyle(
                        color: _Ui.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _todayCard(),
                    const SizedBox(height: 16),
                    _weekStrip(),
                    const SizedBox(height: 28),
                    _monthNumbers(now),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Recent',
                      trailing: _records.length > _recentLimit
                          ? 'Latest $_recentLimit of ${_records.length}'
                          : '${_records.length} records',
                    ),
                    _timeline(),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance form (bottom sheet). Class name kept so existing references work.
// ---------------------------------------------------------------------------
class AttendanceFormDialog extends StatefulWidget {
  final AttendanceRecord? existing;

  const AttendanceFormDialog({super.key, this.existing});

  @override
  State<AttendanceFormDialog> createState() => _AttendanceFormDialogState();
}

class _AttendanceFormDialogState extends State<AttendanceFormDialog> {
  static const List<int> _breakPresets = [0, 30, 45, 60];

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

    _shiftDate =
        existing != null ? DateTime.parse(existing.shiftDate) : DateTime.now();

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

  // ----------------------------- Logic -------------------------------------

  String _timeLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime get _calculatedTimeIn => _combineDateAndTime(_shiftDate, _timeIn);

  DateTime get _calculatedTimeOut {
    var result = _combineDateAndTime(_shiftDate, _timeOut);

    // If Time Out is earlier than or equal to Time In,
    // assume the shift ended the following day.
    if (!result.isAfter(_calculatedTimeIn)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  bool get _endsNextDay => _calculatedTimeOut.day != _calculatedTimeIn.day;

  int get _breakMinutes => int.tryParse(_breakController.text) ?? 0;

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _shiftDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => _shiftDate = result);
  }

  Future<void> _selectTime({required bool isTimeIn}) async {
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: _Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TimeWheelSheet(
        title: isTimeIn ? 'Time in' : 'Time out',
        initial: isTimeIn ? _timeIn : _timeOut,
      ),
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

    if (breakMinutes > 0 &&
        breakMinutes >= timeOut.difference(timeIn).inMinutes) {
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

  // ----------------------------- Widgets -----------------------------------

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _Ui.textSecondary,
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onTap,
    String? footnote,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Ui.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Ui.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _Ui.accent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: _Ui.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _timeLabel(time),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _Ui.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              footnote ?? ' ',
              style: const TextStyle(color: _Ui.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakChips() {
    return Wrap(
      spacing: 8,
      children: _breakPresets.map((minutes) {
        final selected = _breakMinutes == minutes;
        return ChoiceChip(
          label: Text(minutes == 0 ? 'None' : '$minutes min'),
          selected: selected,
          showCheckmark: false,
          selectedColor: _Ui.accent,
          backgroundColor: _Ui.surfaceHigh,
          side: const BorderSide(color: _Ui.border),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFF0B1F1C) : _Ui.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          onSelected: (_) {
            setState(() => _breakController.text = minutes.toString());
          },
        );
      }).toList(),
    );
  }

  String _previewHours() {
    final duration = _calculatedTimeOut.difference(_calculatedTimeIn);
    final netMinutes = duration.inMinutes - _breakMinutes;

    if (netMinutes < 0) return 'Invalid';
    return '${netMinutes ~/ 60}h ${netMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isEditing ? 'Edit attendance' : 'Add attendance',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _Ui.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              _label('SHIFT DATE'),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_shiftDate),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Ui.textPrimary,
                    side: const BorderSide(color: _Ui.border),
                    backgroundColor: _Ui.surfaceHigh,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      label: 'TIME IN',
                      time: _timeIn,
                      icon: Icons.login,
                      onTap: () => _selectTime(isTimeIn: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeTile(
                      label: 'TIME OUT',
                      time: _timeOut,
                      icon: Icons.logout,
                      onTap: () => _selectTime(isTimeIn: false),
                      footnote: _endsNextDay
                          ? 'Next day, ${DateFormat('MMM d').format(_calculatedTimeOut)}'
                          : 'Same day',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _label('BREAK'),
              _breakChips(),
              const SizedBox(height: 10),
              TextFormField(
                controller: _breakController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Break duration (minutes)',
                  prefixIcon: Icon(Icons.coffee_outlined),
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
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 18),

              // Net hours: a plain row, no extra card chrome.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _Ui.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Ui.border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Net working hours',
                        style: TextStyle(color: _Ui.textSecondary),
                      ),
                    ),
                    Text(
                      _previewHours(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _Ui.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _Ui.textSecondary,
                        side: const BorderSide(color: _Ui.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _Ui.accent,
                        foregroundColor: const Color(0xFF0B1F1C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isEditing ? 'Update' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Time picker: two looping wheels (24h). Works with touch, mouse drag and
// mouse wheel, so it is also usable when running on web/desktop.
// ---------------------------------------------------------------------------
class _TimeWheelSheet extends StatefulWidget {
  final String title;
  final TimeOfDay initial;

  const _TimeWheelSheet({required this.title, required this.initial});

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const double _itemExtent = 52;

  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 90,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemExtent,
        diameterRatio: 2.2,
        perspective: 0.002,
        overAndUnderCenterOpacity: 0.3,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) => onChanged(index % count),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: List.generate(
            count,
            (i) => Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _Ui.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _Ui.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _itemExtent * 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Flat highlight band behind the selected row.
                  IgnorePointer(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: _Ui.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _Ui.border),
                      ),
                    ),
                  ),
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _wheel(
                          controller: _hourController,
                          count: 24,
                          onChanged: (v) => _hour = v,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: _Ui.accent,
                            ),
                          ),
                        ),
                        _wheel(
                          controller: _minuteController,
                          count: 60,
                          onChanged: (v) => _minute = v,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _Ui.textSecondary,
                      side: const BorderSide(color: _Ui.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TimeOfDay(hour: _hour, minute: _minute),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _Ui.accent,
                      foregroundColor: const Color(0xFF0B1F1C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Set time',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}