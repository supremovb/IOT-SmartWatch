import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../widgets/top_bar.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _editingProfile = false;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  bool _savingEmailConfig = false;
  bool _testingEmail = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _specCtrl;
  late TextEditingController _alertEmailCtrl;
  late TextEditingController _newEmailCtrl;
  late TextEditingController _newPassCtrl;
  late TextEditingController _confirmPassCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _deptCtrl = TextEditingController(text: user?.department ?? '');
    _specCtrl = TextEditingController(text: user?.specialization ?? '');
    final ap = context.read<AppProvider>();
    _alertEmailCtrl = TextEditingController(text: ap.alertEmail);
    _newEmailCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _specCtrl.dispose();
    _alertEmailCtrl.dispose();
    _newEmailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id ?? '';
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final path = '$userId/avatar.$ext';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
      final urlWithTs = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      if (mounted) {
        await context.read<AuthProvider>().updateProfile(photoUrl: urlWithTs);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    final success = await context.read<AuthProvider>().updateProfile(
      name: _nameCtrl.text.trim(),
      department: _deptCtrl.text.trim(),
      specialization: _specCtrl.text.trim(),
    );
    if (mounted) {
      setState(() {
        _savingProfile = false;
        if (success) _editingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Profile updated!' : 'Update failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final appProvider = context.watch<AppProvider>();
    final t = AppColors.themed(context);

    return Column(
      children: [
        TopBar(
          onProfileTap: () {},
          onNavigate: widget.onNavigate,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, 'Profile Information'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: _pickAndUploadPhoto,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _uploadingPhoto
                                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                        : user?.photoUrl != null
                                            ? Image.network(
                                                user!.photoUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Icon(
                                                  _roleIcon(user.role),
                                                  size: 40,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : Icon(
                                                _roleIcon(user?.role ?? ''),
                                                size: 40,
                                                color: AppColors.primary,
                                              ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickAndUploadPhoto,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? 'User',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                      builder: (_) {
                                        final r = user?.role?.toLowerCase() ?? '';
                                        String label;
                                        Color color;
                                        switch (r) {
                                          case 'doctor':
                                            label = 'Doctor';
                                            color = Colors.blue;
                                            break;
                                          case 'admin':
                                            label = 'Admin';
                                            color = Colors.purple;
                                            break;
                                          case 'nurse':
                                            label = 'Nurse';
                                            color = Colors.green;
                                            break;
                                          default:
                                            label = r.isNotEmpty ? r[0].toUpperCase() + r.substring(1) : 'Staff';
                                            color = Colors.grey;
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            if (!_editingProfile)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Profile',
                                onPressed: () {
                                  _nameCtrl.text = user?.name ?? '';
                                  _deptCtrl.text = user?.department ?? '';
                                  _specCtrl.text = user?.specialization ?? '';
                                  setState(() => _editingProfile = true);
                                },
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => _editingProfile = false),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 4),
                                  _savingProfile
                                      ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
                                      : ElevatedButton(
                                          onPressed: _saveProfile,
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                          child: const Text('Save'),
                                        ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        if (_editingProfile) ...[
                          _buildEditField('Full Name', _nameCtrl, Icons.person_outline),
                          const SizedBox(height: 12),
                          _buildEditField('Department', _deptCtrl, Icons.business_outlined),
                          const SizedBox(height: 12),
                          _buildEditField('Specialization', _specCtrl, Icons.medical_services_outlined),
                        ] else ...[
                          _buildProfileDetail('Email', user?.email ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildProfileDetail('Employee ID', user?.employeeId ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildProfileDetail('Department', user?.department ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildProfileDetail('Specialization', user?.specialization ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildProfileDetail('Current Shift', user?.shift.name ?? 'N/A'),
                          const SizedBox(height: 8),
                          if (user?.shift != null)
                            Text(
                              '${user!.shift.startTime} - ${user.shift.endTime}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.themed(context).textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Account Security ──
                  _buildSectionTitle(context, 'Account Security'),
                  const SizedBox(height: 16),
                  _buildAccountSecurityCard(context, t),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, 'Notification Preferences'),
                  const SizedBox(height: 16),
                  _buildToggleSetting(
                    'Email Notifications',
                    'Receive critical alerts via email in realtime',
                    appProvider.emailNotifications,
                    (value) => appProvider.setEmailNotifications(value),
                  ),
                  // Gmail Alert Config — admin only
                  if (user?.role?.toLowerCase() == 'admin')
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildEmailConfigCard(appProvider, t),
                      ),
                      crossFadeState: appProvider.emailNotifications
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                  const SizedBox(height: 12),
                  _buildToggleSetting(
                    'SMS Notifications',
                    'Receive critical alerts via SMS',
                    appProvider.smsNotifications,
                    (value) => appProvider.setSmsNotifications(value),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Alert Settings'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alert Sensitivity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          _sensitivityDescription(appProvider.alertThreshold),
                          style: TextStyle(fontSize: 12, color: AppColors.themed(context).textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'low', label: Text('Low')),
                              ButtonSegment(value: 'medium', label: Text('Medium')),
                              ButtonSegment(value: 'high', label: Text('High')),
                            ],
                            selected: {appProvider.alertThreshold},
                            onSelectionChanged: (Set<String> newSelection) {
                              appProvider.setAlertThreshold(newSelection.first);
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Alert Thresholds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        _buildAlertThresholdRow('Heart Rate', _heartRateThreshold(appProvider.alertThreshold)),
                        const SizedBox(height: 8),
                        _buildAlertThresholdRow('SpO2', _spo2Threshold(appProvider.alertThreshold)),
                        const SizedBox(height: 8),
                        _buildAlertThresholdRow('Blood Pressure', _bpThreshold(appProvider.alertThreshold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Display Settings'),
                  const SizedBox(height: 16),
                  _buildToggleSetting(
                    'Dark Mode',
                    'Switch between light and dark theme',
                    appProvider.darkMode,
                    (value) => appProvider.setDarkMode(value),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Danger Zone'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    onPressed: () => _showResetDialog(context),
                    child: const Text('Factory Reset'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () => context.read<AuthProvider>().logout(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailConfigCard(AppProvider appProvider, Themed t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Gmail Alert Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: t.textPrimary)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.info.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Emails are sent via Gmail SMTP through a Supabase Edge Function. '
                'Gmail credentials (App Password) are configured securely as server-side secrets — not stored in the app.',
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _emailField('Recipient Email', _alertEmailCtrl, Icons.person_outline, 'doctor@hospital.com', t),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: _savingEmailConfig
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _savingEmailConfig ? null : () async {
                setState(() => _savingEmailConfig = true);
                appProvider.setAlertEmail(_alertEmailCtrl.text.trim());
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) {
                  setState(() => _savingEmailConfig = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Alert email saved'),
                    backgroundColor: AppColors.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ));
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: _testingEmail
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send Test'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _testingEmail ? null : () async {
                setState(() => _testingEmail = true);
                appProvider.setAlertEmail(_alertEmailCtrl.text.trim());
                final ok = await appProvider.sendTestAlertEmail();
                if (mounted) {
                  setState(() => _testingEmail = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Test email sent to ${_alertEmailCtrl.text}!' : 'Failed — check browser console for details'),
                    backgroundColor: ok ? AppColors.accent : AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ));
                }
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Setup (one-time):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '1. Generate a Google App Password at\n   myaccount.google.com/apppasswords\n'
              '2. Install Supabase CLI: npm install -g supabase\n'
              '3. supabase login\n'
              '4. supabase link --project-ref cnktjnchyyttjvslvdpr\n'
              '5. supabase functions deploy send-alert-email\n'
              '6. supabase secrets set GMAIL_USER=you@gmail.com\n'
              '   GMAIL_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx',
              style: TextStyle(fontSize: 10, color: t.textSecondary, fontFamily: 'monospace'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _emailField(String label, TextEditingController ctrl, IconData icon, String hint, Themed t, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(fontSize: 13, color: t.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: t.textSecondary),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.themed(context).textPrimary));
  }

  Widget _buildToggleSetting(String title, String subtitle, bool value, Function(bool) onChanged, {bool enabled = true}) {
    final t = AppColors.themed(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: t.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: t.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildAlertThresholdRow(String label, String threshold) {
    final t = AppColors.themed(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: t.textSecondary)),
        Text(threshold, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: t.textPrimary)),
      ],
    );
  }

  String _sensitivityDescription(String level) {
    switch (level) {
      case 'low':
        return 'Only critical alerts shown — severe vital anomalies';
      case 'high':
        return 'All alerts shown — minor and major vital changes';
      default:
        return 'Critical and warning alerts shown (recommended)';
    }
  }

  String _heartRateThreshold(String level) {
    switch (level) {
      case 'low':    return '< 50 or > 130 bpm';
      case 'high':   return '< 60 or > 100 bpm';
      default:       return '< 55 or > 115 bpm';
    }
  }

  String _spo2Threshold(String level) {
    switch (level) {
      case 'low':    return '< 90%';
      case 'high':   return '< 96%';
      default:       return '< 93%';
    }
  }

  String _bpThreshold(String level) {
    switch (level) {
      case 'low':    return '> 180/110 mmHg';
      case 'high':   return '> 130/85 mmHg';
      default:       return '> 150/95 mmHg';
    }
  }

  Widget _buildProfileDetail(String label, String value) {
    final t = AppColors.themed(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.textPrimary)),
        ),
      ],
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'doctor': return Icons.local_hospital;
      case 'admin':  return Icons.admin_panel_settings;
      case 'nurse':  return Icons.health_and_safety;
      default:       return Icons.person;
    }
  }

  Widget _buildAccountSecurityCard(BuildContext context, dynamic t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: t.primary, size: 20),
              const SizedBox(width: 8),
              Text('Change Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'A confirmation link will be sent to both old and new email addresses.',
            style: TextStyle(fontSize: 12, color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newEmailCtrl,
                  decoration: InputDecoration(
                    hintText: 'New email address',
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Update Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final email = _newEmailCtrl.text.trim();
                  if (email.isEmpty) return;
                  final err = await context.read<AuthProvider>().changeEmail(email);
                  if (!mounted) return;
                  if (err == null) {
                    _newEmailCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Confirmation link sent to both email addresses.'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.lock_outline, color: t.primary, size: 20),
              const SizedBox(width: 8),
              Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _confirmPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Confirm password',
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text('Update Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final pass = _newPassCtrl.text;
                  final confirm = _confirmPassCtrl.text;
                  if (pass.isEmpty) return;
                  if (pass != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  final err = await context.read<AuthProvider>().changePassword(pass);
                  if (!mounted) return;
                  if (err == null) {
                    _newPassCtrl.clear();
                    _confirmPassCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully.'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Factory Reset'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will reset all settings to their defaults:'),
            const SizedBox(height: 12),
            const Text('• Notification preferences', style: TextStyle(fontSize: 13)),
            const Text('• Alert sensitivity (reset to Medium)', style: TextStyle(fontSize: 13)),
            const Text('• Dark mode (reset to Light)', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Text(
              'Your patient data and messages will NOT be deleted.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.themed(ctx).textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<AppProvider>().factoryReset();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Factory reset completed. All settings restored to defaults.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Reset Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
