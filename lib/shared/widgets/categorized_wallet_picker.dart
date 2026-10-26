import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/icon_helper.dart';
import 'institution_badge.dart';
import '../../core/utils/color_utils.dart';

/// Dropdown pemilih dompet / sumber dana dengan pengelompokan kategori:
/// Bank, Dompet Digital (E-Wallet), Kantong Tabungan, dan Uang Tunai.
class CategorizedWalletPicker extends StatefulWidget {
  final String label;
  final String? selectedWalletId;
  final List<Wallet> wallets;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddNewWallet;
  final bool isCompact;

  const CategorizedWalletPicker({
    super.key,
    required this.label,
    required this.selectedWalletId,
    required this.wallets,
    required this.onChanged,
    this.onAddNewWallet,
    this.isCompact = false,
  });

  @override
  State<CategorizedWalletPicker> createState() => _CategorizedWalletPickerState();
}

/// Alias agar pengembang dapat menggunakan nama [CategorizedWalletDropdown]
typedef CategorizedWalletDropdown = CategorizedWalletPicker;

class _CategorizedWalletPickerState extends State<CategorizedWalletPicker>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant CategorizedWalletPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
      // Rebuild overlay if wallets or selection changed while open
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlayImmediate();
    _animationController.dispose();
    super.dispose();
  }

  void _removeOverlayImmediate() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    _animationController.reverse().then((_) {
      if (mounted) {
        _removeOverlayImmediate();
        setState(() {});
      }
    });
    setState(() {
      _isOpen = false;
    });
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final overlayState = Overlay.maybeOf(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (overlayState == null || renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Hitung lebar dropdown (jika compact, buat minimum 280 agar teks & saldo leluasa)
    final double dropdownWidth = widget.isCompact
        ? (screenSize.width - 32).clamp(270.0, 320.0)
        : size.width;

    // Hitung posisi horizontal agar tidak terpotong di tepi layar
    double horizontalOffset = 0.0;
    if (widget.isCompact) {
      if (offset.dx > screenSize.width / 2) {
        horizontalOffset = size.width - dropdownWidth;
      }
      final leftScreen = offset.dx + horizontalOffset;
      if (leftScreen < 12) {
        horizontalOffset = 12 - offset.dx;
      } else if (leftScreen + dropdownWidth > screenSize.width - 12) {
        horizontalOffset = screenSize.width - 12 - dropdownWidth - offset.dx;
      }
    }

    // Cek ruang vertikal: jika di bawah < 250px dan di atas cukup, buka ke atas
    const double dropdownMaxHeight = 280.0;
    final double spaceBelow = screenSize.height - (offset.dy + size.height);
    final bool openUpwards = spaceBelow < 250 && offset.dy > 270;
    final double verticalOffset = openUpwards ? -(dropdownMaxHeight + 6) : (size.height + 6);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        // Kelompokkan dompet berdasarkan kategori
        final bankWallets = widget.wallets.where((w) => w.walletType == 'BANK').toList();
        final eWallets = widget.wallets.where((w) => w.walletType == 'E_WALLET').toList();
        final savingsWallets = widget.wallets.where((w) => w.walletType == 'SAVINGS').toList();
        final cashWallets = widget.wallets.where((w) => w.walletType == 'CASH').toList();
        final otherWallets = widget.wallets
            .where((w) => !['BANK', 'E_WALLET', 'SAVINGS', 'CASH'].contains(w.walletType))
            .toList();

        return Stack(
          children: [
            // Barrier transparan: sentuh di luar dropdown untuk menutup
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child: const SizedBox.expand(),
              ),
            ),

            // Dropdown Menu yang menempel (anchored) pada kotak input
            Positioned(
              width: dropdownWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(horizontalOffset, verticalOffset),
                child: FadeTransition(
                  opacity: _expandAnimation,
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    alignment: openUpwards ? Alignment.bottomCenter : Alignment.topCenter,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: dropdownMaxHeight),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Dropdown Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.label.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gopayBlueLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${widget.wallets.length} Akun',
                                        style: const TextStyle(
                                          color: AppColors.gopayBlueDark,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Daftar Dompet Terkategorisasi
                              Flexible(
                                child: widget.wallets.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Center(
                                          child: Text(
                                            'Belum ada akun dompet',
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                        shrinkWrap: true,
                                        children: [
                                          // 1. BANK
                                          if (bankWallets.isNotEmpty) ...[
                                            _buildCategoryHeader(
                                              'BANK (Rekening)',
                                              LucideIcons.landmark,
                                              const Color(0xFF0060AF),
                                            ),
                                            ...bankWallets.map((w) => _buildWalletDropdownItem(w)),
                                            const SizedBox(height: 6),
                                          ],

                                          // 2. DOMPET DIGITAL
                                          if (eWallets.isNotEmpty) ...[
                                            _buildCategoryHeader(
                                              'DOMPET DIGITAL (E-Wallet)',
                                              LucideIcons.smartphone,
                                              AppColors.gopayBlue,
                                            ),
                                            ...eWallets.map((w) => _buildWalletDropdownItem(w)),
                                            const SizedBox(height: 6),
                                          ],

                                          // 3. KANTONG TABUNGAN
                                          if (savingsWallets.isNotEmpty) ...[
                                            _buildCategoryHeader(
                                              'KANTONG TABUNGAN (✦)',
                                              LucideIcons.sparkles,
                                              AppColors.gopayBlueDark,
                                            ),
                                            ...savingsWallets.map(
                                              (w) => _buildWalletDropdownItem(w, isSavings: true),
                                            ),
                                            const SizedBox(height: 6),
                                          ],

                                          // 4. UANG TUNAI
                                          if (cashWallets.isNotEmpty) ...[
                                            _buildCategoryHeader(
                                              'UANG TUNAI (Cash)',
                                              LucideIcons.banknote,
                                              AppColors.gojekGreen,
                                            ),
                                            ...cashWallets.map((w) => _buildWalletDropdownItem(w)),
                                            const SizedBox(height: 6),
                                          ],

                                          // 5. LAINNYA
                                          if (otherWallets.isNotEmpty) ...[
                                            _buildCategoryHeader(
                                              'LAINNYA',
                                              LucideIcons.wallet,
                                              AppColors.textSecondary,
                                            ),
                                            ...otherWallets.map((w) => _buildWalletDropdownItem(w)),
                                            const SizedBox(height: 6),
                                          ],
                                        ],
                                      ),
                              ),

                              // Tombol Tambah Dompet Baru di bagian bawah Dropdown
                              if (widget.onAddNewWallet != null) ...[
                                Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    border: Border(top: BorderSide(color: AppColors.border)),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _closeDropdown();
                                        widget.onAddNewWallet!();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(LucideIcons.plus, size: 14, color: AppColors.gopayBlue),
                                            SizedBox(width: 6),
                                            Text(
                                              'Tambah Dompet Baru',
                                              style: TextStyle(
                                                color: AppColors.gopayBlue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
    _animationController.forward(from: 0.0);
    setState(() {
      _isOpen = true;
    });
  }

  Widget _buildCategoryHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletDropdownItem(Wallet wallet, {bool isSavings = false}) {
    final isSelected = wallet.id == widget.selectedWalletId;
    final color = ColorUtils.fromHex(wallet.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.gopayBlueLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: AppColors.gopayBlue.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onChanged(wallet.id);
            _closeDropdown();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Icon Dompet
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(IconHelper.getIcon(wallet.iconName), color: color, size: 15),
                ),
                const SizedBox(width: 8),

                // Nama & Badge Institusi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              wallet.name,
                              style: TextStyle(
                                color: isSelected ? AppColors.gopayBlueDark : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InstitutionBadge(
                            institutionCode: wallet.institutionCode,
                            isSavings: isSavings,
                            fontSize: 7.5,
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        CurrencyFormatter.formatRupiah(wallet.currentBalance),
                        style: TextStyle(
                          color: isSelected ? AppColors.gopayBlueDark : AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),

                // Centang tanda terpilih
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(LucideIcons.check, size: 16, color: AppColors.gopayBlue),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = widget.wallets.where((w) => w.id == widget.selectedWalletId).firstOrNull ??
        (widget.wallets.isNotEmpty ? widget.wallets.first : null);

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _toggleDropdown();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 10 : 12,
            vertical: widget.isCompact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isOpen ? AppColors.gopayBlue : AppColors.border,
              width: _isOpen ? 1.5 : 1,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: AppColors.gopayBlue.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (selectedWallet != null) ...[
                // Icon Dompet Terpilih
                Container(
                  width: widget.isCompact ? 28 : 34,
                  height: widget.isCompact ? 28 : 34,
                  decoration: BoxDecoration(
                    color: ColorUtils.fromHex(selectedWallet.colorHex)
                        .withOpacity(0.16),
                    borderRadius: BorderRadius.circular(widget.isCompact ? 8 : 10),
                  ),
                  child: Icon(
                    IconHelper.getIcon(selectedWallet.iconName),
                    size: widget.isCompact ? 15 : 18,
                    color: ColorUtils.fromHex(selectedWallet.colorHex),
                  ),
                ),
                SizedBox(width: widget.isCompact ? 8 : 10),

                // Label, Nama, Badge, dan Saldo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              selectedWallet.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: widget.isCompact ? 12 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InstitutionBadge(
                            institutionCode: selectedWallet.institutionCode,
                            isSavings: selectedWallet.walletType == 'SAVINGS',
                            fontSize: 7.5,
                          ),
                        ],
                      ),
                      if (!widget.isCompact) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Saldo: ${CurrencyFormatter.formatRupiah(selectedWallet.currentBalance)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Chevron Down berputar halus saat dropdown terbuka
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: _isOpen ? AppColors.gopayBlue : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
