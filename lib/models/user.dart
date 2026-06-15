class User {
  final int? id;
  final String nama;
  final String email;
  final String password;
  final String telepon;
  final String? profilePicture;

  User({
    this.id,
    required this.nama,
    required this.email,
    required this.password,
    required this.telepon,
    this.profilePicture,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nama': nama,
      'email': email,
      'password': password,
      'telepon': telepon,
      if (profilePicture != null) 'profile_picture': profilePicture,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nama: map['nama'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      telepon: map['telepon'] as String? ?? '',
      profilePicture: map['profile_picture'] as String?,
    );
  }

  User copyWith({
    int? id,
    String? nama,
    String? email,
    String? password,
    String? telepon,
    String? profilePicture,
  }) {
    return User(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      password: password ?? this.password,
      telepon: telepon ?? this.telepon,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }
}
