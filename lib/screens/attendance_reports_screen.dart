import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

// Same flat design tokens as the other screens.
class _Ui {
  static const bg = Color(0xFF15171E);
  static const surface = Color(0xFF20232C);
  static const surfaceHigh = Color(0xFF282C37);
  static const border = Color(0x14FFFFFF);
  static const accent = Color(0xFF2DD4BF);
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

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final AttendanceRepository _repository = AttendanceRepository();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

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
          content: Text('Failed to load reports: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<AttendanceRecord> _recordsForMonth(DateTime month) {
    return _records.where((record) {
      final date = DateTime.tryParse(record.shiftDate);
      if (date == null) return false;
      return date.year == month.year && date.month == month.month;
    }).toList()..sort((a, b) => b.shiftDate.compareTo(a.shiftDate));
  }

  int _netMinutes(AttendanceRecord record) {
    final duration = record.netDuration;
    return duration.isNegative ? 0 : duration.inMinutes;
  }

  int _totalMinutes(List<AttendanceRecord> records) {
    return records.fold(0, (sum, r) => sum + _netMinutes(r));
  }

  int _totalBreak(List<AttendanceRecord> records) {
    return records.fold(0, (sum, r) => sum + r.breakMinutes);
  }

  String _formatMinutes(int minutes) {
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  DateTime get _earliestMonth {
    DateTime? earliest;
    for (final record in _records) {
      final date = DateTime.tryParse(record.shiftDate);
      if (date == null) continue;
      final month = DateTime(date.year, date.month);
      if (earliest == null || month.isBefore(earliest)) earliest = month;
    }
    final now = DateTime.now();
    return earliest ?? DateTime(now.year, now.month);
  }

  bool get _canGoPrevious => _selectedMonth.isAfter(_earliestMonth);

  bool get _canGoNext {
    final now = DateTime.now();
    return _selectedMonth.isBefore(DateTime(now.year, now.month));
  }

  void _changeMonth(int amount) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + amount,
      );
    });
  }

  /// Net minutes per week of the month (days 1-7, 8-14, ...).
  List<_WeekTotal> _weeklyTotals(List<AttendanceRecord> records) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final weeks = <_WeekTotal>[];

    for (var startDay = 1; startDay <= daysInMonth; startDay += 7) {
      final endDay = (startDay + 6) > daysInMonth ? daysInMonth : startDay + 6;

      final minutes = records
          .where((record) {
            final day = DateTime.parse(record.shiftDate).day;
            return day >= startDay && day <= endDay;
          })
          .fold<int>(0, (sum, r) => sum + _netMinutes(r));

      final label = startDay == endDay
          ? '${DateFormat('MMM').format(_selectedMonth)} $startDay'
          : '${DateFormat('MMM').format(_selectedMonth)} $startDay–$endDay';

      weeks.add(_WeekTotal(label, minutes));
    }

    return weeks;
  }

  // ----------------------------- Widgets -----------------------------------

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _Ui.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontSize: 13, color: _Ui.textSecondary),
              ),
            ],
          ),
        ),
        _navButton(
          Icons.chevron_left,
          _canGoPrevious ? () => _changeMonth(-1) : null,
        ),
        const SizedBox(width: 8),
        _navButton(
          Icons.chevron_right,
          _canGoNext ? () => _changeMonth(1) : null,
        ),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;

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
          child: Icon(
            icon,
            color: enabled ? _Ui.textSecondary : _Ui.textMuted.withAlpha(90),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: _Ui.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildHero(List<AttendanceRecord> records) {
    final total = _totalMinutes(records);
    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );
    final previousTotal = _totalMinutes(_recordsForMonth(previousMonth));
    final diff = total - previousTotal;

    Widget? comparison;
    if (previousTotal > 0 && records.isNotEmpty) {
      comparison = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diff >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: _Ui.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '${_formatMinutes(diff.abs())} vs ${DateFormat('MMMM').format(previousMonth)}',
            style: const TextStyle(color: _Ui.textSecondary, fontSize: 13),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _Ui.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL WORKING HOURS',
            style: TextStyle(
              color: _Ui.textSecondary,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatMinutes(total),
            style: TextStyle(
              color: records.isEmpty ? _Ui.textMuted : _Ui.accent,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (comparison != null) ...[const SizedBox(height: 8), comparison],
        ],
      ),
    );
  }

  Widget _buildStats(List<AttendanceRecord> records) {
    final days = records.map((r) => r.shiftDate).toSet().length;
    final average = records.isEmpty
        ? 0
        : (_totalMinutes(records) / records.length).round();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: _Ui.card(),
      child: Column(
        children: [
          Row(
            children: [
              _stat('Days worked', '$days'),
              _divider(),
              _stat('Avg / shift', _formatMinutes(average)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: _Ui.border),
          ),
          Row(
            children: [
              _stat('Break time', _formatMinutes(_totalBreak(records))),
              _divider(),
              _stat('Records', '${records.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _Ui.textPrimary,
              fontSize: 20,
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: _Ui.border,
    );
  }

  Widget _buildWeeklyChart(List<AttendanceRecord> records) {
    final weeks = _weeklyTotals(records);
    final maxMinutes = weeks.fold<int>(
      0,
      (m, w) => w.minutes > m ? w.minutes : m,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Ui.card(),
      child: Column(
        children: weeks.map((week) {
          final fraction = maxMinutes == 0 ? 0.0 : week.minutes / maxMinutes;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    week.label,
                    style: const TextStyle(
                      color: _Ui.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 12, color: _Ui.surfaceHigh),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(height: 12, color: _Ui.accent),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    _formatMinutes(week.minutes),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: week.minutes == 0
                          ? _Ui.textMuted
                          : _Ui.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHighlights(List<AttendanceRecord> records) {
    AttendanceRecord? longest;
    for (final record in records) {
      if (longest == null || _netMinutes(record) > _netMinutes(longest)) {
        longest = record;
      }
    }

    final byWeekday = <int, int>{};
    for (final record in records) {
      final weekday = DateTime.parse(record.shiftDate).weekday;
      byWeekday[weekday] = (byWeekday[weekday] ?? 0) + _netMinutes(record);
    }

    int? busiestWeekday;
    byWeekday.forEach((weekday, minutes) {
      if (busiestWeekday == null || minutes > byWeekday[busiestWeekday]!) {
        busiestWeekday = weekday;
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _Ui.card(),
      child: Column(
        children: [
          _highlightRow(
            'Longest shift',
            longest == null
                ? '—'
                : '${_formatMinutes(_netMinutes(longest))}  ·  '
                      '${DateFormat('MMM d').format(DateTime.parse(longest.shiftDate))}',
          ),
          const Divider(height: 1, color: _Ui.border),
          _highlightRow(
            'Busiest weekday',
            busiestWeekday == null ? '—' : _weekdayNames[busiestWeekday! - 1],
          ),
        ],
      ),
    );
  }

  Widget _highlightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _Ui.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _Ui.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown(List<AttendanceRecord> records) {
    return Container(
      decoration: _Ui.card(),
      child: Column(
        children: [
          for (var i = 0; i < records.length; i++) ...[
            _dailyRow(records[i]),
            if (i != records.length - 1)
              const Divider(height: 1, color: _Ui.border),
          ],
        ],
      ),
    );
  }

  Widget _dailyRow(AttendanceRecord record) {
    final date = DateTime.tryParse(record.shiftDate);
    final endsNextDay = record.timeOut.day != record.timeIn.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null ? '--' : DateFormat('dd').format(date),
                  style: const TextStyle(
                    color: _Ui.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  date == null ? '' : DateFormat('EEE').format(date),
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${DateFormat('HH:mm').format(record.timeIn)} – '
              '${DateFormat('HH:mm').format(record.timeOut)}'
              '${endsNextDay ? ' (+1)' : ''}'
              '${record.breakMinutes > 0 ? '  ·  ${record.breakMinutes}m break' : ''}',
              style: const TextStyle(color: _Ui.textSecondary, fontSize: 12),
            ),
          ),
          Text(
            _formatMinutes(_netMinutes(record)),
            style: const TextStyle(
              color: _Ui.accent,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: _Ui.card(),
      child: Column(
        children: [
          const Icon(
            Icons.insert_chart_outlined_rounded,
            color: _Ui.textMuted,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'No data for this month',
            style: TextStyle(
              color: _Ui.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing recorded in ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final records = _recordsForMonth(_selectedMonth);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildHero(records),
        const SizedBox(height: 12),
        _buildStats(records),
        const SizedBox(height: 28),
        if (records.isEmpty)
          _buildEmptyState()
        else ...[
          _sectionTitle('Hours per week'),
          _buildWeeklyChart(records),
          const SizedBox(height: 28),
          _sectionTitle('Highlights'),
          _buildHighlights(records),
          const SizedBox(height: 28),
          _sectionTitle('Daily breakdown'),
          _buildDailyBreakdown(records),
        ],
      ],
    );
  }

  // ----------------------------- Build -------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Ui.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _Ui.accent))
            : RefreshIndicator(
                color: _Ui.accent,
                backgroundColor: _Ui.surface,
                onRefresh: _loadRecords,
                child: _buildReportContent(),
              ),
      ),
    );
  }
}

class _WeekTotal {
  final String label;
  final int minutes;

  const _WeekTotal(this.label, this.minutes);
}
