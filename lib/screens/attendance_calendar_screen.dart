import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

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

  static const Color background = Color(0xFF15171E);
  static const Color surface = Color(0xFF20232C);
  static const Color primary = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF5EEAD4);

  @override
  void dispose() {
    AttendanceSync.version.removeListener(_onAttendanceChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    AttendanceSync.version.addListener(_onAttendanceChanged);

    _loadRecords();
  }

  void _onAttendanceChanged() {
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

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load attendance: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  List<AttendanceRecord> _recordsForDate(DateTime date) {
    final key = _dateKey(date);

    return _records.where((record) {
      return record.shiftDate == key;
    }).toList();
  }

  Duration _totalHours(List<AttendanceRecord> records) {
    return records.fold(
      Duration.zero,
      (total, record) => total + record.netDuration,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  bool _hasAttendance(DateTime date) {
    return _records.any((record) => record.shiftDate == _dateKey(date));
  }

  void _changeMonth(int amount) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + amount,
      );

      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Attendance Calendar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
          color: Colors.white70,
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
          color: Colors.white70,
        ),
      ],
    );
  }

  Widget _buildMonthTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              final today = DateTime.now();

              setState(() {
                _focusedMonth = DateTime(today.year, today.month);
                _selectedDate = today;
              });
            },
            child: const Text('Today', style: TextStyle(color: secondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.85,
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

        final isSelected = _dateKey(date) == _dateKey(_selectedDate);
        final isToday = _dateKey(date) == _dateKey(DateTime.now());
        final hasRecord = _hasAttendance(date);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDate(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? primary
                  : isToday
                  ? primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: primary.withValues(alpha: 0.6))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasRecord
                        ? isSelected
                              ? Colors.black
                              : secondary
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildMonthTitle(),
          _buildWeekdayLabels(),
          const SizedBox(height: 12),
          _buildCalendarGrid(),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Has attendance',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 18),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  border: Border.all(color: primary),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Today',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateSummary(List<AttendanceRecord> records) {
    final total = _totalHours(records);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F78), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${records.length} attendance ${records.length == 1 ? 'record' : 'records'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecord(AttendanceRecord record) {
    final timeIn = DateFormat('hh:mm a').format(record.timeIn);
    final timeOut = DateFormat('hh:mm a').format(record.timeOut);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: secondary, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Work Schedule',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatDuration(record.netDuration),
                style: const TextStyle(
                  color: secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeColumn('TIME IN', timeIn)),
              Expanded(child: _timeColumn('TIME OUT', timeOut)),
              Expanded(
                child: _timeColumn('BREAK', '${record.breakMinutes} min'),
              ),
            ],
          ),
          if (record.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            Text(
              record.notes,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSelectedDateRecords(List<AttendanceRecord> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: Colors.white30,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'No attendance records',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 5),
                Text(
                  'There are no saved shifts for this date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...records.map(_buildAttendanceRecord),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _recordsForDate(_selectedDate);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : RefreshIndicator(
                color: primary,
                onRefresh: _loadRecords,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCalendarHeader(),
                    const SizedBox(height: 8),
                    _buildCalendarCard(),
                    const SizedBox(height: 20),
                    _buildSelectedDateSummary(selectedRecords),
                    const SizedBox(height: 24),
                    _buildSelectedDateRecords(selectedRecords),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
