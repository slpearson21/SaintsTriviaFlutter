/// Gospel Library links for a trivia reference string.
///
/// Bank references use a full book name, `D&C`, an em dash in
/// Joseph Smith—History, and an ASCII hyphen for verse ranges. An en dash
/// is accepted in those same places. Anything that does not parse returns
/// null so the chip can stay plain text.
library;

/// One book in the Gospel Library canon.
///
/// [volume] and [slug] are the path segments in
/// `https://www.churchofjesuschrist.org/study/scriptures/{volume}/{slug}/{chapter}`.
final class GospelLibraryBook {
  const GospelLibraryBook({
    required this.volume,
    required this.slug,
    required this.names,
  });

  final String volume;
  final String slug;

  /// Names a reference may use, including short forms such as `D&C`.
  final List<String> names;
}

/// A parsed reference and the URL that opens it.
final class ScriptureReferenceLink {
  const ScriptureReferenceLink({required this.book, required this.uri});

  final GospelLibraryBook book;
  final Uri uri;
}

/// Full canon. Slugs that never appear in the question bank were checked
/// against the live site: a real book stays on that slug, and a bad slug
/// ends on the volume index.
const gospelLibraryBooks = <GospelLibraryBook>[
  GospelLibraryBook(volume: 'ot', slug: 'gen', names: ['Genesis']),
  GospelLibraryBook(volume: 'ot', slug: 'ex', names: ['Exodus']),
  GospelLibraryBook(volume: 'ot', slug: 'lev', names: ['Leviticus']),
  GospelLibraryBook(volume: 'ot', slug: 'num', names: ['Numbers']),
  GospelLibraryBook(volume: 'ot', slug: 'deut', names: ['Deuteronomy']),
  GospelLibraryBook(volume: 'ot', slug: 'josh', names: ['Joshua']),
  GospelLibraryBook(volume: 'ot', slug: 'judg', names: ['Judges']),
  GospelLibraryBook(volume: 'ot', slug: 'ruth', names: ['Ruth']),
  GospelLibraryBook(volume: 'ot', slug: '1-sam', names: ['1 Samuel']),
  GospelLibraryBook(volume: 'ot', slug: '2-sam', names: ['2 Samuel']),
  GospelLibraryBook(volume: 'ot', slug: '1-kgs', names: ['1 Kings']),
  GospelLibraryBook(volume: 'ot', slug: '2-kgs', names: ['2 Kings']),
  GospelLibraryBook(volume: 'ot', slug: '1-chr', names: ['1 Chronicles']),
  GospelLibraryBook(volume: 'ot', slug: '2-chr', names: ['2 Chronicles']),
  GospelLibraryBook(volume: 'ot', slug: 'ezra', names: ['Ezra']),
  GospelLibraryBook(volume: 'ot', slug: 'neh', names: ['Nehemiah']),
  GospelLibraryBook(volume: 'ot', slug: 'esth', names: ['Esther']),
  GospelLibraryBook(volume: 'ot', slug: 'job', names: ['Job']),
  GospelLibraryBook(volume: 'ot', slug: 'ps', names: ['Psalms', 'Psalm']),
  GospelLibraryBook(volume: 'ot', slug: 'prov', names: ['Proverbs']),
  GospelLibraryBook(volume: 'ot', slug: 'eccl', names: ['Ecclesiastes']),
  GospelLibraryBook(volume: 'ot', slug: 'song', names: ['Song of Solomon']),
  GospelLibraryBook(volume: 'ot', slug: 'isa', names: ['Isaiah']),
  GospelLibraryBook(volume: 'ot', slug: 'jer', names: ['Jeremiah']),
  GospelLibraryBook(volume: 'ot', slug: 'lam', names: ['Lamentations']),
  GospelLibraryBook(volume: 'ot', slug: 'ezek', names: ['Ezekiel']),
  GospelLibraryBook(volume: 'ot', slug: 'dan', names: ['Daniel']),
  GospelLibraryBook(volume: 'ot', slug: 'hosea', names: ['Hosea']),
  GospelLibraryBook(volume: 'ot', slug: 'joel', names: ['Joel']),
  GospelLibraryBook(volume: 'ot', slug: 'amos', names: ['Amos']),
  GospelLibraryBook(volume: 'ot', slug: 'obad', names: ['Obadiah']),
  GospelLibraryBook(volume: 'ot', slug: 'jonah', names: ['Jonah']),
  GospelLibraryBook(volume: 'ot', slug: 'micah', names: ['Micah']),
  GospelLibraryBook(volume: 'ot', slug: 'nahum', names: ['Nahum']),
  GospelLibraryBook(volume: 'ot', slug: 'hab', names: ['Habakkuk']),
  GospelLibraryBook(volume: 'ot', slug: 'zeph', names: ['Zephaniah']),
  GospelLibraryBook(volume: 'ot', slug: 'hag', names: ['Haggai']),
  GospelLibraryBook(volume: 'ot', slug: 'zech', names: ['Zechariah']),
  GospelLibraryBook(volume: 'ot', slug: 'mal', names: ['Malachi']),
  GospelLibraryBook(volume: 'nt', slug: 'matt', names: ['Matthew']),
  GospelLibraryBook(volume: 'nt', slug: 'mark', names: ['Mark']),
  GospelLibraryBook(volume: 'nt', slug: 'luke', names: ['Luke']),
  GospelLibraryBook(volume: 'nt', slug: 'john', names: ['John']),
  GospelLibraryBook(volume: 'nt', slug: 'acts', names: ['Acts']),
  GospelLibraryBook(volume: 'nt', slug: 'rom', names: ['Romans']),
  GospelLibraryBook(volume: 'nt', slug: '1-cor', names: ['1 Corinthians']),
  GospelLibraryBook(volume: 'nt', slug: '2-cor', names: ['2 Corinthians']),
  GospelLibraryBook(volume: 'nt', slug: 'gal', names: ['Galatians']),
  GospelLibraryBook(volume: 'nt', slug: 'eph', names: ['Ephesians']),
  GospelLibraryBook(volume: 'nt', slug: 'philip', names: ['Philippians']),
  GospelLibraryBook(volume: 'nt', slug: 'col', names: ['Colossians']),
  GospelLibraryBook(volume: 'nt', slug: '1-thes', names: ['1 Thessalonians']),
  GospelLibraryBook(volume: 'nt', slug: '2-thes', names: ['2 Thessalonians']),
  GospelLibraryBook(volume: 'nt', slug: '1-tim', names: ['1 Timothy']),
  GospelLibraryBook(volume: 'nt', slug: '2-tim', names: ['2 Timothy']),
  GospelLibraryBook(volume: 'nt', slug: 'titus', names: ['Titus']),
  GospelLibraryBook(volume: 'nt', slug: 'philem', names: ['Philemon']),
  GospelLibraryBook(volume: 'nt', slug: 'heb', names: ['Hebrews']),
  GospelLibraryBook(volume: 'nt', slug: 'james', names: ['James']),
  GospelLibraryBook(volume: 'nt', slug: '1-pet', names: ['1 Peter']),
  GospelLibraryBook(volume: 'nt', slug: '2-pet', names: ['2 Peter']),
  GospelLibraryBook(volume: 'nt', slug: '1-jn', names: ['1 John']),
  GospelLibraryBook(volume: 'nt', slug: '2-jn', names: ['2 John']),
  GospelLibraryBook(volume: 'nt', slug: '3-jn', names: ['3 John']),
  GospelLibraryBook(volume: 'nt', slug: 'jude', names: ['Jude']),
  GospelLibraryBook(volume: 'nt', slug: 'rev', names: ['Revelation']),
  GospelLibraryBook(volume: 'bofm', slug: '1-ne', names: ['1 Nephi']),
  GospelLibraryBook(volume: 'bofm', slug: '2-ne', names: ['2 Nephi']),
  GospelLibraryBook(volume: 'bofm', slug: 'jacob', names: ['Jacob']),
  GospelLibraryBook(volume: 'bofm', slug: 'enos', names: ['Enos']),
  GospelLibraryBook(volume: 'bofm', slug: 'jarom', names: ['Jarom']),
  GospelLibraryBook(volume: 'bofm', slug: 'omni', names: ['Omni']),
  GospelLibraryBook(volume: 'bofm', slug: 'w-of-m', names: ['Words of Mormon']),
  GospelLibraryBook(volume: 'bofm', slug: 'mosiah', names: ['Mosiah']),
  GospelLibraryBook(volume: 'bofm', slug: 'alma', names: ['Alma']),
  GospelLibraryBook(volume: 'bofm', slug: 'hel', names: ['Helaman']),
  GospelLibraryBook(volume: 'bofm', slug: '3-ne', names: ['3 Nephi']),
  GospelLibraryBook(volume: 'bofm', slug: '4-ne', names: ['4 Nephi']),
  GospelLibraryBook(volume: 'bofm', slug: 'morm', names: ['Mormon']),
  GospelLibraryBook(volume: 'bofm', slug: 'ether', names: ['Ether']),
  GospelLibraryBook(volume: 'bofm', slug: 'moro', names: ['Moroni']),
  GospelLibraryBook(
    volume: 'dc-testament',
    slug: 'dc',
    names: ['D&C', 'Doctrine and Covenants'],
  ),
  GospelLibraryBook(
    volume: 'dc-testament',
    slug: 'od',
    names: ['Official Declaration', 'OD'],
  ),
  GospelLibraryBook(volume: 'pgp', slug: 'moses', names: ['Moses']),
  GospelLibraryBook(volume: 'pgp', slug: 'abr', names: ['Abraham']),
  GospelLibraryBook(
    volume: 'pgp',
    slug: 'js-m',
    names: ['Joseph Smith—Matthew', 'JS—Matthew'],
  ),
  GospelLibraryBook(
    volume: 'pgp',
    slug: 'js-h',
    names: ['Joseph Smith—History', 'JS—History'],
  ),
  GospelLibraryBook(
    volume: 'pgp',
    slug: 'a-of-f',
    names: ['Articles of Faith', 'A of F'],
  ),
];

