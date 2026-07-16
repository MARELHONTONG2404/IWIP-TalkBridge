/// Frasa siap pakai HSE / operasional site IWIP (Indonesia ↔ 中文).
class IwipHsePhrase {
  final String id;
  final String idText;
  final String zhText;

  const IwipHsePhrase({
    required this.id,
    required this.idText,
    required this.zhText,
  });
}

const List<IwipHsePhrase> kIwipHsePhrases = [
  IwipHsePhrase(
    id: 'hse_1',
    idText: 'Pakailah APD sebelum masuk area kerja.',
    zhText: '进入工作区域前请佩戴好个人防护装备。',
  ),
  IwipHsePhrase(
    id: 'hse_2',
    idText: 'Jangan masuk area terlarang tanpa izin.',
    zhText: '未经许可请勿进入禁区。',
  ),
  IwipHsePhrase(
    id: 'hse_3',
    idText: 'Jika ada darurat, segera ke titik kumpul.',
    zhText: '如有紧急情况，请立即前往集合点。',
  ),
  IwipHsePhrase(
    id: 'hse_4',
    idText: 'Laporkan bahaya atau kejadian ke pengawas.',
    zhText: '请向主管报告危险或事故。',
  ),
  IwipHsePhrase(
    id: 'hse_5',
    idText: 'Hati-hati, area smelter panas dan berisiko tinggi.',
    zhText: '请小心，冶炼厂区域高温且风险较高。',
  ),
  IwipHsePhrase(
    id: 'hse_6',
    idText: 'Matikan mesin sebelum memperbaiki.',
    zhText: '维修前请先关闭机器。',
  ),
  IwipHsePhrase(
    id: 'hse_7',
    idText: 'Tolong ulangi lebih lambat.',
    zhText: '请再说慢一点。',
  ),
  IwipHsePhrase(
    id: 'hse_8',
    idText: 'Saya tidak mengerti. Bisakah ditulis?',
    zhText: '我听不懂。可以写下来吗？',
  ),
];
