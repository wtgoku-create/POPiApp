class ProductPlan {
  const ProductPlan({
    required this.id,
    required this.type,
    required this.image,
    required this.title,
    required this.description,
    required this.details,
    required this.level,
    required this.coins,
    required this.months,
    required this.days,
    required this.power,
    required this.videoLength,
    required this.audioLength,
    required this.originalPriceAmount,
    required this.customInfo,
    required this.planCategory,
    required this.pointsGrantMode,
    required this.bonusPointsAmount,
    required this.price,
    required this.oldPrice,
    required this.recommended,
    required this.sortNum,
    required this.status,
    required this.createTime,
    required this.updateTime,
    required this.deleted,
    required this.deleteTime,
  });

  final int id;
  final int type;
  final String image;
  final String title;
  final String description;
  final Object? details;
  final int level;
  final int coins;
  final int months;
  final int days;
  final int power;
  final int videoLength;
  final int audioLength;
  final int originalPriceAmount;
  final ProductPlanCustomInfo? customInfo;
  final String planCategory;
  final String pointsGrantMode;
  final int bonusPointsAmount;
  final int price;
  final int oldPrice;
  final bool recommended;
  final int sortNum;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;
  final bool deleted;
  final DateTime? deleteTime;

  factory ProductPlan.fromJson(Map<String, dynamic> json) {
    final customInfo = json['custom_info'];
    return ProductPlan(
      id: _integer(json['id']),
      type: _integer(json['type']),
      image: json['image']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      details: json['details'],
      level: _integer(json['level']),
      coins: _integer(json['coins']),
      months: _integer(json['months']),
      days: _integer(json['days']),
      power: _integer(json['power']),
      videoLength: _integer(json['videoLength']),
      audioLength: _integer(json['audioLength']),
      originalPriceAmount: _integer(json['original_price_amount']),
      customInfo: customInfo is Map
          ? ProductPlanCustomInfo.fromJson(
              Map<String, dynamic>.from(customInfo),
            )
          : null,
      planCategory: json['planCategory']?.toString() ?? '',
      pointsGrantMode: json['pointsGrantMode']?.toString() ?? '',
      bonusPointsAmount: _integer(json['bonusPointsAmount']),
      price: _integer(json['price']),
      oldPrice: _integer(json['oldPrice']),
      recommended: _boolean(json['recommended']),
      sortNum: _integer(json['sortNum']),
      status: _integer(json['status']),
      createTime: _dateTime(json['createTime']),
      updateTime: _dateTime(json['updateTime']),
      deleted: _boolean(json['deleted']),
      deleteTime: _dateTime(json['deleteTime']),
    );
  }
}

class ProductPlanCustomInfo {
  const ProductPlanCustomInfo({
    required this.buttonText,
    required this.discountInfo,
    required this.featureTitle,
    required this.goalDescription,
    required this.goalTitle,
    required this.newUser,
    required this.pointAmount,
  });

  final String buttonText;
  final String discountInfo;
  final String featureTitle;
  final String goalDescription;
  final String goalTitle;
  final bool newUser;
  final String pointAmount;

  factory ProductPlanCustomInfo.fromJson(Map<String, dynamic> json) {
    return ProductPlanCustomInfo(
      buttonText: json['buttonText']?.toString() ?? '',
      discountInfo: json['discount_info']?.toString() ?? '',
      featureTitle: json['feature_title']?.toString() ?? '',
      goalDescription: json['goal_description']?.toString() ?? '',
      goalTitle: json['goal_title']?.toString() ?? '',
      newUser: _boolean(json['new_user']),
      pointAmount: json['point_amount']?.toString() ?? '',
    );
  }
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}

DateTime? _dateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
