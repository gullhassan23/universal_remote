import 'tv_brand.dart';

class TvDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final TvBrand brand;
  final String? token;

  TvDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.brand,
    this.token,
  });

  TvDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    TvBrand? brand,
    String? token,
  }) {
    return TvDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      brand: brand ?? this.brand,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'brand': brand.name,
      'token': token,
    };
  }

  factory TvDevice.fromJson(Map<String, dynamic> json) {
    return TvDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      brand: TvBrand.values.firstWhere(
        (b) => b.name == json['brand'],
        orElse: () => TvBrand.androidTv,
      ),
      token: json['token'] as String?,
    );
  }
}

