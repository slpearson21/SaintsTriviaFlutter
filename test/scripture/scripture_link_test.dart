import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/scripture/scripture_link.dart';

void main() {
  Uri link(String reference) {
    final uri = gospelLibraryUri(reference);
    expect(uri, isNotNull, reason: reference);
    return uri!;
  }

  test('maps a single verse', () {
    expect(
      link('Genesis 1:1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/ot/gen/1?id=p1#p1',
    );
  });

  test('maps a verse range', () {
    expect(
      link('Genesis 2:19-20').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/ot/gen/2'
      '?id=p19-p20#p19',
    );
  });

  test('maps a comma list', () {
    expect(
      link('Alma 1:3, 9, 15').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/bofm/alma/1'
      '?id=p3,p9,p15#p3',
    );
  });

  test('maps a mixed list and range', () {
    expect(
      link('Acts 3:2, 6-7').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/nt/acts/3'
      '?id=p2,p6-p7#p2',
    );
  });

  test('maps D&C, Official Declaration, and the Pearl of Great Price books', () {
    expect(
      link('D&C 1:38').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/dc-testament/dc/1'
      '?id=p38#p38',
    );
    expect(
      link('Official Declaration 1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/dc-testament/od/1',
    );
    expect(
      link('OD 2:4').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/dc-testament/od/2'
      '?id=p4#p4',
    );
    expect(
      link('Joseph Smith—History 1:3').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/pgp/js-h/1'
      '?id=p3#p3',
    );
    expect(
      link('JS—History 1:17').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/pgp/js-h/1'
      '?id=p17#p17',
    );
    expect(
      link('A of F 1:13').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/pgp/a-of-f/1'
      '?id=p13#p13',
    );
    expect(
      link('Articles of Faith 1:1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/pgp/a-of-f/1'
      '?id=p1#p1',
    );
  });

  test('maps Psalms, Song of Solomon, and numbered books', () {
    expect(
      link('Psalms 23:1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/ot/ps/23?id=p1#p1',
    );
    expect(
      link('Song of Solomon 2:1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/ot/song/2'
      '?id=p1#p1',
    );
    expect(
      link('1 Nephi 1:1').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/bofm/1-ne/1'
      '?id=p1#p1',
    );
    expect(
      link('2 Corinthians 9:7').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/nt/2-cor/9'
      '?id=p7#p7',
    );
    expect(
      link('3 John 1:4').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/nt/3-jn/1'
      '?id=p4#p4',
    );
  });

  test('accepts an en dash in a range and in a book name', () {
    expect(
      link('Genesis 2:19–20').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/ot/gen/2'
      '?id=p19-p20#p19',
    );
    expect(
      link('Joseph Smith–Matthew 1:4').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/pgp/js-m/1'
      '?id=p4#p4',
    );
  });

  test(
    'rejects a reversed range, chapter or verse 0, and a trailing comma',
    () {
      expect(gospelLibraryUri('Genesis 2:20-19'), isNull);
      expect(gospelLibraryUri('Genesis 2:20–19'), isNull);
      expect(gospelLibraryUri('Genesis 0:1'), isNull);
      expect(gospelLibraryUri('Genesis 0'), isNull);
      expect(gospelLibraryUri('Genesis 1:0'), isNull);
      expect(gospelLibraryUri('Genesis 1:0-2'), isNull);
      expect(gospelLibraryUri('Genesis 1:1,'), isNull);
      expect(gospelLibraryUri('Alma 1:3, 9,'), isNull);
    },
  );

  test('accepts extra spaces, mixed case, and the long book names', () {
    expect(link('  gEnEsIs   1:1 ').toString(), link('Genesis 1:1').toString());
    expect(link('Psalm 23:1').toString(), link('Psalms 23:1').toString());
    expect(
      link('Doctrine and Covenants 1:38').toString(),
      link('D&C 1:38').toString(),
    );
    expect(
      link('OD 2').toString(),
      'https://www.churchofjesuschrist.org/study/scriptures/dc-testament/od/2',
    );
    expect(
      link('JS\u2013History 1:17').toString(),
      link('JS—History 1:17').toString(),
    );
  });

  test('known references keep their chapter', () {
    expect(link('Genesis 1:1').pathSegments.last, '1');
    expect(link('Psalms 119:105').pathSegments.last, '119');
    expect(link('Psalm 23:1').pathSegments.last, '23');
    expect(link('3 Nephi 11:1').pathSegments.last, '11');
    expect(link('1 Nephi 3:7').pathSegments.last, '3');
    expect(link('D&C 138:1').pathSegments.last, '138');
    expect(link('Official Declaration 1').pathSegments.last, '1');
    expect(link('OD 2').pathSegments.last, '2');
    expect(link('JS—History 1:17').pathSegments.last, '1');
    expect(link('Articles of Faith 1:13').pathSegments.last, '1');
  });

  test('returns null for a reference it cannot parse', () {
    expect(gospelLibraryUri(''), isNull);
    expect(gospelLibraryUri('not a reference'), isNull);
    expect(gospelLibraryUri('Genesis'), isNull);
    expect(gospelLibraryUri('Genesis 1:'), isNull);
    expect(gospelLibraryUri('Foo 1:1'), isNull);
    expect(gospelLibraryUri('1 Nephi 3–4'), isNull);
    expect(gospelLibraryUri('D&C 20 heading'), isNull);
    expect(gospelLibraryUri('Mosiah 11–17'), isNull);
  });

  test('does not add a lang parameter', () {
    final uri = link('John 3:16');
    expect(uri.query, isNot(contains('lang')));
    expect(uri.toString(), isNot(contains('lang=')));
  });

  test('the catalog has every verified slug', () {
    final byVolume = <String, Set<String>>{};
    for (final book in gospelLibraryBooks) {
      byVolume.putIfAbsent(book.volume, () => {}).add(book.slug);
    }
    expect(byVolume['ot'], {
      'gen',
      'ex',
      'lev',
      'num',
      'deut',
      'josh',
      'judg',
      'ruth',
      '1-sam',
      '2-sam',
      '1-kgs',
      '2-kgs',
      '1-chr',
      '2-chr',
      'ezra',
      'neh',
      'esth',
      'job',
      'ps',
      'prov',
      'eccl',
      'song',
      'isa',
      'jer',
      'lam',
      'ezek',
      'dan',
      'hosea',
      'joel',
      'amos',
      'obad',
      'jonah',
      'micah',
      'nahum',
      'hab',
      'zeph',
      'hag',
      'zech',
      'mal',
    });
    expect(byVolume['nt'], {
      'matt',
      'mark',
      'luke',
      'john',
      'acts',
      'rom',
      '1-cor',
      '2-cor',
      'gal',
      'eph',
      'philip',
      'col',
      '1-thes',
      '2-thes',
      '1-tim',
      '2-tim',
      'titus',
      'philem',
      'heb',
      'james',
      '1-pet',
      '2-pet',
      '1-jn',
      '2-jn',
      '3-jn',
      'jude',
      'rev',
    });
    expect(byVolume['bofm'], {
      '1-ne',
      '2-ne',
      'jacob',
      'enos',
      'jarom',
      'omni',
      'w-of-m',
      'mosiah',
      'alma',
      'hel',
      '3-ne',
      '4-ne',
      'morm',
      'ether',
      'moro',
    });
    expect(byVolume['dc-testament'], {'dc', 'od'});
    expect(byVolume['pgp'], {'moses', 'abr', 'js-m', 'js-h', 'a-of-f'});
  });

  test('every bundled reference maps to a book in the catalog', () async {
    const files = [
      'assets/questions/v1/old_testament.json',
      'assets/questions/v1/new_testament.json',
      'assets/questions/v1/book_of_mormon.json',
      'assets/questions/v1/doctrine_and_covenants.json',
      'assets/questions/v1/pearl_of_great_price.json',
    ];
    var count = 0;
    for (final path in files) {
      final questions = jsonDecode(File(path).readAsStringSync()) as List;
      for (final question in questions) {
        final reference = (question as Map)['reference'] as String;
        final parsed = parseScriptureReference(reference);
        expect(parsed, isNotNull, reason: reference);
        expect(
          parsed!.book.volume,
          _volumeForBankFile(path),
          reason: reference,
        );
        final normalized = normalizeScriptureName(reference);
        expect(
          parsed.book.names.any(
            (name) => normalized.startsWith('${normalizeScriptureName(name)} '),
          ),
          isTrue,
          reason: reference,
        );
        expect(
          parsed.uri.toString(),
          matches(_gospelLibraryUrl),
          reason: reference,
        );
        expect(parsed.uri.toString(), isNot(contains('lang=')));
        final bookName = parsed.book.names.firstWhere(
          (name) => normalized.startsWith('${normalizeScriptureName(name)} '),
        );
        final afterBook = normalized
            .substring(normalizeScriptureName(bookName).length)
            .trimLeft();
        final chapter = RegExp(r'^(\d+)').firstMatch(afterBook);
        expect(chapter, isNotNull, reason: reference);
        expect(
          chapter!.group(1),
          parsed.uri.pathSegments.last,
          reason: reference,
        );
        count += 1;
      }
    }
    expect(count, _questionsIn(files));
  });
}

/// Gospel Library chapter URLs this app builds. The query is omitted for a
/// chapter with no verses.
final _gospelLibraryUrl = RegExp(
  r'^https://www\.churchofjesuschrist\.org/study/scriptures/'
  r'(ot|nt|bofm|dc-testament|pgp)/[a-z0-9-]+/[1-9]\d*'
  r'(\?id=p\d+(-p\d+)?(,p\d+(-p\d+)?)*#p\d+)?$',
);

int _questionsIn(List<String> files) {
  var count = 0;
  for (final path in files) {
    count += (jsonDecode(File(path).readAsStringSync()) as List).length;
  }
  return count;
}

String _volumeForBankFile(String path) {
  if (path.endsWith('old_testament.json')) return 'ot';
  if (path.endsWith('new_testament.json')) return 'nt';
  if (path.endsWith('book_of_mormon.json')) return 'bofm';
  if (path.endsWith('doctrine_and_covenants.json')) return 'dc-testament';
  if (path.endsWith('pearl_of_great_price.json')) return 'pgp';
  throw StateError(path);
}
