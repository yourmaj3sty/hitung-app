import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/animations/confetti_overlay.dart';
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/institution_presets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/formatted_amount_text.dart';
import '../../../shared/widgets/institution_badge.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/wallet_provider.dart';
import 'wallet_form_sheet.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/rupiah_input_formatter.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(activeWalletsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dompet & Tabungan'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.gopayBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.plus, color: AppColors.gopayBlue, size: 18),
            ),
            onPressed: () => _showAddOptions(context),
            tooltip: 'Tambah Dompet / Tabungan',
          ),
        ],
      ),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gopayBlue)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.coralRed))),
        data: (wallets) {
          if (wallets.isEmpty) {
            return EmptyStateWidget(
              icon: LucideIcons.wallet,
              title: 'Belum Ada Dompet',
              subtitle: 'Tambahkan dompet atau kantong tabungan untuk mulai mengelola saldo Anda.',
              action: ElevatedButton.icon(
                onPressed: () => WalletFormSheet.show(context),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Tambah Dompet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gopayBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          }

          final dailyWallets = wallets.where((w) => w.walletType != 'SAVINGS').toList();
          final savingsWallets = wallets.where((w) => w.walletType == 'SAVINGS').toList();

          final totalDaily = dailyWallets.fold<int>(0, (sum, w) => sum + w.currentBalance);
          final totalSavings = savingsWallets.fold<int>(0, (sum, w) => sum + w.currentBalance);
          final totalAll = totalDaily + totalSavings;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Hero Balance Card (GoPay Gradient with Rounded Rect 24)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00AED6), Color(0xFF0082A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.heroShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Seluruh Saldo',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    FormattedAmountText(
                      amount: totalAll,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Split summary pills
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Dompet Harian', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(totalDaily),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: CurrencyFormatter.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Tabungan (✦)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(totalSavings),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: CurrencyFormatter.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION: Kantong Tabungan (Savings Pockets)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.sparkles, color: AppColors.gopayBlue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Kantong Tabungan (${savingsWallets.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => WalletFormSheet.show(context, initialIsSavings: true),
                    child: const Text(
                      '+ Buat Kantong',
                      style: TextStyle(
                        color: AppColors.gopayBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (savingsWallets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.gopayBlueLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.sparkles, color: AppColors.gopayBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Belum ada kantong tabungan',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sisihkan dana untuk target impianmu sekarang.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => WalletFormSheet.show(context, initialIsSavings: true),
                        child: const Text('Buat', style: TextStyle(color: AppColors.gopayBlue, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                )
              else
                ...savingsWallets.map((wallet) => _buildSavingsCard(context, ref, wallet)),

              const SizedBox(height: 22),

              // SECTION: Dompet Harian
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.wallet, color: AppColors.gojekGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Dompet Harian (${dailyWallets.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => WalletFormSheet.show(context, initialIsSavings: false),
                    child: const Text(
                      '+ Tambah Dompet',
                      style: TextStyle(
                        color: AppColors.gojekGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ...dailyWallets.map((wallet) => _buildDailyWalletCard(context, ref, wallet)),

              // Dompet Diarsipkan (Feature 3)
              Builder(
                builder: (context) {
                  final archivedWallets = ref.watch(archivedWalletsStreamProvider).value ?? [];
                  if (archivedWallets.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(LucideIcons.archive, color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Dompet Diarsipkan (${archivedWallets.length})',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...archivedWallets.map((w) => _buildArchivedWalletCard(context, ref, w)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, WidgetRef ref, Wallet wallet) {
    final preset = InstitutionPresets.getByCode(wallet.institutionCode);
    final color = ColorUtils.fromHex(wallet.colorHex);
    final target = wallet.targetAmount;
    final current = wallet.currentBalance;
    double progress = 0.0;
    if (target != null && target > 0) {
      progress = (current / target).clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(IconHelper.getIcon(wallet.iconName), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            wallet.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InstitutionBadge(
                          institutionCode: wallet.institutionCode,
                          customColorHex: wallet.colorHex,
                          isSavings: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Disimpan di ${preset.name}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical, color: AppColors.textSecondary, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (action) {
                  if (action == 'edit') {
                    WalletFormSheet.show(context, walletToEdit: wallet);
                  } else if (action == 'adjust') {
                    _showAdjustBalanceDialog(context, ref, wallet);
                  } else if (action == 'archive') {
                    _confirmArchive(context, ref, wallet);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(LucideIcons.edit2, size: 16, color: AppColors.textPrimary),
                        SizedBox(width: 10),
                        Text('Edit Tabungan'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'adjust',
                    child: Row(
                      children: [
                        Icon(LucideIcons.slidersHorizontal, size: 16, color: AppColors.gopayBlue),
                        SizedBox(width: 10),
                        Text('Koreksi / Sesuaikan Saldo'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(LucideIcons.archive, size: 16, color: AppColors.coralRed),
                        SizedBox(width: 10),
                        Text('Arsipkan', style: TextStyle(color: AppColors.coralRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nominal & Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Terkumpul', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  FormattedAmountText(
                    amount: current,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gopayBlueDark,
                    ),
                  ),
                ],
              ),
              if (target != null && target > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target: ${CurrencyFormatter.formatRupiah(target)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    if (progress >= 1.0)
                      EmilSpringButton(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ConfettiOverlay.show(context);
                        },
                        pressScale: 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8F031).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.sparkles, color: AppColors.brandPurple, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Target Tercapai! 100% 🎉',
                                style: TextStyle(
                                  color: AppColors.brandPurple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        '${(progress * 100).toInt()}% tercapai',
                        style: const TextStyle(color: AppColors.gopayBlue, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
            ],
          ),

          // Progress bar elastis
          if (target != null && target > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 7,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyWalletCard(BuildContext context, WidgetRef ref, Wallet wallet) {
    final color = ColorUtils.fromHex(wallet.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(IconHelper.getIcon(wallet.iconName), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        wallet.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InstitutionBadge(
                      institutionCode: wallet.institutionCode,
                      customColorHex: wallet.colorHex,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FormattedAmountText(
                  amount: wallet.currentBalance,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical, color: AppColors.textSecondary, size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (action) {
              if (action == 'edit') {
                WalletFormSheet.show(context, walletToEdit: wallet);
              } else if (action == 'adjust') {
                _showAdjustBalanceDialog(context, ref, wallet);
              } else if (action == 'archive') {
                _confirmArchive(context, ref, wallet);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(LucideIcons.edit2, size: 16, color: AppColors.textPrimary),
                    SizedBox(width: 10),
                    Text('Edit Dompet'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'adjust',
                child: Row(
                  children: [
                    Icon(LucideIcons.slidersHorizontal, size: 16, color: AppColors.gopayBlue),
                    SizedBox(width: 10),
                    Text('Koreksi / Sesuaikan Saldo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(LucideIcons.archive, size: 16, color: AppColors.coralRed),
                    SizedBox(width: 10),
                    Text('Arsipkan', style: TextStyle(color: AppColors.coralRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      // Warna & sudut diatur di sheet (Material), bukan di Container, agar efek
      // ketukan ListTile di dalamnya terlihat.
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Tambah Akun Keuangan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gojekGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.wallet, color: AppColors.gojekGreen, size: 20),
              ),
              title: const Text('Dompet Harian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Untuk transaksi harian (Bank, E-Wallet, atau Tunai)', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                WalletFormSheet.show(context, initialIsSavings: false);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gopayBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.sparkles, color: AppColors.gopayBlue, size: 20),
              ),
              title: const Text('Kantong Tabungan (✦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Target tabungan impian disimpan di Bank/E-Wallet', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                WalletFormSheet.show(context, initialIsSavings: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, WidgetRef ref, Wallet wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wallet.walletType == 'SAVINGS' ? 'Arsipkan Kantong?' : 'Arsipkan Dompet?'),
        content: Text('Akun "${wallet.name}" akan disembunyikan. Riwayat transaksi sebelumnya tetap aman tersimpan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final walletFilter = ref.read(selectedWalletFilterProvider.notifier);
              final ok = await ref.read(walletControllerProvider.notifier).archiveWallet(wallet.id);
              // Jangan biarkan Beranda tetap memfilter dompet yang sudah diarsipkan.
              if (ok && walletFilter.state == wallet.id) walletFilter.state = null;
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal mengarsipkan (tidak bisa mengarsipkan dompet terakhir).')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
  }

  void _showAdjustBalanceDialog(BuildContext context, WidgetRef ref, Wallet wallet) {
    final balanceController = TextEditingController(
      text: CurrencyFormatter.formatRupiah(wallet.currentBalance).replaceAll('Rp ', ''),
    );
    final noteController = TextEditingController();
    int current = wallet.currentBalance;
    int entered = current;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final delta = entered - current;
          final isPositive = delta > 0;
          final isZero = delta == 0;

          return AlertDialog(
            title: Text('Sesuaikan Saldo: ${wallet.name}'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo di Aplikasi saat ini:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(CurrencyFormatter.formatRupiah(current), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  const Text('Saldo Asli / Rekening:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: const [RupiahInputFormatter()],
                    onChanged: (val) {
                      setState(() {
                        entered = CurrencyFormatter.parse(val);
                      });
                    },
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isZero
                          ? AppColors.surfaceElevated
                          : (isPositive ? AppColors.gojekGreen.withOpacity(0.12) : AppColors.coralRed.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isZero ? LucideIcons.check : (isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft),
                          size: 16,
                          color: isZero ? AppColors.textSecondary : (isPositive ? AppColors.gojekGreen : AppColors.coralRed),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isZero
                                ? 'Saldo sudah cocok'
                                : 'Selisih koreksi: ${isPositive ? '+' : '-'}${CurrencyFormatter.formatRupiah(delta.abs())}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isZero ? AppColors.textSecondary : (isPositive ? AppColors.gojekGreen : AppColors.coralRed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Koreksi (opsional)',
                      hintText: 'misal: Bunga bank, biaya admin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final note = noteController.text.trim();
                  final ok = await ref.read(walletControllerProvider.notifier).adjustBalance(
                    walletId: wallet.id,
                    actualBalance: entered,
                    note: note.isEmpty ? null : note,
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saldo ${wallet.name} disesuaikan ke ${CurrencyFormatter.formatRupiah(entered)}.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gopayBlue, foregroundColor: Colors.white),
                child: const Text('Terapkan Koreksi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildArchivedWalletCard(BuildContext context, WidgetRef ref, Wallet wallet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(IconHelper.getIcon(wallet.iconName), color: Colors.grey, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Saldo: ${CurrencyFormatter.formatRupiah(wallet.currentBalance)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          EmilSpringButton(
            onTap: () async {
              final ok = await ref.read(walletControllerProvider.notifier).unarchiveWallet(wallet.id);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dompet "${wallet.name}" berhasil dipulihkan!')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gojekGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.rotateCcw, size: 14, color: AppColors.gojekGreen),
                  SizedBox(width: 4),
                  Text('Pulihkan', style: TextStyle(color: AppColors.gojekGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
