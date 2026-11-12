import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

// Same flat design tokens as the Home screen.
class _Ui {
  static const bg = Color(0xFF15171E);
  static const surface = Color(0xFF20232C);
  static const surfaceHigh = Color(0xFF282C37);
  static const border = Color(0x14FFFFFF);
  static const accent = Color(0xFF2DD4BF);
  static const onAccent = Color(0xFF0B1F1C);
  static const textPrimary = Color(0xFFF1F3F7);
  static const textSecondary = Color(0xFF9AA0AE);
  static const textMuted = Color(0xFF6B7180);

  static const radius = 16.0;

  static BoxDecoration card() => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );
}

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  final AttendanceRepository _repository = AttendanceRepository();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load attendance: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  List<AttendanceRecord> _recordsForDate(DateTime date) {
    final key = _dateKey(date);
    return _records.where((r) => r.shiftDate == key).toList();
  }

  List<AttendanceRecord> get _focusedMonthRecords {
    return _records.where((r) {
      final d = DateTime.parse(r.shiftDate);
      return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
    }).toList();
  }

  Duration _totalHours(List<AttendanceRecord> records) {
    return records.fold(
      Duration.zero,
      (total, record) => total + record.netDuration,
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  Set<String> get _datesWithRecords => _records.map((r) => r.shiftDate).toSet();

  // ----------------------------- Actions -----------------------------------

  void _changeMonth(int amount) {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + amount);
    final today = DateTime.now();
    final isCurrentMonth = next.year == today.year && next.month == today.month;

    setState(() {
      _focusedMonth = next;
      _selectedDate = isCurrentMonth ? today : next;
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(today.year, today.month);
      _selectedDate = today;
    });
  }

  // ----------------------------- Widgets -----------------------------------

  Widget _buildMonthHeader() {
    final monthRecords = _focusedMonthRecords;
    final days = monthRecords.map((r) => r.shiftDate).toSet().length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _Ui.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$days ${days == 1 ? 'day' : 'days'}  ·  '
                '${_formatDuration(_totalHours(monthRecords))}',
                style: const TextStyle(fontSize: 13, color: _Ui.textSecondary),
              ),
            ],
          ),
        ),
        _iconButton(Icons.chevron_left, () => _changeMonth(-1)),
        const SizedBox(width: 8),
        _iconButton(Icons.chevron_right, () => _changeMonth(1)),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _Ui.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _Ui.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: _Ui.textSecondary),
        ),
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: weekdays
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: _Ui.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);

    // Monday = 0, Sunday = 6.
    final startingOffset = firstDay.weekday - 1;
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final totalCells = ((startingOffset + daysInMonth + 6) ~/ 7) * 7;

    final withRecords = _datesWithRecords;
    final todayKey = _dateKey(DateTime.now());
    final selectedKey = _dateKey(_selectedDate);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - startingOffset + 1;

        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayNumber,
        );
        final key = _dateKey(date);

        final isSelected = key == selectedKey;
        final isToday = key == todayKey;
        final hasRecord = withRecords.contains(key);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? _Ui.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: _Ui.accent)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? _Ui.onAccent : _Ui.textPrimary,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasRecord
                        ? (isSelected ? _Ui.onAccent : _Ui.accent)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard() {
    return GestureDetector(
      // Swipe left/right to change month.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        _changeMonth(velocity < 0 ? 1 : -1);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: _Ui.card(),
        child: Column(
          children: [
            _buildWeekdayLabels(),
            const SizedBox(height: 10),
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateSummary(List<AttendanceRecord> records) {
    final total = _totalHours(records);
    final isToday = _dateKey(_selectedDate) == _dateKey(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _Ui.card(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? 'TODAY'
                      : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                  style: const TextStyle(
                    color: _Ui.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDate),
                  style: const TextStyle(
                    color: _Ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${records.length} ${records.length == 1 ? 'record' : 'records'}',
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(total),
            style: TextStyle(
              color: records.isEmpty ? _Ui.textMuted : _Ui.accent,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecord(AttendanceRecord record) {
    final timeIn = DateFormat('HH:mm').format(record.timeIn);
    final timeOut = DateFormat('HH:mm').format(record.timeOut);
    final endsNextDay = record.timeOut.day != record.timeIn.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _Ui.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  endsNextDay ? 'Overnight shift' : 'Shift',
                  style: const TextStyle(
                    color: _Ui.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatDuration(record.netDuration),
                style: const TextStyle(
                  color: _Ui.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeColumn('TIME IN', timeIn)),
              Expanded(
                child: _timeColumn(
                  'TIME OUT',
                  timeOut,
                  footnote: endsNextDay ? '+1 day' : null,
                ),
              ),
              Expanded(
                child: _timeColumn('BREAK', '${record.breakMinutes} min'),
              ),
            ],
          ),
          if (record.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: _Ui.border),
            const SizedBox(height: 12),
            Text(
              record.notes,
              style: const TextStyle(color: _Ui.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeColumn(String label, String value, {String? footnote}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Ui.textMuted,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _Ui.textPrimary,
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(width: 4),
              Text(
                footnote,
                style: const TextStyle(fontSize: 10, color: _Ui.textMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedDateRecords(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: _Ui.card(),
        child: const Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: _Ui.textMuted,
              size: 34,
            ),
            SizedBox(height: 10),
            Text(
              'No attendance on this day',
              style: TextStyle(
                color: _Ui.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add a shift from the Home screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _Ui.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(children: records.map(_buildAttendanceRecord).toList());
  }

  // ----------------------------- Build -------------------------------------

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _recordsForDate(_selectedDate);
    final today = DateTime.now();
    final showTodayButton =
        _dateKey(_selectedDate) != _dateKey(today) ||
        _focusedMonth.month != today.month ||
        _focusedMonth.year != today.year;

    return Scaffold(
      backgroundColor: _Ui.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _Ui.accent))
            : RefreshIndicator(
                color: _Ui.accent,
                backgroundColor: _Ui.surface,
                onRefresh: _loadRecords,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _buildMonthHeader(),
                    const SizedBox(height: 16),
                    _buildCalendarCard(),
                    if (showTodayButton)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _goToToday,
                          child: const Text('Jump to today'),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    _buildSelectedDateSummary(selectedRecords),
                    const SizedBox(height: 12),
                    _buildSelectedDateRecords(selectedRecords),
                  ],
                ),
              ),
      ),
    );
  }
}
