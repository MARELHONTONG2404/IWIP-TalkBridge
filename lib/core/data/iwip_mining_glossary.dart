/// Kamus istilah teknis pertambangan & industri PT IWIP (id / en / zh).
class MiningGlossaryEntry {
  final String id;
  final String en;
  final String zh;
  final List<String> idVariants;
  final List<String> enVariants;

  const MiningGlossaryEntry({
    required this.id,
    required this.en,
    required this.zh,
    this.idVariants = const [],
    this.enVariants = const [],
  });
}

const List<MiningGlossaryEntry> kIwipMiningGlossary = [
  MiningGlossaryEntry(
    id: 'crusher',
    en: 'crusher',
    zh: '破碎机',
    idVariants: ['kruser', 'cruser', 'pembreak'],
    enVariants: ['crushing machine'],
  ),
  MiningGlossaryEntry(
    id: 'conveyor',
    en: 'conveyor',
    zh: '输送机',
    idVariants: ['konveyor', 'conveyer', 'ban berjalan'],
    enVariants: ['conveyor belt', 'belt conveyor'],
  ),
  MiningGlossaryEntry(
    id: 'stockpile',
    en: 'stockpile',
    zh: '堆场',
    idVariants: ['stok pile', 'stokpile', 'tumpukan bijih'],
    enVariants: ['ore stockpile'],
  ),
  MiningGlossaryEntry(
    id: 'smelter',
    en: 'smelter',
    zh: '冶炼厂',
    idVariants: ['smelder', 'smeltar', 'peleburan'],
    enVariants: ['smelting plant'],
  ),
  MiningGlossaryEntry(
    id: 'drilling',
    en: 'drilling',
    zh: '钻探',
    idVariants: ['pengeboran', 'bor', 'driling'],
    enVariants: ['drill', 'drilling operation'],
  ),
  MiningGlossaryEntry(
    id: 'excavator',
    en: 'excavator',
    zh: '挖掘机',
    idVariants: ['ekskavator', 'alat gali'],
    enVariants: ['digger', 'hoe'],
  ),
  MiningGlossaryEntry(
    id: 'haul truck',
    en: 'haul truck',
    zh: '矿用卡车',
    idVariants: ['truk angkut', 'dump truck', 'hauling truck'],
    enVariants: ['dump truck', 'mining truck'],
  ),
  MiningGlossaryEntry(
    id: 'blasting',
    en: 'blasting',
    zh: '爆破',
    idVariants: ['peledakan', 'ledakan'],
    enVariants: ['blast', 'explosion'],
  ),
  MiningGlossaryEntry(
    id: 'ore',
    en: 'ore',
    zh: '矿石',
    idVariants: ['bijih', 'mineral'],
    enVariants: ['mineral ore'],
  ),
  MiningGlossaryEntry(
    id: 'nickel',
    en: 'nickel',
    zh: '镍',
    idVariants: ['nikel', 'nickle'],
    enVariants: ['ni'],
  ),
  MiningGlossaryEntry(
    id: 'furnace',
    en: 'furnace',
    zh: '熔炉',
    idVariants: ['tungku', 'oven peleburan'],
    enVariants: ['kiln'],
  ),
  MiningGlossaryEntry(
    id: 'safety helmet',
    en: 'safety helmet',
    zh: '安全帽',
    idVariants: ['helm keselamatan', 'helm proyek'],
    enVariants: ['hard hat', 'helmet'],
  ),
  MiningGlossaryEntry(
    id: 'PPE',
    en: 'PPE',
    zh: '个人防护装备',
    idVariants: ['apd', 'alat pelindung diri', 'ppe'],
    enVariants: ['personal protective equipment'],
  ),
  MiningGlossaryEntry(
    id: 'muster point',
    en: 'muster point',
    zh: '集合点',
    idVariants: ['titik kumpul', 'titik kumpulan'],
    enVariants: ['assembly point', 'evacuation point'],
  ),
  MiningGlossaryEntry(
    id: 'lockout tagout',
    en: 'lockout tagout',
    zh: '上锁挂牌',
    idVariants: ['loto', 'kunci dan label'],
    enVariants: ['loto', 'lock out tag out'],
  ),
  MiningGlossaryEntry(
    id: 'hot work',
    en: 'hot work',
    zh: '动火作业',
    idVariants: ['pekerjaan panas', 'kerja panas'],
    enVariants: ['hot work permit'],
  ),
  MiningGlossaryEntry(
    id: 'confined space',
    en: 'confined space',
    zh: '受限空间',
    idVariants: ['ruang terbatas', 'ruang sempit'],
    enVariants: ['enclosed space'],
  ),
  MiningGlossaryEntry(
    id: 'hazard',
    en: 'hazard',
    zh: '危险',
    idVariants: ['bahaya', 'risiko'],
    enVariants: ['danger', 'risk'],
  ),
  MiningGlossaryEntry(
    id: 'permit to work',
    en: 'permit to work',
    zh: '工作许可证',
    idVariants: ['izin kerja', 'surat izin kerja'],
    enVariants: ['work permit', 'ptw'],
  ),
];
