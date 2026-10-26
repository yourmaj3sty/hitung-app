# HITUNG (v1.0.0) 📱
> **Pencatat Pengeluaran** • 100% On-Device / Offline-First Personal Finance App

Aplikasi pencatatan keuangan pribadi modern berbasis **Flutter**, dibangun secara khusus untuk platform **Android & iOS** dengan arsitektur **100% Offline-First** (Zero Cloud Dependency, Tanpa Login/Akun, Nol Penggunaan Backend Eksternal).

---

## 💎 Identitas Brand & Logo
- **Application ID / Bundle ID**: `id.hitung.app`
- **Tagline**: Pencatat Pengeluaran
- **Default Locale & Mata Uang**: `id_ID` | Rupiah (`Rp`, bilangan bulat tanpa desimal `,00`)
- **Visual Logo**:
  - Container Squircle gelap (`#14161B`) dengan border halus (`#232730`, 1.5px).
  - Monogram "H" dengan tiang kiri Emerald Green (`#10B981`, tanda `+`), tiang kanan Coral Red (`#F43F5E`, tanda `-`), pita tengah putih (`#FFFFFF`, simbol `+/-`), serta titik presisi Warm Orange (`#F97316`).

---

## 🛡️ Kepatuhan Terhadap Strict Technical Rules

1. **No External Backend**: Seluruh data disimpan dan diproses secara lokal di perangkat. Tidak ada package jaringan/cloud (Nol Firebase, Supabase, Dio, Http).
2. **Integer-Only Financial Math**: Seluruh nilai uang di database SQLite dan memori bertipe `int` (Rupiah penuh). Tidak ada floating point error `double` untuk kalkulasi saldo.
3. **Tabular Figures Mandatory**: Setiap teks yang merender angka atau nominal `Rp` dilengkapi `fontFeatures: [FontFeature.tabularFigures()]` untuk perataan angka monospaced yang rapi.
4. **ACID Database Transactions**: Setiap penambahan, penghapusan, dan pemulihan transaksi dibungkus dalam `db.transaction(() async { ... })` yang memperbarui saldo dompet terkait secara atomik.
5. **No Hard Delete on Referenced Entities**: Dompet dan Kategori yang digunakan hanya menggunakan *soft delete* (`isArchived = true` atau `isDeleted = true`).

---

## 🚀 Fitur Lengkap Sesuai PRD

| ID | Fitur | Deskripsi |
| :--- | :--- | :--- |
| **FR-01** | **Zero-Login Onboarding** | Pengguna langsung masuk tanpa registrasi. Input nama dompet utama & saldo awal, serta otomatis *seeding* 10 kategori bawaan (7 Pengeluaran, 3 Pemasukan). |
| **FR-02** | **3-Tap Quick Entry** | Tombol `+` membuka Modal Bottom Sheet setinggi 85% layar. Dilengkapi Custom Numpad dengan tombol `000`, batas 12 digit (Rp 999.999.999.999), dan tombol Simpan aktif hanya jika nominal > 0. |
| **FR-03** | **Multi-Wallet & Transfer** | Pisahkan saldo Tunai, Bank, dan E-Wallet. Mode `TRANSFER` memvalidasi `Dompet Asal != Dompet Tujuan`, mengurangi saldo asal & menambah saldo tujuan tanpa dihitung sebagai pengeluaran/pemasukan bulanan. |
| **FR-04** | **Reactive Dashboard** | Filter interaktif Bulan & Tahun (`< Oktober 2026 >`) serta filter dompet (`Semua Dompet` atau spesifik). Menampilkan Total Saldo, Pemasukan, dan Pengeluaran. Riwayat harian dengan subtotal, serta *Swipe-to-delete* dengan SnackBar `Urungkan (Undo)` selama 4 detik. |
| **FR-05** | **Budgeting System** | Pengaturan batas anggaran bulanan Global dan per Kategori. Dilengkapi indikator warna: Hijau (`<80%`), Oranye `#F97316` (`80%-99%`), dan Merah `#F43F5E` (`>=100%`). |
| **FR-06** | **Analytics & Charts** | Donut Chart interaktif (`fl_chart`) dengan persentase tiap kategori. Ketuk irisan untuk menyorot detail, serta kartu perbandingan pengeluaran bulan ini vs bulan lalu. |
| **FR-07** | **JSON/CSV Backup & Restore** | Ekspor cadangan lengkap `.json` untuk dipulihkan kembali secara atomik dengan validasi `schemaVersion`, serta ekspor `.csv` yang kompatibel dengan Microsoft Excel dan Google Sheets. |
| **FR-08** | **Biometric Lock** | Proteksi privasi menggunakan Face ID / Fingerprint (`local_auth`). Layar kunci otomatis muncul setiap kali aplikasi dibuka kembali (`AppLifecycleState.resumed`). |

