import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  final AttendanceRepository _repository = AttendanceRepository();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  late DateTime _selectedMonth;

  final Color _background = const Color(0xFF15171E);
  final Color _surface = const Color(0xFF20232C);
  final Color _primary = const Color(0xFF14B8A6);
  final Color _secondary = const Color(0xFF5EEAD4);

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

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
    }
  }

  List<AttendanceRecord> get _monthlyRecords {
    return _records.where((record) {
      final date = DateTime.tryParse(record.shiftDate);

      if (date == null) return false;

      return date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList()..sort((a, b) => b.shiftDate.compareTo(a.shiftDate));
  }

  int _getNetMinutes(AttendanceRecord record) {
    final duration = record.netDuration;

    if (duration.isNegative) return 0;

    return duration.inMinutes;
  }

  int get _totalWorkingMinutes {
    return _monthlyRecords.fold(
      0,
      (total, record) => total + _getNetMinutes(record),
    );
  }

  int get _totalBreakMinutes {
    return _monthlyRecords.fold(
      0,
      (total, record) => total + record.breakMinutes,
    );
  }

  int get _daysWorked {
    return _monthlyRecords.map((record) => record.shiftDate).toSet().length;
  }

  int get _averageMinutes {
    if (_monthlyRecords.isEmpty) return 0;

    return (_totalWorkingMinutes / _monthlyRecords.length).round();
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }

  List<DateTime> get _availableMonths {
    final now = DateTime.now();

    return List.generate(12, (index) => DateTime(now.year, now.month - index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _loadRecords,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildReportContent(),
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final records = _monthlyRecords;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 20),

        _buildSectionTitle('Attendance Overview'),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildSummaryCard(
              title: 'Working Hours',
              value: _formatDuration(_totalWorkingMinutes),
              icon: Icons.access_time_rounded,
              color: _primary,
            ),
            _buildSummaryCard(
              title: 'Days Worked',
              value: '$_daysWorked',
              icon: Icons.calendar_month_rounded,
              color: Colors.blueAccent,
            ),
            _buildSummaryCard(
              title: 'Break Hours',
              value: _formatDuration(_totalBreakMinutes),
              icon: Icons.coffee_rounded,
              color: Colors.orangeAccent,
            ),
            _buildSummaryCard(
              title: 'Average Shift',
              value: _formatDuration(_averageMinutes),
              icon: Icons.trending_up_rounded,
              color: Colors.purpleAccent,
            ),
          ],
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('Monthly Activity'),
        const SizedBox(height: 12),
        _buildActivityCard(),

        const SizedBox(height: 24),

        _buildSectionTitle('Attendance Breakdown'),
        const SizedBox(height: 12),

        if (records.isEmpty)
          _buildEmptyState()
        else
          ...records.map(_buildRecordCard),
      ],
    );
  }

  Widget _buildMonthSelector() {
    final months = _availableMonths;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: _selectedMonth,
          isExpanded: true,
          dropdownColor: _surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: _secondary),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: months.map((month) {
            return DropdownMenuItem(
              value: month,
              child: Text(DateFormat('MMMM yyyy').format(month)),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() => _selectedMonth = value);
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    final count = _monthlyRecords.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildActivityRow('Total attendance records', '$count'),
          const Divider(height: 24, color: Colors.white12),
          _buildActivityRow(
            'Total working time',
            _formatDuration(_totalWorkingMinutes),
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildActivityRow(
            'Total break time',
            _formatDuration(_totalBreakMinutes),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final date = DateTime.tryParse(record.shiftDate);
    final workingMinutes = _getNetMinutes(record);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: _secondary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? record.shiftDate
                      : DateFormat('EEE, MMM d, yyyy').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${DateFormat('hh:mm a').format(record.timeIn)} - '
                  '${DateFormat('hh:mm a').format(record.timeOut)}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                if (record.breakMinutes > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Break: ${record.breakMinutes} minutes',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(workingMinutes),
                style: TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Net hours',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insert_chart_outlined_rounded,
            color: Colors.grey.shade600,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'No attendance records',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            'No records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