/// The Gospel Library URL for [reference], or null when it cannot be parsed.
Uri? gospelLibraryUri(String reference) {
  return parseScriptureReference(reference)?.uri;
}

/// Parses [reference] into a book from [gospelLibraryBooks] and a URL.
///
/// The URL is
/// `https://www.churchofjesuschrist.org/study/scriptures/{vol}/{slug}/{chapter}?id=pV#pV`.
/// A range is `?id=p17-p18#p17`. A comma list is `?id=p7,p10#p7`. A mix such
/// as Acts 3:2, 6-7 is `?id=p2,p6-p7#p2`. No `lang` parameter is added.
/// Official Declaration uses the declaration number as the chapter and omits
/// the verse query when the reference has no verses.
ScriptureReferenceLink? parseScriptureReference(String reference) {
  final normalized = normalizeScriptureName(reference);
  if (normalized.isEmpty) return null;

  GospelLibraryBook? book;
  var matchedName = '';
  for (final entry in gospelLibraryBooks) {
    for (final name in entry.names) {
      final key = normalizeScriptureName(name);
      final matches = normalized == key || normalized.startsWith('$key ');
      if (matches && key.length > matchedName.length) {
        book = entry;
        matchedName = key;
      }
    }
  }
  if (book == null) return null;

  final rest = normalized.substring(matchedName.length).trim();
  final chapterMatch = RegExp(r'^(\d+)(?::(.*))?$').firstMatch(rest);
  if (chapterMatch == null) return null;
  final chapter = int.tryParse(chapterMatch.group(1)!);
  if (chapter == null || chapter <= 0) return null;

  final hasVerseMark = rest.contains(':');
  final verseSpec = chapterMatch.group(2)?.trim();
  if (hasVerseMark && (verseSpec == null || verseSpec.isEmpty)) return null;
  final verses = verseSpec == null || verseSpec.isEmpty
      ? null
      : _verseId(verseSpec);
  if (hasVerseMark && verses == null) return null;

  final path =
      'https://www.churchofjesuschrist.org/study/scriptures/'
      '${book.volume}/${book.slug}/$chapter';
  final uri = verses == null
      ? Uri.parse(path)
      : Uri.parse('$path?id=${verses.id}#${verses.fragment}');
  return ScriptureReferenceLink(book: book, uri: uri);
}

/// Lowercase, collapsed whitespace, and em/en dashes folded to a hyphen.
String normalizeScriptureName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll(RegExp(r'\s+'), ' ');
}

final class _VerseId {
  const _VerseId(this.id, this.fragment);

  final String id;
  final String fragment;
}

_VerseId? _verseId(String spec) {
  final parts = spec.split(',');
  if (parts.isEmpty) return null;
  final pieces = <String>[];
  int? first;
  for (final raw in parts) {
    final part = raw.trim();
    if (part.isEmpty) return null;
    final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(part);
    if (range != null) {
      final start = int.tryParse(range.group(1)!);
      final end = int.tryParse(range.group(2)!);
      if (start == null || end == null || start <= 0 || end < start) {
        return null;
      }
      first ??= start;
      pieces.add('p$start-p$end');
      continue;
    }
    final single = RegExp(r'^(\d+)$').firstMatch(part);
    if (single == null) return null;
    final verse = int.tryParse(single.group(1)!);
    if (verse == null || verse <= 0) return null;
    first ??= verse;
    pieces.add('p$verse');
  }
  if (first == null || pieces.isEmpty) return null;
  return _VerseId(pieces.join(','), 'p$first');
}
