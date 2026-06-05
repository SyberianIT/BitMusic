class EqPreset {
  final String name;
  final List<double> gains; // 5 bands, dB

  const EqPreset({required this.name, required this.gains});

  static const bands = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

  static const List<EqPreset> defaults = [
    EqPreset(name: 'Ровно',        gains: [0,  0,  0,  0,  0]),
    EqPreset(name: 'Бас',          gains: [7,  5,  1, -1, -2]),
    EqPreset(name: 'Высокие',      gains: [-2,-1,  0,  3,  7]),
    EqPreset(name: 'Рок',          gains: [3,  4,  2,  1,  2]),
    EqPreset(name: 'Поп',          gains: [-1, 2,  4,  2, -1]),
    EqPreset(name: 'Классика',     gains: [4,  3, -1,  2,  3]),
    EqPreset(name: 'Электроника',  gains: [5,  3,  0,  2,  4]),
    EqPreset(name: 'R&B',          gains: [3,  4,  2, -2, -1]),
    EqPreset(name: 'Custom',       gains: [0,  0,  0,  0,  0]),
  ];
}
