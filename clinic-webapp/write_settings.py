#!/usr/bin/env python3
"""Helper script to write the settings_screen.dart file cleanly."""
import os

target = r"d:\School\IOT Smart Watch\clinic-webapp\lib\screens\settings_screen.dart"

content = r"""import 'package:flutter/material.dart';
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
  final bool _darkMode = false;

  bool _editingProfile = false;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _specCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _deptCtrl = TextEditingController(text: user?.department ?? '');
    _specCtrl = TextEditingController(text: user?.specialization ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _specCtrl.dispose();
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
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('Profile Information'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.divider),
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
                                                  user.role == 'doctor' ? Icons.local_hospital : Icons.health_and_safety,
                                                  size: 40,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : Icon(
                                                user?.role == 'doctor' ? Icons.local_hospital : Icons.health_and_safety,
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
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: user?.role == 'doctor'
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      user?.role == 'doctor' ? 'Doctor' : 'Nurse',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: user?.role == 'doctor'
                                            ? Colors.blue.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
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
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('Notification Preferences'),
                  const SizedBox(height: 16),
                  _buildToggleSetting(
                    'Email Notifications',
                    'Receive alerts via email',
                    appProvider.emailNotifications,
                    (value) => appProvider.setEmailNotifications(value),
                  ),
                  const SizedBox(height: 12),
                  _buildToggleSetting(
                    'SMS Notifications',
                    'Receive critical alerts via SMS',
                    appProvider.smsNotifications,
                    (value) => appProvider.setSmsNotifications(value),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Alert Settings'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alert Sensitivity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'low', label: Text('Low')),
                            ButtonSegment(value: 'medium', label: Text('Medium')),
                            ButtonSegment(value: 'high', label: Text('High')),
                          ],
                          selected: {appProvider.alertThreshold},
                          onSelectionChanged: (Set<String> newSelection) {
                            appProvider.setAlertThreshold(newSelection.first);
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text('Alert Thresholds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        _buildAlertThresholdRow('Heart Rate', '60-100 bpm'),
                        const SizedBox(height: 8),
                        _buildAlertThresholdRow('SpO2', '95-100%'),
                        const SizedBox(height: 8),
                        _buildAlertThresholdRow('Blood Pressure', '120/80 mmHg'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Display Settings'),
                  const SizedBox(height: 16),
                  _buildToggleSetting('Dark Mode', 'Coming soon', _darkMode, (value) {}, enabled: false),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Danger Zone'),
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }

  Widget _buildToggleSetting(String title, String subtitle, bool value, Function(bool) onChanged, {bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null, activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildAlertThresholdRow(String label, String threshold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(threshold, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text('This will reset all settings to default. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().factoryReset();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Factory reset completed.'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
"""

with open(target, 'w', encoding='utf-8') as f:
    f.write(content)

import os
print(f"Written: {os.path.getsize(target)} bytes, {content.count(chr(10))} lines")
