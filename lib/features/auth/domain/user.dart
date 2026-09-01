class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.code = '',
    this.avatarUrl,
    this.phone = '',
    this.signature = '',
    this.memberLevel = 0,
    this.isMember = false,
  });

  final String id;
  final String name;
  final String email;
  final String code;
  final String? avatarUrl;
  final String phone;
  final String signature;
  final int memberLevel;
  final bool isMember;

  User copyWith({
    String? name,
    String? email,
    String? code,
    String? avatarUrl,
    String? phone,
    String? signature,
    int? memberLevel,
    bool? isMember,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      code: code ?? this.code,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      signature: signature ?? this.signature,
      memberLevel: memberLevel ?? this.memberLevel,
      isMember: isMember ?? this.isMember,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      code: json['code'] as String? ?? '',
      avatarUrl: (json['avatarUrl'] ?? json['avatar']) as String?,
      phone: json['phone'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      memberLevel: (json['memberLevel'] as num?)?.toInt() ?? 0,
      isMember: json['isMember'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.code == code &&
        other.avatarUrl == avatarUrl &&
        other.phone == phone &&
        other.signature == signature &&
        other.memberLevel == memberLevel &&
        other.isMember == isMember;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        code,
        avatarUrl,
        phone,
        signature,
        memberLevel,
        isMember,
      );
}
