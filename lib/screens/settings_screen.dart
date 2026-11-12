
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color background = Color(0xFF15171E);
  static const Color surface = Color(0xFF20232C);
  static const Color primary = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFF5EEAD4);

  String _timeFormat = '24-hour';
  String _weekStart = 'Monday';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _timeFormat =
          preferences.getString('time_format') ?? '24-hour';
      _weekStart =
          preferences.getString('week_start') ?? 'Monday';
      _isLoading = false;
    });
  }

  Future<void> _saveTimeFormat(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('time_format', value);

    if (!mounted) return;

    setState(() => _timeFormat = value);
    _showMessage('Time format preference saved.');
  }

  Future<void> _saveWeekStart(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('week_start', value);

    if (!mounted) return;

    setState(() => _weekStart = value);
    _showMessage('Week start preference saved.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _buildIntro(),
            const SizedBox(height: 24),

            _buildSectionTitle('Preferences'),
            const SizedBox(height: 12),

            _buildPreferenceCard(
              icon: Icons.access_time_rounded,
              title: 'Time Format',
              subtitle: 'Choose how time should be displayed.',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _timeFormat,
                  dropdownColor: surface,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: '12-hour',
                      child: Text('12-hour (AM / PM)'),
                    ),
                    DropdownMenuItem(
                      value: '24-hour',
                      child: Text('24-hour'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _saveTimeFormat(value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildPreferenceCard(
              icon: Icons.calendar_month_rounded,
              title: 'Week Starts On',
              subtitle: 'Choose the first day of your week.',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _weekStart,
                  dropdownColor: surface,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Monday',
                      child: Text('Monday'),
                    ),
                    DropdownMenuItem(
                      value: 'Sunday',
                      child: Text('Sunday'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _saveWeekStart(value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('Appearance'),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Appearance',
              subtitle:
                  'TimeTrack currently uses its dark charcoal and teal theme.',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('Local Database'),
            const SizedBox(height: 12),
            _buildDatabaseCard(),

            const SizedBox(height: 24),

            _buildSectionTitle('About'),
            const SizedBox(height: 12),
            _buildAboutCard(),

            const SizedBox(height: 24),

            Center(
              child: Text(
                'TimeTrack • Attendance Tracker',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your preferences and application information.',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _iconContainer(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildDatabaseCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _databaseRow(
            Icons.storage_rounded,
            'Database Name',
            'timetrack.db',
          ),
          const Divider(color: Colors.white10, height: 24),
          _databaseRow(
            Icons.devices_rounded,
            'Storage Type',
            'Local SQLite',
          ),
          const Divider(color: Colors.white10, height: 24),
          _databaseRow(
            Icons.cloud_off_rounded,
            'Cloud Sync',
            'Not connected',
          ),
        ],
      ),
    );
  }

  Widget _databaseRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: secondary, size: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return _buildInfoCard(
      icon: Icons.info_outline_rounded,
      title: 'TimeTrack',
      subtitle:
          'A simple attendance tracking application for managing '
          'daily working hours, breaks, records, and reports.',
      trailing: const Icon(
        Icons.verified_rounded,
        color: primary,
        size: 20,
      ),
    );
  }

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: secondary, size: 19),
    );
  }
}
