import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/top_bar.dart';

class AdminUsersScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const AdminUsersScreen({super.key, this.onNavigate});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AuthProvider>().listAllUsers();
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'all' || role == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.themed(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: t.background,
      child: Column(
        children: [
          TopBar(
            onProfileTap: () {},
            onNavigate: widget.onNavigate,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(t),
                          const SizedBox(height: 24),
                          _buildToolbar(t),
                          const SizedBox(height: 16),
                          _buildUsersTable(t, isMobile),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic t) {
    final total = _users.length;
    final doctors = _users.where((u) => u['role'] == 'doctor').length;
    final nurses = _users.where((u) => u['role'] == 'nurse').length;
    final admins = _users.where((u) => u['role'] == 'admin').length;
    final locked = _users.where((u) => u['is_locked'] == true).length;

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        _statCard(t, 'Total Users', '$total', Icons.people, AppColors.primary),
        _statCard(t, 'Doctors', '$doctors', Icons.local_hospital, Colors.blue),
        _statCard(t, 'Nurses', '$nurses', Icons.health_and_safety, Colors.green),
        _statCard(t, 'Admins', '$admins', Icons.admin_panel_settings, Colors.purple),
        _statCard(t, 'Locked', '$locked', Icons.lock, AppColors.danger),
      ],
    );
  }

  Widget _statCard(dynamic t, String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: t.textPrimary)),
              Text(label, style: TextStyle(fontSize: 11, color: t.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(dynamic t) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search users by name...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: t.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _roleFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                DropdownMenuItem(value: 'nurse', child: Text('Nurses')),
                DropdownMenuItem(value: 'admin', child: Text('Admins')),
              ],
              onChanged: (v) => setState(() => _roleFilter = v ?? 'all'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, color: t.primary),
          onPressed: _loadUsers,
        ),
      ],
    );
  }

  Widget _buildUsersTable(dynamic t, bool isMobile) {
    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.person_off, size: 48, color: t.textSecondary),
              const SizedBox(height: 12),
              Text('No users found', style: TextStyle(fontSize: 16, color: t.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: users.map((u) => _buildUserCard(t, u)).toList(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width < 768 ? 32 : 300)),
            child: DataTable(
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
          headingRowColor: WidgetStateProperty.all(t.primary.withOpacity(0.06)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: users.map((u) {
            final isLocked = u['is_locked'] == true;
            final role = (u['role'] ?? 'unknown').toString();
            return DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: u['photo_url'] != null ? NetworkImage(u['photo_url']) : null,
                    child: u['photo_url'] == null ? Text((u['full_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 14)) : null,
                  ),
                  const SizedBox(width: 10),
                  Text(u['full_name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary)),
                ],
              )),
              DataCell(Text(u['email'] ?? '—', style: TextStyle(color: t.textSecondary, fontSize: 13))),
              DataCell(_buildRoleBadge(role)),
              DataCell(Text(u['department'] ?? '—', style: TextStyle(color: t.textSecondary))),
              DataCell(Text(u['employee_id'] ?? '—', style: TextStyle(color: t.textSecondary))),
              DataCell(_buildStatusBadge(isLocked)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionBtn(
                    icon: isLocked ? Icons.lock_open : Icons.lock,
                    label: isLocked ? 'Unlock' : 'Lock',
                    color: isLocked ? Colors.green : AppColors.danger,
                    onTap: () => _toggleLock(u, isLocked),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.password,
                    label: 'Reset Password',
                    color: Colors.orange,
                    onTap: () => _sendReset(u),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic t, Map<String, dynamic> u) {
    final isLocked = u['is_locked'] == true;
    final role = (u['role'] ?? 'unknown').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLocked ? AppColors.danger.withOpacity(0.3) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: u['photo_url'] != null ? NetworkImage(u['photo_url']) : null,
                child: u['photo_url'] == null ? Text((u['full_name'] ?? '?')[0].toUpperCase()) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['full_name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: t.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildRoleBadge(role),
                        const SizedBox(width: 8),
                        _buildStatusBadge(isLocked),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Dept: ${u['department'] ?? '—'}  |  ID: ${u['employee_id'] ?? '—'}', style: TextStyle(fontSize: 12, color: t.textSecondary)),
          const SizedBox(height: 12),
          _buildActionButtons(u, isLocked),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    IconData icon;
    switch (role.toLowerCase()) {
      case 'doctor':
        color = Colors.blue;
        icon = Icons.local_hospital;
        break;
      case 'admin':
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        break;
      case 'nurse':
        color = Colors.green;
        icon = Icons.health_and_safety;
        break;
      default:
        color = Colors.grey;
        icon = Icons.person;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(role[0].toUpperCase() + role.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isLocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLocked ? AppColors.danger.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLocked ? Icons.lock : Icons.check_circle, size: 13, color: isLocked ? AppColors.danger : Colors.green),
          const SizedBox(width: 4),
          Text(isLocked ? 'Locked' : 'Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLocked ? AppColors.danger : Colors.green)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> u, bool isLocked) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionBtn(
          icon: isLocked ? Icons.lock_open : Icons.lock,
          label: isLocked ? 'Unlock' : 'Lock',
          color: isLocked ? Colors.green : AppColors.danger,
          onTap: () => _toggleLock(u, isLocked),
        ),
        _actionBtn(
          icon: Icons.password,
          label: 'Reset Password',
          color: Colors.orange,
          onTap: () => _sendReset(u),
        ),
      ],
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLock(Map<String, dynamic> u, bool currentlyLocked) async {
    final name = u['full_name'] ?? 'this user';
    final action = currentlyLocked ? 'unlock' : 'lock';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Account'),
        content: Text('Are you sure you want to $action the account for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentlyLocked ? Colors.green : AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action[0].toUpperCase() + action.substring(1), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final err = await context.read<AuthProvider>().toggleUserLock(u['id'], !currentlyLocked);
    if (!mounted) return;
    if (err == null) {
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account ${currentlyLocked ? 'unlocked' : 'locked'} successfully.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  Future<void> _sendReset(Map<String, dynamic> u) async {
    final name = u['full_name'] ?? 'this user';
    final email = u['email']?.toString();
    
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found for this user.'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Password Reset'),
        content: Text('Send a password reset email to $name ($email)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final err = await context.read<AuthProvider>().adminResetUserPassword(email);
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $name.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

}
