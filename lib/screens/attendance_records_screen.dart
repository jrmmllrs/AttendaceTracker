import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

// Same flat design tokens as the Home and Calendar screens.
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

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  static const String _allMonths = '__all__';

  final AttendanceRepository _repository = AttendanceRepository();
  final TextEditingController _searchController = TextEditingController();

  List<AttendanceRecord> _records = [];

  bool _isLoading = true;
  bool _newestFirst = true;

  DateTimeRange? _dateRange;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    AttendanceSync.version.addListener(_onAttendanceChanged);
    _loadRecords();
  }

  @override
  void dispose() {
    AttendanceSync.version.removeListener(_onAttendanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAttendanceChanged() => _loadRecords();

  // ----------------------------- Data --------------------------------------

  Future<void> _loadRecords() async {
    try {
      final result = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _records = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Failed to load records: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  Duration _totalOf(List<AttendanceRecord> records) {
    return records.fold(
      Duration.zero,
      (total, record) => total + record.netDuration,
    );
  }

  List<String> get _availableMonths {
    final months = _records
        .map((r) => DateFormat('yyyy-MM').format(DateTime.parse(r.shiftDate)))
        .toSet()
        .toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _dateRange != null ||
      _selectedMonth != null;

  List<AttendanceRecord> _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _records.where((record) {
      final date = DateTime.parse(record.shiftDate);
      final monthKey = DateFormat('yyyy-MM').format(date);

      final matchesSearch =
          query.isEmpty ||
          record.shiftDate.toLowerCase().contains(query) ||
          record.notes.toLowerCase().contains(query) ||
          DateFormat('MMMM d, yyyy').format(date).toLowerCase().contains(query);

      final matchesMonth = _selectedMonth == null || monthKey == _selectedMonth;

      var matchesRange = true;
      if (_dateRange != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        matchesRange = !date.isBefore(start) && !date.isAfter(end);
      }

      return matchesSearch && matchesMonth && matchesRange;
    }).toList();

    filtered.sort((a, b) {
      final comparison = a.shiftDate.compareTo(b.shiftDate);
      return _newestFirst ? -comparison : comparison;
    });

    return filtered;
  }

  // ----------------------------- Actions -----------------------------------

  Future<void> _selectDateRange() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _Ui.accent,
              onPrimary: _Ui.onAccent,
              surface: _Ui.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _dateRange = result;
        _selectedMonth = null;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _dateRange = null;
      _selectedMonth = null;
    });
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
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
      _showMessage('Failed to delete record: $e');
    }
  }

  void _showRecordDetails(AttendanceRecord record) {
    final date = DateTime.parse(record.shiftDate);
    final endsNextDay = record.timeOut.day != record.timeIn.day;

    showModalBottomSheet(
      context: context,
      backgroundColor: _Ui.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                DateFormat('EEEE, MMMM d, yyyy').format(date),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _Ui.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                endsNextDay ? 'Overnight shift' : 'Same-day shift',
                style: const TextStyle(color: _Ui.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _Ui.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Ui.border),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      'Time in',
                      DateFormat('HH:mm').format(record.timeIn),
                    ),
                    _detailRow(
                      'Time out',
                      '${DateFormat('HH:mm').format(record.timeOut)}'
                          '${endsNextDay ? '  (+1 day)' : ''}',
                    ),
                    _detailRow('Break', '${record.breakMinutes} min'),
                    _detailRow(
                      'Net hours',
                      _formatDuration(record.netDuration),
                      highlight: true,
                      last: true,
                    ),
                  ],
                ),
              ),
              if (record.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'NOTES',
                  style: TextStyle(
                    color: _Ui.textMuted,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  record.notes,
                  style: const TextStyle(color: _Ui.textPrimary),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _deleteRecord(record);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: _Ui.accent,
                        foregroundColor: _Ui.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------- Widgets -----------------------------------

  Widget _detailRow(
    String label,
    String value, {
    bool highlight = false,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: _Ui.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _Ui.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlight ? _Ui.accent : _Ui.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<AttendanceRecord> records) {
    final days = records.map((r) => r.shiftDate).toSet().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _Ui.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasActiveFilters ? 'FILTERED TOTAL' : 'ALL TIME',
                  style: const TextStyle(
                    color: _Ui.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_totalOf(records)),
                  style: const TextStyle(
                    color: _Ui.accent,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${records.length} ${records.length == 1 ? 'record' : 'records'}',
                style: const TextStyle(
                  color: _Ui.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$days ${days == 1 ? 'day' : 'days'}',
                style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool active = false,
  }) {
    return Material(
      color: active ? _Ui.accent : _Ui.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? _Ui.accent : _Ui.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? _Ui.onAccent : _Ui.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? _Ui.onAccent : _Ui.textPrimary,
                ),
              ),
              if (active && onClear != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 16, color: _Ui.onAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthChip() {
    final months = _availableMonths;
    final selected = _selectedMonth;

    final label = selected == null
        ? 'All months'
        : DateFormat('MMM yyyy').format(
            DateTime(
              int.parse(selected.substring(0, 4)),
              int.parse(selected.substring(5, 7)),
            ),
          );

    return PopupMenuButton<String>(
      color: _Ui.surfaceHigh,
      tooltip: 'Filter by month',
      onSelected: (value) {
        setState(() {
          _selectedMonth = value == _allMonths ? null : value;
          if (_selectedMonth != null) _dateRange = null;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: _allMonths, child: Text('All months')),
        ...months.map((month) {
          final date = DateTime(
            int.parse(month.substring(0, 4)),
            int.parse(month.substring(5, 7)),
          );
          return PopupMenuItem(
            value: month,
            child: Text(DateFormat('MMMM yyyy').format(date)),
          );
        }),
      ],
      child: IgnorePointer(
        child: _filterChip(
          icon: Icons.calendar_month_outlined,
          label: label,
          active: selected != null,
          onTap: () {},
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: _Ui.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search date or notes',
            hintStyle: const TextStyle(color: _Ui.textMuted),
            prefixIcon: const Icon(Icons.search, color: _Ui.textMuted),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, color: _Ui.textMuted),
                  )
                : null,
            filled: true,
            fillColor: _Ui.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Ui.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Ui.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                icon: Icons.date_range_outlined,
                label: _dateRange == null
                    ? 'Date range'
                    : '${DateFormat('MMM d').format(_dateRange!.start)} – '
                          '${DateFormat('MMM d').format(_dateRange!.end)}',
                active: _dateRange != null,
                onTap: _selectDateRange,
                onClear: () => setState(() => _dateRange = null),
              ),
              const SizedBox(width: 8),
              _buildMonthChip(),
              const SizedBox(width: 8),
              _filterChip(
                icon: _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                label: _newestFirst ? 'Newest first' : 'Oldest first',
                onTap: () => setState(() => _newestFirst = !_newestFirst),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear all'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthHeader(String monthKey, List<AttendanceRecord> inMonth) {
    final date = DateTime(
      int.parse(monthKey.substring(0, 4)),
      int.parse(monthKey.substring(5, 7)),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(date),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _Ui.textPrimary,
              ),
            ),
          ),
          Text(
            '${_formatDuration(_totalOf(inMonth))}  ·  ${inMonth.length}',
            style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final date = DateTime.parse(record.shiftDate);
    final endsNextDay = record.timeOut.day != record.timeIn.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _Ui.card(),
      child: InkWell(
        borderRadius: BorderRadius.circular(_Ui.radius),
        onTap: () => _showRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _Ui.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(date),
                          style: const TextStyle(
                            color: _Ui.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: const TextStyle(
                            color: _Ui.textMuted,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date),
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
                          '  ·  ${record.breakMinutes}m break',
                          style: const TextStyle(
                            color: _Ui.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(record.netDuration),
                    style: const TextStyle(
                      color: _Ui.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (record.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  record.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedList(List<AttendanceRecord> records) {
    final widgets = <Widget>[];

    // Records are already sorted, so months appear in order.
    final byMonth = <String, List<AttendanceRecord>>{};
    for (final record in records) {
      final key = record.shiftDate.substring(0, 7); // yyyy-MM
      byMonth.putIfAbsent(key, () => []).add(record);
    }

    byMonth.forEach((monthKey, inMonth) {
      widgets.add(_monthHeader(monthKey, inMonth));
      widgets.addAll(inMonth.map(_buildRecordCard));
    });

    return widgets;
  }

  Widget _buildEmptyState() {
    final filtered = _hasActiveFilters;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: _Ui.card(),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.event_note_outlined,
            color: _Ui.textMuted,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'No matching records' : 'No attendance yet',
            style: const TextStyle(
              color: _Ui.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Try changing your search or filters.'
                : 'Records you add on the Home screen show up here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
          ),
          if (filtered) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------- Build -------------------------------------

  @override
  Widget build(BuildContext context) {
    // Filter once per build and reuse the result.
    final records = _applyFilters();

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
                    const Text(
                      'Records',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _Ui.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummary(records),
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 4),
                    if (records.isEmpty) ...[
                      const SizedBox(height: 12),
                      _buildEmptyState(),
                    ] else
                      ..._buildGroupedList(records),
                  ],
                ),
              ),
      ),
    );
  }
}
