import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/rupiah_input_formatter.dart';
import '../../../core/constants/institution_presets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/institution_dropdown_picker.dart';
import '../providers/wallet_provider.dart';
import '../../../core/utils/color_utils.dart';

class WalletFormSheet extends ConsumerStatefulWidget {
  final Wallet? walletToEdit;
  final bool initialIsSavings;

  const WalletFormSheet({
    super.key,
    this.walletToEdit,
    this.initialIsSavings = false,
  });

  static Future<void> show(
    BuildContext context, {
    Wallet? walletToEdit,
    bool initialIsSavings = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletFormSheet(
        walletToEdit: walletToEdit,
        initialIsSavings: initialIsSavings,
      ),
    );
  }

  @override
  ConsumerState<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<WalletFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _targetController;

  late String _walletType; // 'BANK', 'E_WALLET', 'SAVINGS', 'CASH'
  late String _selectedInstitutionCode;
  late String _selectedIcon;
  late String _selectedColor;
  String? _errorText;
  bool _isSaving = false;

  final List<String> _colors = [
    '#00AED6', // GoPay Cyan Blue
    '#00AA13', // Gojek Green
    '#3B82F6', // Blue
    '#FF8A00', // Orange / Jago
    '#8B5CF6', // Purple / OVO
    '#F04438', // Coral Red / ShopeePay
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.walletToEdit;

    if (w != null) {
      _walletType = w.walletType;
      _selectedInstitutionCode = w.institutionCode;
      _nameController = TextEditingController(text: w.name);
      _balanceController = TextEditingController(
        text: CurrencyFormatter.format(w.currentBalance, includeSymbol: false),
      );
      _targetController = TextEditingController(
        text: w.targetAmount != null
            ? CurrencyFormatter.format(w.targetAmount!, includeSymbol: false)
            : '',
      );
      _selectedIcon = w.iconName;
      _selectedColor = w.colorHex;
    } else {
      _walletType = widget.initialIsSavings ? 'SAVINGS' : 'E_WALLET';
      _selectedInstitutionCode = widget.initialIsSavings ? 'GOPAY' : 'CUSTOM';
      _nameController = TextEditingController();
      _balanceController = TextEditingController(text: '0');
      _targetController = TextEditingController();
      _selectedIcon = widget.initialIsSavings ? 'piggy-bank' : 'wallet';
      _selectedColor = widget.initialIsSavings ? '#00AED6' : '#00AA13';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _selectInstitution(InstitutionPreset preset) {
    setState(() {
      _selectedInstitutionCode = preset.code;
      _selectedColor = preset.colorHex;
      if (_walletType != 'SAVINGS') {
        if (preset.category == InstitutionCategory.bank) {
          _walletType = 'BANK';
        } else if (preset.category == InstitutionCategory.eWallet) {
          _walletType = 'E_WALLET';
        } else {
          _walletType = 'CASH';
        }
        _selectedIcon = preset.defaultIcon;
      }
      if (_nameController.text.trim().isEmpty && _walletType != 'SAVINGS') {
        _nameController.text = preset.name;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nama dompet wajib diisi.');
      return;
    }
    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final controller = ref.read(walletControllerProvider.notifier);
    // Target hanya berlaku untuk kantong tabungan; kosong atau 0 berarti tanpa target.
    final parsedTarget = CurrencyFormatter.parse(_targetController.text);
    final targetVal = (_walletType == 'SAVINGS' && parsedTarget > 0) ? parsedTarget : null;

    bool ok;
    if (widget.walletToEdit != null) {
      ok = await controller.updateWallet(
        id: widget.walletToEdit!.id,
        name: name,
        iconName: _selectedIcon,
        colorHex: _selectedColor,
        walletType: _walletType,
        institutionCode: _selectedInstitutionCode,
        targetAmount: targetVal,
      );
    } else {
      final initialBalance = CurrencyFormatter.parse(_balanceController.text);
      ok = await controller.createWallet(
        name: name,
        initialBalance: initialBalance,
        iconName: _selectedIcon,
        colorHex: _selectedColor,
        walletType: _walletType,
        institutionCode: _selectedInstitutionCode,
        targetAmount: targetVal,
      );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isSaving = false;
        _errorText = 'Gagal menyimpan dompet. Periksa kembali data yang diisi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.walletToEdit != null;
    final isSavings = _walletType == 'SAVINGS';

    // Calculate preview progress if savings target is specified
    final currentBal = CurrencyFormatter.parse(_balanceController.text);
    final targetBal = CurrencyFormatter.parse(_targetController.text);
    double progress = 0.0;
    if (targetBal > 0) {
      progress = (currentBal / targetBal).clamp(0.0, 1.0);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit
                        ? (isSavings ? 'Ubah Kantong Tabungan' : 'Ubah Dompet')
                        : (isSavings ? 'Buat Kantong Tabungan' : 'Tambah Dompet Baru'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isSavings)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gopayBlueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.sparkles, size: 12, color: AppColors.gopayBlue),
                          SizedBox(width: 4),
                          Text(
                            'Tabungan',
                            style: TextStyle(
                              color: AppColors.gopayBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Mode Switcher: Dompet Harian vs Kantong Tabungan (if new)
              if (!isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _walletType = 'E_WALLET';
                              _selectedIcon = 'wallet';
                              _selectedColor = '#00AA13';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: !isSavings ? AppColors.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isSavings ? AppColors.cardShadow : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.wallet,
                                  size: 15,
                                  color: !isSavings ? AppColors.gojekGreen : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Dompet Harian',
                                  style: TextStyle(
                                    color: !isSavings ? AppColors.textPrimary : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: !isSavings ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _walletType = 'SAVINGS';
                              _selectedIcon = 'piggy-bank';
                              _selectedColor = '#00AED6';
                              if (_selectedInstitutionCode == 'CUSTOM') {
                                _selectedInstitutionCode = 'GOPAY';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isSavings ? AppColors.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSavings ? AppColors.cardShadow : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 15,
                                  color: isSavings ? AppColors.gopayBlue : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kantong Tabungan',
                                  style: TextStyle(
                                    color: isSavings ? AppColors.gopayBlueDark : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSavings ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Nama Tabungan / Dompet
              Text(
                isSavings ? 'Nama Kantong Tabungan' : 'Nama Dompet',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxNameLength)],
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: isSavings ? 'misal: Nonton Konser, Upgrade Setup, Dana Darurat' : 'misal: BCA Utama, GoPay Harian, Dompet Saku',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isSavings ? AppColors.gopayBlue : AppColors.gojekGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Opsi Institusi Bank & E-Wallet (Dropdown Terkategorisasi)
              InstitutionDropdownPicker(
                label: isSavings
                    ? 'Disimpan di Bank / Dompet Digital Mana?'
                    : 'Pilih Bank / Dompet Digital / Tunai',
                selectedCode: _selectedInstitutionCode,
                onSelected: (preset) {
                  _selectInstitution(preset);
                },
              ),
              const SizedBox(height: 16),

              // Saldo Awal (only for new wallet)
              if (!isEdit) ...[
                Text(
                  isSavings ? 'Saldo Tabungan Saat Ini' : 'Saldo Awal',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _balanceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: CurrencyFormatter.tabularFigures,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      color: isSavings ? AppColors.gopayBlue : AppColors.gojekGreen,
                      fontWeight: FontWeight.w800,
                      fontFeatures: CurrencyFormatter.tabularFigures,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isSavings ? AppColors.gopayBlue : AppColors.gojekGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Target Tabungan (Opsional - khusus SAVINGS)
              if (isSavings) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Target Nominal Tabungan (Opsional)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (targetBal > 0)
                      Text(
                        'Tercapai ${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.gopayBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: CurrencyFormatter.tabularFigures,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      color: AppColors.gopayBlue,
                      fontWeight: FontWeight.w800,
                      fontFeatures: CurrencyFormatter.tabularFigures,
                    ),
                    hintText: 'misal: 5.000.000',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gopayBlue, width: 1.5),
                    ),
                  ),
                ),
                if (targetBal > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gopayBlue),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Ikon & Warna
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ikon', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: IconHelper.availableWalletIcons.take(6).map((iconName) {
                            final isSelected = _selectedIcon == iconName;
                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedIcon = iconName);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.gopayBlue : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  IconHelper.getIcon(iconName),
                                  size: 18,
                                  color: isSelected ? AppColors.gopayBlue : AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Color Picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _colors.map((hex) {
                            final color = ColorUtils.fromHex(hex);
                            final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedColor = hex);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.textPrimary : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  style: const TextStyle(color: AppColors.coralRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSavings ? AppColors.gopayBlue : AppColors.gojekGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isEdit
                        ? 'Simpan Perubahan'
                        : (isSavings ? 'Buat Kantong Tabungan (✦)' : 'Tambah Dompet'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
