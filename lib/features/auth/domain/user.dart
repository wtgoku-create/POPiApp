class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.code = '',
    this.avatarUrl,
    this.phone = '',
    this.signature = '',
    this.gender = 0,
    this.birthday = '',
    this.wechat = '',
    this.country = '',
    this.province = '',
    this.city = '',
    this.memberLevel = 0,
    this.isMember = false,
    this.memberName = '',
    this.memberLabel = '',
    this.memberCoins = 0,
    this.otherCoins = 0,
    this.pointPackageCoins = 0,
    this.allCoins = 0,
    this.isUsedCoinsRecently = false,
    this.memberEndTime,
    this.power = 0,
    this.powerConsumed = 0,
    this.powerRecharged = 0,
    this.followingNum = 0,
    this.fansNum = 0,
    this.likeNum = 0,
    this.postNum = 0,
    this.taskNum = 0,
    this.characterDesignGuide = false,
    this.status = 0,
    this.createTime,
    this.updateTime,
  });

  final String id;
  final String name;
  final String email;
  final String code;
  final String? avatarUrl;
  final String phone;
  final String signature;
  final int gender;
  final String birthday;
  final String wechat;
  final String country;
  final String province;
  final String city;
  final int memberLevel;
  final bool isMember;
  final String memberName;
  final String memberLabel;
  final int memberCoins;
  final int otherCoins;
  final int pointPackageCoins;
  final int allCoins;
  final bool isUsedCoinsRecently;
  final DateTime? memberEndTime;
  final int power;
  final int powerConsumed;
  final int powerRecharged;
  final int followingNum;
  final int fansNum;
  final int likeNum;
  final int postNum;
  final int taskNum;
  final bool characterDesignGuide;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;

  factory User.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    DateTime? dateTime(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty ? null : DateTime.tryParse(value);
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      code: json['code'] as String? ?? '',
      avatarUrl: (json['avatarUrl'] ?? json['avatar']) as String?,
      phone: json['phone'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      gender: number('gender'),
      birthday: json['birthday'] as String? ?? '',
      wechat: json['wechat'] as String? ?? '',
      country: json['country'] as String? ?? '',
      province: json['province'] as String? ?? '',
      city: json['city'] as String? ?? '',
      memberLevel: number('memberLevel'),
      isMember: json['isMember'] as bool? ?? false,
      memberName: json['memberName'] as String? ?? '',
      memberLabel: json['memberLabel'] as String? ?? '',
      memberCoins: number('memberCoins'),
      otherCoins: number('otherCoins'),
      pointPackageCoins: number('pointPackageCoins'),
      allCoins: number('allCoins'),
      isUsedCoinsRecently: json['isUsedCoinsRecently'] as bool? ?? false,
      memberEndTime: dateTime('memberEndTime'),
      power: number('power'),
      powerConsumed: number('powerConsumed'),
      powerRecharged: number('powerRecharged'),
      followingNum: number('followingNum'),
      fansNum: number('fansNum'),
      likeNum: number('likeNum'),
      postNum: number('postNum'),
      taskNum: number('taskNum'),
      characterDesignGuide: json['characterDesignGuide'] as bool? ?? false,
      status: number('status'),
      createTime: dateTime('createTime'),
      updateTime: dateTime('updateTime'),
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
        other.gender == gender &&
        other.birthday == birthday &&
        other.wechat == wechat &&
        other.country == country &&
        other.province == province &&
        other.city == city &&
        other.memberLevel == memberLevel &&
        other.isMember == isMember &&
        other.memberName == memberName &&
        other.memberLabel == memberLabel &&
        other.memberCoins == memberCoins &&
        other.otherCoins == otherCoins &&
        other.pointPackageCoins == pointPackageCoins &&
        other.allCoins == allCoins &&
        other.isUsedCoinsRecently == isUsedCoinsRecently &&
        other.memberEndTime == memberEndTime &&
        other.power == power &&
        other.powerConsumed == powerConsumed &&
        other.powerRecharged == powerRecharged &&
        other.followingNum == followingNum &&
        other.fansNum == fansNum &&
        other.likeNum == likeNum &&
        other.postNum == postNum &&
        other.taskNum == taskNum &&
        other.characterDesignGuide == characterDesignGuide &&
        other.status == status &&
        other.createTime == createTime &&
        other.updateTime == updateTime;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    email,
    code,
    avatarUrl,
    phone,
    signature,
    gender,
    birthday,
    wechat,
    country,
    province,
    city,
    memberLevel,
    isMember,
    memberName,
    memberLabel,
    memberCoins,
    otherCoins,
    pointPackageCoins,
    allCoins,
    isUsedCoinsRecently,
    memberEndTime,
    power,
    powerConsumed,
    powerRecharged,
    followingNum,
    fansNum,
    likeNum,
    postNum,
    taskNum,
    characterDesignGuide,
    status,
    createTime,
    updateTime,
  ]);
}
