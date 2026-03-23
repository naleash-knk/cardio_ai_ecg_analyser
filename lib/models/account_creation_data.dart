class AccountCreationData {
  const AccountCreationData({
    required this.name,
    required this.age,
    required this.gender,
    required this.email,
    required this.complaints,
    required this.otherSymptoms,
    required this.history,
    required this.otherHistory,
    required this.hasMedications,
    required this.medications,
    required this.hasAnticoagulant,
    required this.anticoagulant,
  });

  final String name;
  final String age;
  final String gender;
  final String email;
  final Map<String, bool> complaints;
  final String otherSymptoms;
  final Map<String, bool> history;
  final String otherHistory;
  final bool hasMedications;
  final String medications;
  final bool hasAnticoagulant;
  final String anticoagulant;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'age': age,
      'gender': gender,
      'email': email,
      'complaints': complaints,
      'otherSymptoms': otherSymptoms,
      'history': history,
      'otherHistory': otherHistory,
      'hasMedications': hasMedications,
      'medications': medications,
      'hasAnticoagulant': hasAnticoagulant,
      'anticoagulant': anticoagulant,
    };
  }

  factory AccountCreationData.fromMap(Map<String, dynamic> map) {
    return AccountCreationData(
      name: (map['name'] ?? '').toString(),
      age: (map['age'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      complaints: _readBoolMap(map['complaints']),
      otherSymptoms: (map['otherSymptoms'] ?? '').toString(),
      history: _readBoolMap(map['history']),
      otherHistory: (map['otherHistory'] ?? '').toString(),
      hasMedications: map['hasMedications'] == true,
      medications: (map['medications'] ?? '').toString(),
      hasAnticoagulant: map['hasAnticoagulant'] == true,
      anticoagulant: (map['anticoagulant'] ?? '').toString(),
    );
  }

  AccountCreationData copyWith({
    String? name,
    String? age,
    String? gender,
    String? email,
    Map<String, bool>? complaints,
    String? otherSymptoms,
    Map<String, bool>? history,
    String? otherHistory,
    bool? hasMedications,
    String? medications,
    bool? hasAnticoagulant,
    String? anticoagulant,
  }) {
    return AccountCreationData(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      complaints: complaints ?? this.complaints,
      otherSymptoms: otherSymptoms ?? this.otherSymptoms,
      history: history ?? this.history,
      otherHistory: otherHistory ?? this.otherHistory,
      hasMedications: hasMedications ?? this.hasMedications,
      medications: medications ?? this.medications,
      hasAnticoagulant: hasAnticoagulant ?? this.hasAnticoagulant,
      anticoagulant: anticoagulant ?? this.anticoagulant,
    );
  }

  static Map<String, bool> _readBoolMap(Object? raw) {
    if (raw is! Map) {
      return <String, bool>{};
    }
    final Map<String, bool> values = <String, bool>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      values[entry.key.toString()] = entry.value == true;
    }
    return values;
  }
}
