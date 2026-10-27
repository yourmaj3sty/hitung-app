class AppConstants {
  static const String appName = 'hitung.';
  static const String appTagline = 'catat duit, tanpa ribet';
  static const String applicationId = 'id.hitung.app';
  static const String appVersion = '2.0.0';
  static const int schemaVersion = 4;

  // Formatting & Financial Constraints
  static const String currencySymbol = 'Rp';
  static const String defaultLocale = 'id_ID';
  static const int maxInputDigits = 12; // Rp 999.999.999.999
  static const int maxInputAmount = 999999999999;
  static const int maxNameLength = 50; // Batas kolom nama dompet/kategori di database

  // Preferences Keys
  static const String prefIsOnboarded = 'is_onboarded';
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefLastUsedWalletId = 'last_used_wallet_id';
  static const String prefGlobalMonthlyBudget = 'global_monthly_budget';
  static const String prefSelectedTabFilter = 'selected_tab_filter'; // 'ALL', 'DAILY', 'SAVINGS'

  // New Keys v2.1
  static const String prefThemeMode = 'app_theme_mode'; // 'system', 'light', 'dark'
  static const String prefAppPin = 'app_security_pin';
  static const String prefPinEnabled = 'pin_security_enabled';
  static const String prefPinFailedCount = 'pin_failed_count';
  static const String prefPinLockedUntil = 'pin_locked_until_ms';
  static const String prefDailyReminderEnabled = 'daily_reminder_enabled';
  static const String prefDailyReminderHour = 'daily_reminder_hour';
  static const String prefDailyReminderMinute = 'daily_reminder_minute';
  static const String prefBudgetAlertEnabled = 'budget_alert_enabled';
  static const String prefAutoBackupEnabled = 'auto_backup_enabled';
  static const String prefLastAutoBackupTime = 'last_auto_backup_time';
  static const String prefPrivacyScreenEnabled = 'privacy_screen_enabled';
}
