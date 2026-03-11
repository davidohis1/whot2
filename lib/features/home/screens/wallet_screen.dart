import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/models/transaction_model.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final transactionsProvider = StreamProvider.family<List<TransactionModel>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('transactions')
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .where((d) => d.data()['uid'] == uid)
            .map((d) => TransactionModel.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

// ── Screen ────────────────────────────────────────────────────────────────────

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _uid => ref.read(authStateProvider).valueOrNull?.uid ?? '';

  Future<void> _openWallet(String path) async {
    final uri = Uri.parse('https://davidohiwerei.name.ng/arenagames/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open browser'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final txAsync   = ref.watch(transactionsProvider(_uid));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error:   (e, _) => Center(child: Text('$e')),
            data:    (user) {
              if (user == null) return const Center(child: Text('Not logged in'));
              final txList = txAsync.valueOrNull ?? [];
              return _buildContent(user, txList);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(user, List<TransactionModel> txList) {
    final deposits     = txList.where((t) => t.isDeposit).toList();
    final withdrawals  = txList.where((t) => t.isWithdrawal).toList();
    final totalAdded   = deposits.fold(0, (s, t) => s + t.coins);

    return Column(children: [
      _topBar(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _balanceCard(user, totalAdded),
            const SizedBox(height: 16),
            _gameStatsRow(user),
            const SizedBox(height: 20),
            _tabBar(),
            _tabContent(txList, user),
          ]),
        ),
      ),
    ]);
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        onPressed: () => context.go('/home'),
      ),
      const Text('Wallet', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const Spacer(),
    ]),
  );

  Widget _balanceCard(user, int totalAdded) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2035), Color(0xFF091525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AVAILABLE BALANCE', style: TextStyle(
            fontSize: 11, letterSpacing: 2, color: AppColors.textSecondary,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${user.coinBalance}', style: const TextStyle(
              fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.gold,
              height: 1)),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('coins', style: TextStyle(
                fontSize: 16, color: AppColors.textSecondary)),
          ),
        ]),
        Text('≈ ₦${user.coinBalance}', style: const TextStyle(
            color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: _actionBtn(
              icon: Icons.add_circle_outline,
              label: 'Add Coins',
              color: AppColors.gold,
              onTap: () => _openWallet('wallet.php'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(
              icon: Icons.arrow_downward_rounded,
              label: 'Withdraw',
              color: AppColors.danger,
              onTap: () => _openWallet('wallet.php?page=dashboard'),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ),
  );

  Widget _gameStatsRow(user) => Row(children: [
    _statChip('Whot Wins',   '${user.whotWins ?? 0}',   AppColors.teal),
    const SizedBox(width: 10),
    _statChip('Whot Losses', '${user.whotLosses ?? 0}', AppColors.danger),
    const SizedBox(width: 10),
    _statChip('Chess Wins',  '${user.chessWins ?? 0}',  AppColors.gold),
  ].map((w) => Expanded(child: w)).toList() as List<Widget>)
      .animate().fadeIn(delay: 100.ms);

  Widget _statChip(String label, String val, Color col) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(children: [
      Text(val, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: col)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
          fontSize: 9, color: AppColors.textMuted,
          letterSpacing: 0.5), textAlign: TextAlign.center),
    ]),
  );

  Widget _tabBar() => Container(
    decoration: BoxDecoration(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cardBorder),
    ),
    padding: const EdgeInsets.all(4),
    child: TabBar(
      controller: _tabs,
      indicator: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: '🎮  Game Records'),
        Tab(text: '💳  Transactions'),
      ],
    ),
  );

  Widget _tabContent(List<TransactionModel> txList, user) {
    return SizedBox(
      height: 500,
      child: TabBarView(
        controller: _tabs,
        children: [
          _gameRecordsTab(user),
          _transactionsTab(txList),
        ],
      ),
    );
  }

  // ── Game Records ────────────────────────────────────────────────────────────
  Widget _gameRecordsTab(user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('whot_games')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: AppColors.gold));

        final records = <Map<String, dynamic>>[];
        for (final doc in snap.data!.docs) {
          final data    = doc.data() as Map<String, dynamic>;
          final players = (data['players'] as List?) ?? [];
          final myEntry = players.cast<Map>().where((p) => p['uid'] == _uid);
          if (myEntry.isEmpty) continue;

          final rankings = List<String>.from(data['rankings'] ?? []);
          final rank     = rankings.indexOf(_uid);
          final pc       = (data['playerCount'] as num?)?.toInt() ?? 4;
          final status   = data['status'];
          if (status != 2) continue; // only finished games

          String result, coins;
          if (rank == 0) {
            result = 'Win'; coins = pc == 2 ? '+700' : '+1000';
          } else if (rank == 1 && pc == 4) {
            result = '2nd'; coins = '+300';
          } else {
            result = 'Loss'; coins = '-400';
          }

          records.add({
            'game':      'Whot ${pc}P',
            'result':    result,
            'coins':     coins,
            'createdAt': data['createdAt'] ?? '',
          });
        }

        records.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

        if (records.isEmpty) return _emptyState('🃏', 'No games played yet');

        return ListView.separated(
          padding: const EdgeInsets.only(top: 12),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _gameRecordTile(records[i]),
        );
      },
    );
  }

  Widget _gameRecordTile(Map<String, dynamic> r) {
    final isWin     = r['result'] == 'Win';
    final is2nd     = r['result'] == '2nd';
    final isPos     = (r['coins'] as String).startsWith('+');
    final color     = isWin ? AppColors.teal : (is2nd ? AppColors.gold : AppColors.danger);
    final dateStr   = r['createdAt'] != ''
        ? _formatDate(r['createdAt'] as String) : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(
            isWin ? '🥇' : (is2nd ? '🥈' : '🥉'),
            style: const TextStyle(fontSize: 18),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['game'] as String, style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(dateStr, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(r['coins'] as String, style: TextStyle(
              color: isPos ? AppColors.teal : AppColors.danger,
              fontWeight: FontWeight.w800, fontSize: 16)),
          Text('coins', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Transactions ────────────────────────────────────────────────────────────
  Widget _transactionsTab(List<TransactionModel> txList) {
    if (txList.isEmpty) return _emptyState('💳', 'No transactions yet');
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12),
      itemCount: txList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _txTile(txList[i]),
    );
  }

  Widget _txTile(TransactionModel tx) {
    final isDeposit = tx.isDeposit;
    final color     = isDeposit ? AppColors.teal : AppColors.danger;
    final icon      = isDeposit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    Color statusColor;
    String statusLabel;
    switch (tx.status) {
      case TransactionStatus.completed:
      case TransactionStatus.paid:
        statusColor = AppColors.teal; statusLabel = 'Completed'; break;
      case TransactionStatus.rejected:
        statusColor = AppColors.danger; statusLabel = 'Rejected'; break;
      default:
        statusColor = AppColors.gold; statusLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.typeLabel, style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          Row(children: [
            Text(_formatDate(tx.createdAt.toIso8601String()),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusLabel, style: TextStyle(
                  color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (!isDeposit && tx.bankName != null)
            Text('${tx.bankName} · ${tx.accountNumber}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(tx.coinsDisplay, style: TextStyle(
              color: isDeposit ? AppColors.teal : AppColors.danger,
              fontWeight: FontWeight.w800, fontSize: 16)),
          Text('₦${tx.amountNaira}', style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _emptyState(String emoji, String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
    ]),
  );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return '—'; }
  }
}