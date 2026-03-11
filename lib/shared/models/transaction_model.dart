// ══════════════════════════════════════════════════════════════════════════════
// Transaction Model
// ══════════════════════════════════════════════════════════════════════════════

enum TransactionType { deposit, withdrawal }
enum TransactionStatus { pending, completed, paid, rejected }

class TransactionModel {
  final String            id;
  final String            uid;
  final String            username;
  final TransactionType   type;
  final int               coins;
  final int               amountNaira;
  final int               feeNaira;
  final TransactionStatus status;
  final String?           reference;     // Paystack ref for deposits
  final String?           accountNumber;
  final String?           accountName;
  final String?           bankName;
  final DateTime          createdAt;
  final DateTime?         updatedAt;
  final DateTime?         paidAt;

  const TransactionModel({
    required this.id,
    required this.uid,
    required this.username,
    required this.type,
    required this.coins,
    required this.amountNaira,
    this.feeNaira      = 0,
    required this.status,
    this.reference,
    this.accountNumber,
    this.accountName,
    this.bankName,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
  });

  bool get isDeposit    => type == TransactionType.deposit;
  bool get isWithdrawal => type == TransactionType.withdrawal;
  bool get isPending    => status == TransactionStatus.pending;
  bool get isCompleted  => status == TransactionStatus.completed || status == TransactionStatus.paid;

  String get typeLabel   => isDeposit ? 'Add Coins' : 'Withdrawal';
  String get statusLabel => status.name[0].toUpperCase() + status.name.substring(1);

  String get coinsDisplay {
    final sign = isDeposit ? '+' : '-';
    return '$sign${coins.toString()}';
  }

  factory TransactionModel.fromMap(Map<String, dynamic> m, String docId) {
    return TransactionModel(
      id:            docId,
      uid:           m['uid']      as String? ?? '',
      username:      m['username'] as String? ?? '',
      type:          (m['type'] as String?) == 'deposit'
                       ? TransactionType.deposit
                       : TransactionType.withdrawal,
      coins:         (m['coins'] as num?)?.toInt() ?? 0,
      amountNaira:   (m['amount_naira'] as num?)?.toInt() ?? 0,
      feeNaira:      (m['fee_naira'] as num?)?.toInt() ?? 0,
      status:        _parseStatus(m['status'] as String? ?? 'pending'),
      reference:     m['reference']      as String?,
      accountNumber: m['account_number'] as String?,
      accountName:   m['account_name']   as String?,
      bankName:      m['bank_name']       as String?,
      createdAt:     m['createdAt'] != null
                       ? DateTime.parse(m['createdAt'] as String)
                       : DateTime.now(),
      updatedAt:     m['updatedAt'] != null
                       ? DateTime.parse(m['updatedAt'] as String)
                       : null,
      paidAt:        m['paidAt'] != null
                       ? DateTime.parse(m['paidAt'] as String)
                       : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':            uid,
    'username':       username,
    'type':           type.name,
    'coins':          coins,
    'amount_naira':   amountNaira,
    'fee_naira':      feeNaira,
    'status':         status.name,
    'reference':      reference,
    'account_number': accountNumber,
    'account_name':   accountName,
    'bank_name':      bankName,
    'createdAt':      createdAt.toIso8601String(),
    'updatedAt':      updatedAt?.toIso8601String(),
    'paidAt':         paidAt?.toIso8601String(),
  };

  static TransactionStatus _parseStatus(String s) => switch (s) {
    'completed' => TransactionStatus.completed,
    'paid'      => TransactionStatus.paid,
    'rejected'  => TransactionStatus.rejected,
    _           => TransactionStatus.pending,
  };
}