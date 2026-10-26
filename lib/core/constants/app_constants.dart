class AppConstants {
  static const String appName = 'hitung.';
  static const String appTagline = 'catat duit, tanpa ribet';
  static const String applicationId = 'id.hitung.app';
  static const String appVersion = '2.0.0';
  static const int schemaVersion = 2;

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
}
