# St. Dominic Health Monitoring System - Login & Signup Guide

## Overview
The app now includes a complete authentication system with role-based access for **Doctors** and **Nurses** at St. Dominic hospital, including shift management.

## User Roles & Departments

### Doctors
- Can access full patient monitors and medical records
- Department: Cardiology, Emergency, Surgery, etc.
- Specialization: e.g., Pediatrics, Interventional Cardiology
- Employee ID: DOC###

### Nurses
- Can access patient vitals and care notes
- Department: General Ward, ICU, Emergency
- Certification: e.g., Registered Nurse, Critical Care
- Employee ID: NUR###

## Shift System (St. Dominic)
All staff are assigned to one of three shifts:

1. **Morning Shift**: 6:00 AM - 2:00 PM
2. **Afternoon Shift**: 2:00 PM - 10:00 PM
3. **Night Shift**: 10:00 PM - 6:00 AM

## Test Credentials

### Doctor Account
```
Email: doctor.smith@stdominic.com
Password: doctor123
Name: Dr. Smith Johnson
Role: Doctor
Department: Cardiology
Specialization: Interventional Cardiology
Employee ID: DOC001
Shift: Morning Shift (6:00 AM - 2:00 PM)
```

### Nurse Account
```
Email: nurse.maria@stdominic.com
Password: nurse123
Name: Maria Santos
Role: Nurse
Department: General Ward
Specialization: Registered Nurse
Employee ID: NUR001
Shift: Afternoon Shift (2:00 PM - 10:00 PM)
```

## User Flow

### Login Screen
1. Enter email address
2. Enter password
3. Click "Login"
4. System validates credentials against the database
5. If successful, navigates to dashboard
6. If failed, displays error message
7. New users can click "Sign Up" link

### Signup Screen
1. Fill in full name
2. Enter email address
3. Enter employee/staff ID
4. Select role (Doctor or Nurse)
5. Select department
6. Enter specialization/certification
7. Select shift (Morning, Afternoon, or Night)
8. Create password (minimum 8 characters)
9. Confirm password
10. Click "Create Account"
11. After successful signup, auto-logged in and redirected to dashboard

### User Profile (Settings Screen)
- View complete profile information
- See current role and shift details
- View department and specialization
- Manage notification preferences
- Configure alert settings
- Logout option

## Features Implemented

### Authentication
✅ Email-based login with password validation
✅ Signup with full staff details
✅ Password strength validation (minimum 8 characters)
✅ Email format validation
✅ Duplicate email prevention
✅ Auto-login after signup
✅ Persistent user session

### User Model Enhanced
✅ Role-based access (Doctor/Nurse)
✅ Department assignment
✅ Specialization/Certification
✅ Employee ID tracking
✅ Shift assignment with times
✅ Account creation timestamp

### UI/UX
✅ Professional login screen
✅ Comprehensive signup form
✅ Error message display
✅ Loading states
✅ Password visibility toggle
✅ Shift selection with time display
✅ Role-based icons and colors
✅ Profile information display

## Future Enhancements

- [ ] Database integration (Firebase/Backend API)
- [ ] Password reset functionality
- [ ] Two-factor authentication
- [ ] Staff schedule management
- [ ] Shift swapping/scheduling
- [ ] Role-based feature access
- [ ] Device linking per staff member
- [ ] Activity logging and audit trail

## File Structure

```
lib/
├── models/
│   ├── user.dart (Enhanced with new fields)
│   └── shift.dart (New - shift management)
├── providers/
│   └── auth_provider.dart (Updated with signup logic)
├── screens/
│   ├── login_screen.dart (Updated with signup link)
│   ├── signup_screen.dart (New - signup form)
│   └── settings_screen.dart (Updated with profile display)
└── main.dart (Updated with signup route)
```

## Notes

- Currently using mock database in AuthProvider
- All credentials are stored locally (use backend API for production)
- Shift times are St. Dominic standards
- Role-based features can be implemented in individual screens
- Error messages are displayed to guide users
