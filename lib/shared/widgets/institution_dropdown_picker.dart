import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/institution_presets.dart';

/// Dropdown pemilih Bank & Dompet Digital (E-Wallet) terkategorisasi
/// Digunakan pada pembuatan atau pengubahan akun dompet/tabungan baru.
class InstitutionDropdownPicker extends StatefulWidget {
  final String label;
  final String? selectedCode;
  final ValueChanged<InstitutionPreset> onSelected;

  const InstitutionDropdownPicker({
    super.key,
    required this.label,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  State<InstitutionDropdownPicker> createState() => _InstitutionDropdownPickerState();
}

class _InstitutionDropdownPickerState extends State<InstitutionDropdownPicker>
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
  void didUpdateWidget(covariant InstitutionDropdownPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
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

    final double dropdownWidth = size.width;
    const double dropdownMaxHeight = 300.0;

    final double spaceBelow = screenSize.height - (offset.dy + size.height);
    final bool openUpwards = spaceBelow < 250 && offset.dy > 270;
    final double verticalOffset = openUpwards ? -(dropdownMaxHeight + 6) : (size.height + 6);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
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

            // Dropdown Menu yang menempel tepat di bawah kotak input
            Positioned(
              width: dropdownWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, verticalOffset),
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'PILIH BANK ATAU E-WALLET',
                                      style: TextStyle(
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
                                        '${InstitutionPresets.all.length} Institusi',
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

                              // Daftar Institusi Terkategorisasi
                              Flexible(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  shrinkWrap: true,
                                  children: [
                                    // 1. BANK
                                    _buildCategoryHeader(
                                      'BANK (Rekening)',
                                      LucideIcons.landmark,
                                      const Color(0xFF0060AF),
                                    ),
                                    ...InstitutionPresets.banks.map((p) => _buildPresetItem(p)),
                                    const SizedBox(height: 6),

                                    // 2. DOMPET DIGITAL
                                    _buildCategoryHeader(
                                      'DOMPET DIGITAL (E-Wallet)',
                                      LucideIcons.smartphone,
                                      AppColors.gopayBlue,
                                    ),
                                    ...InstitutionPresets.eWallets.map((p) => _buildPresetItem(p)),
                                    const SizedBox(height: 6),

                                    // 3. UANG TUNAI
                                    _buildCategoryHeader(
                                      'UANG TUNAI (Cash)',
                                      LucideIcons.banknote,
                                      AppColors.gojekGreen,
                                    ),
                                    ...InstitutionPresets.cash.map((p) => _buildPresetItem(p)),
                                    const SizedBox(height: 6),

                                    // 4. KUSTOM / LAINNYA
                                    _buildCategoryHeader(
                                      'LAINNYA',
                                      LucideIcons.wallet,
                                      AppColors.textSecondary,
                                    ),
                                    _buildPresetItem(InstitutionPresets.defaultPreset),
                                  ],
                                ),
                              ),
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

  Widget _buildPresetItem(InstitutionPreset preset) {
    final isSelected = widget.selectedCode?.toUpperCase() == preset.code.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? preset.color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: preset.color.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onSelected(preset);
            _closeDropdown();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                // Indikator Warna / Dot
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: preset.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: preset.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nama Institusi
                Expanded(
                  child: Text(
                    preset.name,
                    style: TextStyle(
                      color: isSelected ? preset.color : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Short Badge (e.g. BCA, JAGO, GOPAY)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: preset.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preset.shortLabel,
                    style: TextStyle(
                      color: preset.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                // Centang tanda terpilih
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.check, size: 16, color: preset.color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset = InstitutionPresets.getByCode(widget.selectedCode);

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isOpen ? currentPreset.color : AppColors.border,
              width: _isOpen ? 1.5 : 1,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: currentPreset.color.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Badge Indikator Institusi Terpilih
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: currentPreset.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: currentPreset.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Detail Label & Institusi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currentPreset.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: currentPreset.color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            currentPreset.shortLabel,
                            style: TextStyle(
                              color: currentPreset.color,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron Down berputar halus saat dropdown terbuka
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: _isOpen ? currentPreset.color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
