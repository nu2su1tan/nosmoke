class Friend {
  const Friend({required this.name, required this.phone});

  final String name;
  final String phone;

  String get displayName => name.isEmpty ? phone : name;
}
