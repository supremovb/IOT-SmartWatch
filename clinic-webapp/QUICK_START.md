# Quick Start Guide - Login & Signup UI

## 🚀 Getting Started

### First Time Users - Sign Up

1. **Launch App** → You'll see the Login Screen
2. **Click "Sign Up"** → Navigate to Signup Screen
3. **Fill in Details:**
   - Full Name (e.g., "John Smith")
   - Email (e.g., "john.smith@stdominic.com")
   - Employee ID (e.g., "DOC001")
   - Select Role: Doctor **OR** Nurse
   - Department (e.g., "Cardiology")
   - Specialization (e.g., "Surgery" for doctors, "RN" for nurses)
   - Select Shift:
     - 🌅 Morning (6:00 AM - 2:00 PM)
     - 🌤️ Afternoon (2:00 PM - 10:00 PM)
     - 🌙 Night (10:00 PM - 6:00 AM)
   - Password (minimum 8 characters)
   - Confirm Password
4. **Click "Create Account"**
5. ✅ **Automatically logged in** → See Dashboard

---

## 🔐 Returning Users - Login

**Quick Test Credentials:**

### Doctor Account
```
Email:    doctor.smith@stdominic.com
Password: doctor123
```

### Nurse Account
```
Email:    nurse.maria@stdominic.com
Password: nurse123
```

**Login Steps:**
1. Enter email
2. Enter password
3. Toggle password visibility if needed
4. Optional: Check "Remember me"
5. Click "Login"
6. ✅ Access dashboard as logged-in user

---

## 👤 View Your Profile

**After Login:**
1. Navigate to **Settings**
2. Scroll to **"Profile Information"** section
3. See your:
   - Name & Role badge
   - Email address
   - Employee ID
   - Department
   - Specialization/Certification
   - **Current Shift** with times (e.g., "Morning Shift - 6:00 AM - 2:00 PM")

---

## ⚠️ Error Messages & Solutions

| Error | Solution |
|-------|----------|
| "All fields are required" | Fill in every field on the form |
| "Invalid email format" | Use format: name@stdominic.com |
| "Password must be at least 8 characters" | Create password with 8+ characters |
| "Passwords do not match" | Retype on confirm password field |
| "This email is already registered" | Use a different email address |
| "Invalid shift selected" | Choose one of the 3 available shifts |
| "User not found. Please sign up first." | Create new account or check email |
| "Invalid password" | Verify password is correct (case-sensitive) |

---

## 🔄 User Flow Diagram

```
App Launch
    ↓
┌─────────────────────┐
│ Logged In?          │
└─────────────────────┘
    ↙          ↘
  YES          NO
  ↓            ↓
MAIN     LOGIN SCREEN
SCREEN        ↓
          ┌───────────────────────┐
          │ Have Account?         │
          └───────────────────────┘
               ↙         ↘
             YES          NO
              ↓            ↓
           LOGIN      SIGN UP
           (Email)    (Full Form)
           (Password)     ↓
              ↓       Enter All Data
              ↓       Select Role
              ↓       Select Shift
              ↓       Create Account
              └────────↓────────┘
                      ↓
              ✅ AUTO-LOGGED IN
                      ↓
                 MAIN SCREEN
```

---

## 📋 Role-Based Info

### 👨‍⚕️ **Doctor**
- **Department**: Cardiology, Surgery, Emergency, etc.
- **Specialization**: Pediatrics, Interventional, etc.
- **Employee ID Format**: DOC### (e.g., DOC001)
- **Access**: Full patient records, medical data, prescriptions

### 👩‍⚕️ **Nurse**  
- **Department**: General Ward, ICU, Emergency, etc.
- **Specialization**: Registered Nurse, Critical Care, etc.
- **Employee ID Format**: NUR### (e.g., NUR001)
- **Access**: Patient vitals, care notes, observations

---

## ⏰ Shift Times

All shifts at **St. Dominic Hospital:**

| Shift | Times | Duration |
|-------|-------|----------|
| 🌅 Morning | 6:00 AM - 2:00 PM | 8 hours |
| 🌤️ Afternoon | 2:00 PM - 10:00 PM | 8 hours |
| 🌙 Night | 10:00 PM - 6:00 AM | 8 hours |

---

## 🔓 Logout

1. Go to **Settings**
2. Scroll to bottom
3. Click **"Logout"** button
4. Return to Login Screen
5. Login again or let new user signup

---

## 💾 Account Created Successfully

When your profile is created, it stores:
- ✅ Your name and email
- ✅ Employee ID  
- ✅ Role (Doctor/Nurse)
- ✅ Department
- ✅ Specialization
- ✅ Assigned shift
- ✅ Account creation date

---

## 🛡️ Security Notes

- **Passwords**: Case-sensitive, minimum 8 characters
- **Email**: Must be unique (one account per email)
- **Session**: Maintained while app is running
- **Logout**: Clears session data

---

## ❓ Troubleshooting

**Can't login?**
- Verify email spelling (case-insensitive)
- Check password (case-sensitive)
- Confirm account exists (signup if needed)

**Forgot password?**
- Contact administrator (password reset coming soon)
- Or create new account with different email

**Wrong shift assigned?**
- Contact HR/Manager to update shift
- Feature coming soon

**Need to change details?**
- Logout and create new account
- Profile editing coming soon

---

## 📱 Responsive Design

✅ Works on all screen sizes:
- **Desktop**: Full professional layout
- **Tablet**: Optimized form display
- **Mobile**: Touch-friendly buttons and inputs

---

## 🎨 Visual Design

- **Primary Color**: Red (#DC2626)
- **Doctor Badge**: Blue
- **Nurse Badge**: Green
- **Role Icons**: 
  - Doctor: 🏥 Hospital icon
  - Nurse: 🏥 Medical icon
- **Shift Times**: Displayed in 24-hour format (HH:MM)

---

**Version**: 1.0  
**Last Updated**: April 2, 2026  
**Institution**: St. Dominic Health Monitoring System
