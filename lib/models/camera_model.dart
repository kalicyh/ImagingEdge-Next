class CameraModel {
  final String address;
  final int port;
  final bool isConnected;
  final List<String> services;

  const CameraModel({
    required this.address,
    required this.port,
    this.isConnected = false,
    this.services = const [],
  });

  CameraModel copyWith({
    String? address,
    int? port,
    bool? isConnected,
    List<String>? services,
  }) {
    return CameraModel(
      address: address ?? this.address,
      port: port ?? this.port,
      isConnected: isConnected ?? this.isConnected,
      services: services ?? this.services,
    );
  }

  @override
  String toString() {
    return 'CameraModel(address: $address, port: $port, isConnected: $isConnected, services: $services)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraModel &&
        other.address == address &&
        other.port == port &&
        other.isConnected == isConnected &&
        _listEquals(other.services, services);
  }

  @override
  int get hashCode {
    return address.hashCode ^
        port.hashCode ^
        isConnected.hashCode ^
        services.hashCode;
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}