---

## 🛠️ Tech Stack & Packages

- **Framework**: Flutter 3.47+ & Dart 3.13+
- **State Management**: `flutter_riverpod: ^2.5.1`
- **Database (SQLite ORM)**: `drift: ^2.18.0`, `sqlite3_flutter_libs: ^0.5.24`, `path_provider: ^2.1.3`, `path: ^1.9.0`
- **UI & Typography**: `google_fonts: ^6.2.1` (Plus Jakarta Sans), `lucide_icons: ^0.257.0`, `fl_chart: ^0.68.0`
- **Utilities & Native APIs**: `intl: ^0.20.3`, `uuid: ^4.4.0`, `shared_preferences: ^2.2.3`, `share_plus: ^9.0.0`, `file_picker: ^8.0.5`, `local_auth: ^2.2.0`
- **Code Generator**: `build_runner: ^2.4.11`, `drift_dev: ^2.18.0`

---

## 📂 Struktur Direktori Proyek

```
d:/Project Hitung/
├── android/                         # Konfigurasi Android (id.hitung.app, minSdk 26)
├── ios/                             # Konfigurasi iOS (id.hitung.app, iOS 15.0)
├── lib/
│   ├── main.dart                    # App entry, ProviderScope, Lifecycle Biometric observer
│   ├── core/
│   │   ├── constants/               # Warna brand (AppColors) & Konstanta (AppConstants)
│   │   ├── database/                # Drift SQLite ORM, Tables, ACID mutations, SeedData
│   │   ├── providers/               # DatabaseProvider & StreamProviders
│   │   ├── theme/                   # AppTheme dark mode & Plus Jakarta Sans
│   │   └── utils/                   # CurrencyFormatter, DateFormatter, IconHelper
│   ├── features/
│   │   ├── onboarding/              # FR-01: Zero-Login Onboarding
│   │   ├── quick_entry/             # FR-02: 3-Tap Quick Entry Modal + Numpad '000'
│   │   ├── wallets/                 # FR-03: Multi-Wallet & Transfer
│   │   ├── dashboard/               # FR-04: Reactive Dashboard, Daily Groups, Undo
│   │   ├── budgeting/               # FR-05: Budgeting System (<80%, 80-99%, >=100%)
│   │   ├── analytics/               # FR-06: Donut Chart & MoM Comparison
│   │   ├── backup_restore/          # FR-07: JSON Backup & CSV Export
│   │   ├── settings/                # FR-08: Biometric Lock & Settings
│   │   └── navigation/              # Bottom navigation shell with central FAB
│   └── shared/
│       └── widgets/                 # AppLogo visual, FormattedAmountText, EmptyState
├── test/
│   └── unit/
│       ├── financial_math_test.dart # Pengujian aritmatika integer & saldo
│       ├── currency_formatter_test.dart # Pengujian format Rupiah & tabular figures
│       └── database_acid_test.dart  # Pengujian mutasi atomik SQLite & soft delete
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 🧪 Menjalankan Pengujian Otomatis (Testing)

Untuk menjalankan seluruh rangkaian unit test:
```powershell
flutter test
```

Untuk menjalankan analisis statis kode (Linter):
```powershell
flutter analyze
```

---

## 📦 Tahap Menuju Go-Live (Release Build)

### 1. Build APK Android
```powershell
flutter build apk --release
```

### 2. Build App Bundle (Google Play Store)
```powershell
flutter build appbundle --release
```

### 3. Build iOS (Apple App Store)
```bash
flutter build ipa --release
```
