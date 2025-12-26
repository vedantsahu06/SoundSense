class SoundCategory {
  static const Map<String, String> priorities = {
    // 🚨 CRITICAL - Immediate danger
    'Siren': 'critical',
    'Car horn': 'critical',
    'Smoke alarm': 'critical',
    'Fire alarm': 'critical',
    'Scream': 'critical',
    'Glass breaking': 'critical',
    'Gunshot': 'critical',

    // ⚠️ IMPORTANT - Needs attention
    'Dog bark': 'important',
    'Doorbell': 'important',
    'Knock': 'important',
    'Baby cry': 'important',
    'Phone ring': 'important',
    'Alarm clock': 'important',

    // 📢 NORMAL - Awareness
    'Speech': 'normal',
    'Music': 'normal',
    'Bird': 'normal',
    'Rain': 'normal',
    'Traffic': 'normal',
    'Footsteps': 'normal',
  };

  static String getPriority(String soundName) {
    return priorities[soundName] ?? 'normal';
  }

  static bool isCritical(String soundName) {
    return getPriority(soundName) == 'critical';
  }

  static bool isImportant(String soundName) {
    return getPriority(soundName) == 'important';
  }
}