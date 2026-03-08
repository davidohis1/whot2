class UserModel {
  final String uid;
  final String username;
  final String email;
  final int coinBalance;
  final int chessWins;
  final int chessLosses;
  final int whotWins;
  final int whotLosses;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.coinBalance,
    this.chessWins = 0,
    this.chessLosses = 0,
    this.whotWins = 0,
    this.whotLosses = 0,
    this.avatarUrl,
    required this.createdAt,
  });

  int get chessGames => chessWins + chessLosses;
  int get whotGames  => whotWins  + whotLosses;
  double get chessWinRate => chessGames == 0 ? 0 : chessWins / chessGames;
  double get whotWinRate  => whotGames  == 0 ? 0 : whotWins  / whotGames;

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    uid:          map['uid'] as String,
    username:     map['username'] as String,
    email:        map['email'] as String,
    coinBalance:  (map['coinBalance'] as num).toInt(),
    chessWins:    (map['chessWins']   as num? ?? 0).toInt(),
    chessLosses:  (map['chessLosses'] as num? ?? 0).toInt(),
    whotWins:     (map['whotWins']    as num? ?? 0).toInt(),
    whotLosses:   (map['whotLosses']  as num? ?? 0).toInt(),
    avatarUrl:    map['avatarUrl'] as String?,
    createdAt:    DateTime.parse(map['createdAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'uid':         uid,
    'username':    username,
    'email':       email,
    'coinBalance': coinBalance,
    'chessWins':   chessWins,
    'chessLosses': chessLosses,
    'whotWins':    whotWins,
    'whotLosses':  whotLosses,
    'avatarUrl':   avatarUrl,
    'createdAt':   createdAt.toIso8601String(),
  };

  UserModel copyWith({
    String? username,
    String? email,
    int? coinBalance,
    int? chessWins,
    int? chessLosses,
    int? whotWins,
    int? whotLosses,
    String? avatarUrl,
  }) => UserModel(
    uid:         uid,
    username:    username    ?? this.username,
    email:       email       ?? this.email,
    coinBalance: coinBalance ?? this.coinBalance,
    chessWins:   chessWins   ?? this.chessWins,
    chessLosses: chessLosses ?? this.chessLosses,
    whotWins:    whotWins    ?? this.whotWins,
    whotLosses:  whotLosses  ?? this.whotLosses,
    avatarUrl:   avatarUrl   ?? this.avatarUrl,
    createdAt:   createdAt,
  );
}