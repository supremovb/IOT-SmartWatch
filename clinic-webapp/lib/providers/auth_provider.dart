import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_user;
import '../models/shift.dart';

class AuthProvider extends ChangeNotifier {
  /// Set by main() BEFORE the provider is constructed. True when the
  /// URL hash contained type=recovery (user clicked a reset-password link).
  static bool pendingRecovery = false;

  app_user.User? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  bool _needsEmailConfirmation = false;
  bool _isPasswordRecovery = false;
  String? _errorMessage;

  final _supabase = Supabase.instance.client;

  // Getters
  app_user.User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitializing => _isInitializing;
  bool get needsEmailConfirmation => _needsEmailConfirmation;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initSession();
  }

  // Restore session on app start (handles page refresh on web)
  Future<void> _initSession() async {
    // If main() detected a recovery link, enter recovery mode immediately.
    if (pendingRecovery) {
      pendingRecovery = false; // consume the flag
      _isPasswordRecovery = true;
      _isLoggedIn = false;
      _isInitializing = false;
      notifyListeners();

      // Still listen for future events (signOut, etc.)
      _supabase.auth.onAuthStateChange.listen((state) async {
        if (state.event == AuthChangeEvent.signedOut) {
          _user = null;
          _isLoggedIn = false;
          _isPasswordRecovery = false;
          notifyListeners();
        }
      });
      return;
    }

    bool firstEventReceived = false;

    _supabase.auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _isLoggedIn = false;
        _user = null;
        _isInitializing = false;
        notifyListeners();
      } else if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        if (_isPasswordRecovery) return;

        if (state.session?.user != null &&
            (_user == null || _user!.id != state.session!.user.id)) {
          await _fetchAndSetUser(state.session!.user);
        }
        if (!firstEventReceived) {
          firstEventReceived = true;
          _isInitializing = false;
          notifyListeners();
        }
      } else if (state.event == AuthChangeEvent.signedOut) {
        _user = null;
        _isLoggedIn = false;
        _isPasswordRecovery = false;
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  // Shared helper: fetch profile from Supabase and populate _user
  Future<void> _fetchAndSetUser(User supabaseUser) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      final shift = ShiftSchedule.getShiftById(
              profile?['shift_id'] ?? 'morning') ??
          ShiftSchedule.stDominicShifts[0];

      _user = app_user.User(
        id: supabaseUser.id,
        email: supabaseUser.email ?? '',
        name: profile?['full_name'] ?? supabaseUser.email ?? '',
        role: profile?['role'] ?? 'nurse',
        department: profile?['department'] ?? '',
        specialization: profile?['specialization'] ?? '',
        employeeId: profile?['employee_id'] ?? '',
        shift: shift,
        photoUrl: profile?['photo_url'],
        loginTime: DateTime.now(),
        createdAt: DateTime.tryParse(supabaseUser.createdAt) ?? DateTime.now(),
      );
      // Guard: if a passwordRecovery event arrived while we were fetching
      // the profile, do NOT mark the user as logged in.
      if (_isPasswordRecovery) return;
      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  // Validate password strength
  bool _isValidPassword(String password) {
    // At least 8 characters
    return password.length >= 8;
  }

  // Login method
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validation
      if (email.trim().isEmpty || password.isEmpty) {
        _errorMessage = 'Email and password are required';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidEmail(email)) {
        _errorMessage = 'Invalid email format';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userEmail = email.trim().toLowerCase();

      // Authenticate with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: userEmail,
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Login failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Fetch user profile from profiles table
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      // Check if account is locked
      if (profile?['is_locked'] == true) {
        await _supabase.auth.signOut();
        _errorMessage = 'Your account has been locked. Please contact an administrator.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final shift = ShiftSchedule.getShiftById(
              profile?['shift_id'] ?? 'morning') ??
          ShiftSchedule.stDominicShifts[0];

      _user = app_user.User(
        id: response.user!.id,
        email: userEmail,
        name: profile?['full_name'] ?? userEmail,
        role: profile?['role'] ?? 'nurse',
        department: profile?['department'] ?? '',
        specialization: profile?['specialization'] ?? '',
        employeeId: profile?['employee_id'] ?? '',
        shift: shift,
        photoUrl: profile?['photo_url'],
        loginTime: DateTime.now(),
        createdAt: DateTime.tryParse(
                response.user!.createdAt) ??
            DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Signup method
  Future<bool> signup({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required String role,
    required String department,
    required String specialization,
    required String employeeId,
    required String shiftId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validation
      if (email.trim().isEmpty ||
          password.isEmpty ||
          fullName.isEmpty ||
          role.isEmpty ||
          department.isEmpty ||
          employeeId.isEmpty ||
          shiftId.isEmpty) {
        _errorMessage = 'All fields are required';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidEmail(email)) {
        _errorMessage = 'Invalid email format';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidPassword(password)) {
        _errorMessage = 'Password must be at least 8 characters';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password != confirmPassword) {
        _errorMessage = 'Passwords do not match';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userEmail = email.trim().toLowerCase();

      // Get shift object
      final shift = ShiftSchedule.getShiftById(shiftId);
      if (shift == null) {
        _errorMessage = 'Invalid shift selected';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate role
      if (role != 'doctor' && role != 'nurse') {
        _errorMessage = 'Invalid role selected';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Register with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: userEmail,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          'department': department,
          'specialization': specialization,
          'employee_id': employeeId,
          'shift_id': shiftId,
        },
      );

      if (response.user == null) {
        _errorMessage = 'Signup failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // If no session, email confirmation is required — trigger handled profile creation.
      // If session exists (email confirmation disabled), run client-side upsert as fallback.
      if (response.session != null) {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
          'role': role,
          'department': department,
          'specialization': specialization,
          'employee_id': employeeId,
          'shift_id': shiftId,
        });

        // Auto-login only when session is immediately available
        _user = app_user.User(
          id: response.user!.id,
          email: userEmail,
          name: fullName,
          role: role,
          department: department,
          specialization: specialization,
          employeeId: employeeId,
          shift: shift,
          photoUrl: null,
          loginTime: DateTime.now(),
          createdAt: DateTime.now(),
        );
        _isLoggedIn = true;
        _needsEmailConfirmation = false;
      } else {
        // Email confirmation required — user must verify before logging in
        _needsEmailConfirmation = true;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Signup failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Send password reset email via Supabase
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (email.trim().isEmpty) {
        _errorMessage = 'Email is required';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidEmail(email.trim())) {
        _errorMessage = 'Invalid email format';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'http://localhost:3000/?recovery=true',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update password (called from reset-password screen after recovery link click)
  Future<bool> updatePassword(String newPassword) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      _isPasswordRecovery = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update password: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update profile method
  Future<bool> updateProfile({
    String? name,
    String? department,
    String? specialization,
    String? photoUrl,
  }) async {
    if (_user == null) return false;
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['full_name'] = name;
      if (department != null) updates['department'] = department;
      if (specialization != null) updates['specialization'] = specialization;
      if (photoUrl != null) updates['photo_url'] = photoUrl;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', _user!.id);

      _user = app_user.User(
        id: _user!.id,
        email: _user!.email,
        name: name ?? _user!.name,
        role: _user!.role,
        department: department ?? _user!.department,
        specialization: specialization ?? _user!.specialization,
        employeeId: _user!.employeeId,
        shift: _user!.shift,
        photoUrl: photoUrl ?? _user!.photoUrl,
        loginTime: _user!.loginTime,
        createdAt: _user!.createdAt,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Change email (sends confirmation to new email)
  Future<String?> changeEmail(String newEmail) async {
    try {
      if (!_isValidEmail(newEmail)) return 'Invalid email format';
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail.trim().toLowerCase()),
        emailRedirectTo: 'http://localhost:3000/',
      );
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to change email: $e';
    }
  }

  // Change password (requires current session)
  Future<String?> changePassword(String newPassword) async {
    try {
      if (!_isValidPassword(newPassword)) {
        return 'Password must be at least 8 characters';
      }
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to change password: $e';
    }
  }

  // Admin: list all users with email (uses SECURITY DEFINER function)
  Future<List<Map<String, dynamic>>> listAllUsers() async {
    final data = await _supabase.rpc('get_users_with_email');
    return List<Map<String, dynamic>>.from(data);
  }

  // Admin: toggle user lock (uses SECURITY DEFINER function)
  Future<String?> toggleUserLock(String userId, bool lock) async {
    try {
      await _supabase.rpc('admin_toggle_user_lock', params: {
        'target_user_id': userId,
        'lock_status': lock,
      });
      return null;
    } catch (e) {
      return 'Failed to ${lock ? 'lock' : 'unlock'} user: $e';
    }
  }

  // Admin: reset a user's password (sends reset email)
  Future<String?> adminResetUserPassword(String userEmail) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        userEmail,
        redirectTo: 'http://localhost:3000/?recovery=true',
      );
      return null;
    } catch (e) {
      return 'Failed to send reset email: $e';
    }
  }
}
