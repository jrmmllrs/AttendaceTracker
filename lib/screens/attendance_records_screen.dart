import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../helpers/attendance_sync.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  final AttendanceRepository _repository = AttendanceRepository();
  final TextEditingController _searchController = TextEditingController();

  List<AttendanceRecord> _records = [];

  bool _isLoading = true;
  bool _newestFirst = true;

  DateTimeRange? _dateRange;
  String? _selectedMonth;

  static const Color background = Color(0xFF15171E);
  static const Color surface = Color(0xFF20232C);
  static const Color primary = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF5EEAD4);

  @override
  void initState() {
    super.initState();

    AttendanceSync.version.addListener(_onAttendanceChanged);

    _loadRecords();
  }

  void _onAttendanceChanged() {
    _loadRecords();
  }

  @override
  void dispose() {
    AttendanceSync.version.removeListener(_onAttendanceChanged);
    _searchController.dispose();
    super.dispose();
  }

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

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load records: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  List<String> get _availableMonths {
    final months = _records
        .map((record) {
          final date = DateTime.parse(record.shiftDate);
          return DateFormat('yyyy-MM').format(date);
        })
        .toSet()
        .toList();

    months.sort((a, b) => b.compareTo(a));

    return months;
  }

  List<AttendanceRecord> get _filteredRecords {
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

      final matchesDateRange =
          _dateRange == null ||
          (!date.isBefore(
                DateTime(
                  _dateRange!.start.year,
                  _dateRange!.start.month,
                  _dateRange!.start.day,
                ),
              ) &&
              !date.isAfter(
                DateTime(
                  _dateRange!.end.year,
                  _dateRange!.end.month,
                  _dateRange!.end.day,
                  23,
                  59,
                  59,
                ),
              ));

      return matchesSearch && matchesMonth && matchesDateRange;
    }).toList();

    filtered.sort((a, b) {
      final comparison = a.shiftDate.compareTo(b.shiftDate);
      return _newestFirst ? -comparison : comparison;
    });

    return filtered;
  }

  Duration get _filteredTotalHours {
    return _filteredRecords.fold(
      Duration.zero,
      (total, record) => total + record.netDuration,
    );
  }

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
              primary: primary,
              surface: surface,
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
      _newestFirst = true;
    });
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text('Delete Attendance?'),
          content: const Text(
            'Are you sure you want to delete this attendance record? '
            'This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || record.id == null) return;

    try {
      await _repository.delete(record.id!);

      AttendanceSync.notifyChanged();

      if (!mounted) return;

      await _loadRecords();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance record deleted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete record: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showRecordDetails(AttendanceRecord record) {
    final date = DateTime.parse(record.shiftDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Attendance Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(date),
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 24),
                _detailRow(
                  'Time In',
                  DateFormat('hh:mm a').format(record.timeIn),
                ),
                _detailRow(
                  'Time Out',
                  DateFormat('hh:mm a').format(record.timeOut),
                ),
                _detailRow('Break Duration', '${record.breakMinutes} minutes'),
                _detailRow(
                  'Total Working Hours',
                  _formatDuration(record.netDuration),
                  highlight: true,
                ),
                if (record.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notes',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(record.notes),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? secondary : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final records = _filteredRecords;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F78), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL WORKING HOURS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_filteredTotalHours),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${records.length} ${records.length == 1 ? 'record' : 'records'} found',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.access_time_filled_rounded,
            size: 42,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final months = _availableMonths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search date or notes...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, color: Colors.white54),
                  )
                : null,
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _dateRange == null
                      ? 'Date Range'
                      : '${DateFormat('MMM d').format(_dateRange!.start)} - '
                            '${DateFormat('MMM d').format(_dateRange!.end)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMonth,
                isExpanded: true,
                dropdownColor: surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: const Text('All Months', style: TextStyle(fontSize: 12)),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Months'),
                  ),
                  ...months.map((month) {
                    final date = DateTime(
                      int.parse(month.substring(0, 4)),
                      int.parse(month.substring(5, 7)),
                    );

                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(
                        DateFormat('MMM yyyy').format(date),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value;
                    _dateRange = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Clear filters'),
            ),
            const Spacer(),
            IconButton(
              tooltip: _newestFirst ? 'Oldest first' : 'Newest first',
              onPressed: () {
                setState(() {
                  _newestFirst = !_newestFirst;
                });
              },
              icon: Icon(
                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                color: secondary,
              ),
            ),
            Text(
              _newestFirst ? 'Newest' : 'Oldest',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final date = DateTime.parse(record.shiftDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(date),
                          style: const TextStyle(
                            color: secondary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
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
                          DateFormat('EEEE, yyyy').format(date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('hh:mm a').format(record.timeIn)} - '
                          '${DateFormat('hh:mm a').format(record.timeOut)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDuration(record.netDuration),
                        style: const TextStyle(
                          color: secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Net hours',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              if (record.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  record.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(color: Colors.white10),
              Row(
                children: [
                  const Icon(
                    Icons.free_breakfast_outlined,
                    color: Colors.white38,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Break: ${record.breakMinutes} min',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showRecordDetails(record),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Details'),
                  ),
                  IconButton(
                    tooltip: 'Delete record',
                    onPressed: () => _deleteRecord(record),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.white30, size: 42),
          SizedBox(height: 12),
          Text(
            'No records found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

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
                    const Text(
                      'Manage your attendance history',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _buildSummary(),
                    const SizedBox(height: 22),
                    _buildFilters(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'All Attendance Records',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${records.length} results',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (records.isEmpty)
                      _buildEmptyState()
                    else
                      ...records.map(_buildRecordCard),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
