import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Same flat design tokens as the other screens.
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _timeFormatKey = 'time_format';
  static const String _weekStartKey = 'week_start';

  String _timeFormat = '24-hour';
  String _weekStart = 'Monday';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ----------------------------- Data --------------------------------------

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        _timeFormat = preferences.getString(_timeFormatKey) ?? '24-hour';
        _weekStart = preferences.getString(_weekStartKey) ?? 'Monday';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveString(String key, String value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
    } catch (e) {
      _showMessage('Could not save setting: $e');
    }
  }

  Future<void> _setTimeFormat(String value) async {
    // Update the UI first; the selection itself is the feedback.
    setState(() => _timeFormat = value);
    await _saveString(_timeFormatKey, value);
  }

  Future<void> _setWeekStart(String value) async {
    setState(() => _weekStart = value);
    await _saveString(_weekStartKey, value);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ----------------------------- Widgets -----------------------------------

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _Ui.textSecondary,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// One card containing several rows separated by hairline dividers.
  Widget _group(List<Widget> rows) {
    return Container(
      decoration: _Ui.card(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: _Ui.border,
              ),
          ],
        ],
      ),
    );
  }

  /// A setting with a title, a short hint and a segmented choice underneath.
  Widget _choiceRow({
    required String title,
    required String hint,
    required List<String> options,
    required Map<String, String> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _Ui.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(color: _Ui.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: options
                  .map(
                    (option) => ButtonSegment<String>(
                      value: option,
                      label: Text(labels[option] ?? option),
                    ),
                  )
                  .toList(),
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.standard,
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? _Ui.accent
                      : _Ui.surfaceHigh,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? _Ui.onAccent
                      : _Ui.textSecondary,
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: _Ui.border),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _Ui.textSecondary, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _Ui.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TimeTrack',
            style: TextStyle(
              color: _Ui.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'A simple attendance tracker for daily working hours, '
            'breaks, records and monthly reports.',
            style: TextStyle(
              color: _Ui.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _Ui.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('Display'),
                  _group([
                    _choiceRow(
                      title: 'Time format',
                      hint: 'How times are shown across the app.',
                      options: const ['24-hour', '12-hour'],
                      labels: const {
                        '24-hour': '24-hour  (17:00)',
                        '12-hour': '12-hour  (5:00 PM)',
                      },
                      value: _timeFormat,
                      onChanged: _setTimeFormat,
                    ),
                    _choiceRow(
                      title: 'Week starts on',
                      hint: 'The first day of your week.',
                      options: const ['Monday', 'Sunday'],
                      labels: const {},
                      value: _weekStart,
                      onChanged: _setWeekStart,
                    ),
                  ]),

                  const SizedBox(height: 28),
                  _sectionLabel('Data'),
                  _group([
                    _infoRow('Database', 'timetrack.db'),
                    _infoRow('Storage', 'Local SQLite'),
                    _infoRow('Cloud sync', 'Not connected'),
                  ]),

                  const SizedBox(height: 28),
                  _sectionLabel('About'),
                  _group([_aboutRow()]),
                ],
              ),
      ),
    );
  }
}
