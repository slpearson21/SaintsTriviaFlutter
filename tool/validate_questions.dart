import 'dart:io';

import 'package:saints_trivia_flutter/data/questions/question_assets.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_exception.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_loader.dart';
import 'package:saints_trivia_flutter/data/questions/review_status.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/scripture/scripture_link.dart';

/// How many questions each volume of [QuestionAssets.v1Directory] must have.
///
/// Sample fixtures are not held to this. With `--require-approved`, only
/// questions whose review status is `approved` count.
const int minimumQuestionsPerVolume = 100;

/// Validates the offline question bank from the repository root.
///
/// Pull-request CI runs this with no flags (structure only). A release
/// workflow should pass `--require-approved` (alias `--release`). That flag
/// rejects any question that is still `draft` and, for the bundled bank,
/// counts only approved questions toward [minimumQuestionsPerVolume]. The
/// app does not use this flag: a release build skips drafts instead.
///
/// This file must not import `package:saints_trivia_flutter/data/questions/questions.dart`.
/// That barrel includes the Flutter asset loader, and `dart run` has no engine.
Future<void> main(List<String> args) async {
  exitCode = await runQuestionBankValidator(args);
}

/// Runs the validator and returns a process exit code.
///
/// `0` when the bank passes, `1` when content is invalid, `64` when the
/// arguments are wrong. [output] and [errorOutput] default to the process
/// stdout and stderr.
Future<int> runQuestionBankValidator(
  List<String> args, {
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  const usage = '''
Validate the offline scripture question bank.

Run this from the repository root.

Usage:
  dart run tool/validate_questions.dart [--require-approved|--release] [--bank <directory>]

Options:
  --require-approved, --release
      Reject any question whose reviewStatus is not "approved".
      For assets/questions/v1, also require at least 100 approved
      questions in each volume. Pull-request CI omits this flag.
      The release pipeline should pass it. The app does not: a release
      build skips drafts instead of failing the load.

  --bank <directory>
      Directory of volume JSON files. Defaults to assets/questions/v1.
      The v1 schema rules are always what is checked, along with
      reference, whitespace, duplicate-prompt, and chapter rules.
      The 100-question minimum applies only to the bundled
      assets/questions/v1 bank.

  --help
      Show this message.
''';

  var requireApproved = false;
  var directory = QuestionAssets.v1Directory;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      out.writeln(usage.trimRight());
      return 0;
    }
    if (arg == '--require-approved' || arg == '--release') {
      requireApproved = true;
      continue;
    }
    if (arg == '--bank') {
      if (i + 1 >= args.length) {
        err.writeln('Missing directory after --bank.');
        err.writeln(usage.trimRight());
        return 64;
      }
      i += 1;
      directory = args[i];
      continue;
    }
    err.writeln('Unknown argument "$arg".');
    err.writeln(usage.trimRight());
    return 64;
  }

  final assets = QuestionAssets(directory: directory);
  final loader = QuestionBankLoader(
    read: (path) => File(path).readAsString(),
    assets: assets,
  );

  try {
    final bank = await loader.load();
    final violations = <QuestionBankViolation>[
      ...questionContentViolations(bank, assets),
      if (requireApproved) ...unapprovedQuestionViolations(bank, assets),
      if (isBundledQuestionBank(directory))
        ...bundledVolumeMinimumViolations(
          bank,
          approvedOnly: requireApproved,
          directory: directory,
        ),
    ];
    if (violations.isNotEmpty) {
      err.writeln(QuestionBankException(violations));
      return 1;
    }
    final counts = [
      for (final volume in ScriptureVolume.values)
        '${volume.code}=${bank.forVolume(volume).length}',
    ].join(', ');
    final mode = requireApproved ? 'release, approved only' : 'structure only';
    out.writeln(
      'Validated ${bank.length} questions ($counts), '
      'schema v${bank.schemaVersion}, $mode, from $directory.',
    );
    return 0;
  } on QuestionBankException catch (error) {
    err.writeln(error);
    return 1;
  }
}

/// True for the bundled v1 directory, including a trailing slash or `./`.
bool isBundledQuestionBank(String directory) {
  var normalized = directory.trim().replaceAll('\\', '/');
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized == QuestionAssets.v1Directory;
}

/// One violation per question that is not `approved`.
List<QuestionBankViolation> unapprovedQuestionViolations(
  QuestionBank bank,
  QuestionAssets assets,
) {
  final violations = <QuestionBankViolation>[];
  for (final volume in ScriptureVolume.values) {
    final questions = bank.forVolume(volume);
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      if (question.reviewStatus == ReviewStatus.approved) {
        continue;
      }
      violations.add(
        QuestionBankViolation(
          kind: QuestionBankViolationKind.notApproved,
          message:
              'Question ${question.id} is "${question.reviewStatus.value}". '
              'The release validator only allows approved questions.',
          assetPath: assets.pathFor(volume),
          questionId: question.id,
          index: index,
          field: 'reviewStatus',
        ),
      );
    }
  }
  return violations;
}

/// Violations for bundled volumes under [minimumQuestionsPerVolume].
///
/// When [approvedOnly] is true, drafts do not count. This is not applied to
/// fixture directories.
List<QuestionBankViolation> bundledVolumeMinimumViolations(
  QuestionBank bank, {
  required bool approvedOnly,
  int minimum = minimumQuestionsPerVolume,
  String directory = QuestionAssets.v1Directory,
}) {
  final assets = QuestionAssets(directory: directory);
  final violations = <QuestionBankViolation>[];
  for (final volume in ScriptureVolume.values) {
    final questions = bank.forVolume(volume);
    final count = approvedOnly
        ? questions
              .where(
                (question) => question.reviewStatus == ReviewStatus.approved,
              )
              .length
        : questions.length;
    if (count >= minimum) {
      continue;
    }
    final counted = approvedOnly ? 'approved questions' : 'questions';
    violations.add(
      QuestionBankViolation(
        kind: QuestionBankViolationKind.tooFewQuestions,
        message:
            '${volume.code} has $count $counted; '
            'the bundled bank needs at least $minimum per volume.',
        assetPath: assets.pathFor(volume),
      ),
    );
  }
  return violations;
}

/// Longest chapter in the books [scriptureChapterCounts] describes.
///
/// Psalm 119 has 176 verses, and no other chapter in that edition is longer.
/// Verse numbers are checked only when the chapter itself is inside the table.
const longestChapterVerseCount = 176;

/// Chapter counts for the Latter-day Saint edition of each Gospel Library book.
///
/// Keys are [GospelLibraryBook.slug]. Official Declaration uses the
/// declaration number as its chapter, so `od` is 2.
const scriptureChapterCounts = <String, int>{
  'gen': 50,
  'ex': 40,
  'lev': 27,
  'num': 36,
  'deut': 34,
  'josh': 24,
  'judg': 21,
  'ruth': 4,
  '1-sam': 31,
  '2-sam': 24,
  '1-kgs': 22,
  '2-kgs': 25,
  '1-chr': 29,
  '2-chr': 36,
  'ezra': 10,
  'neh': 13,
  'esth': 10,
  'job': 42,
  'ps': 150,
  'prov': 31,
  'eccl': 12,
  'song': 8,
  'isa': 66,
  'jer': 52,
  'lam': 5,
  'ezek': 48,
  'dan': 12,
  'hosea': 14,
  'joel': 3,
  'amos': 9,
  'obad': 1,
  'jonah': 4,
  'micah': 7,
  'nahum': 3,
  'hab': 3,
  'zeph': 3,
  'hag': 2,
  'zech': 14,
  'mal': 4,
  'matt': 28,
  'mark': 16,
  'luke': 24,
  'john': 21,
  'acts': 28,
  'rom': 16,
  '1-cor': 16,
  '2-cor': 13,
  'gal': 6,
  'eph': 6,
  'philip': 4,
  'col': 4,
  '1-thes': 5,
  '2-thes': 3,
  '1-tim': 6,
  '2-tim': 4,
  'titus': 3,
  'philem': 1,
  'heb': 13,
  'james': 5,
  '1-pet': 5,
  '2-pet': 3,
  '1-jn': 5,
  '2-jn': 1,
  '3-jn': 1,
  'jude': 1,
  'rev': 22,
  '1-ne': 22,
  '2-ne': 33,
  'jacob': 7,
  'enos': 1,
  'jarom': 1,
  'omni': 1,
  'w-of-m': 1,
  'mosiah': 29,
  'alma': 63,
  'hel': 16,
  '3-ne': 30,
  '4-ne': 1,
  'morm': 9,
  'ether': 15,
  'moro': 10,
  'dc': 138,
  'od': 2,
  'moses': 8,
  'abr': 5,
  'js-m': 1,
  'js-h': 1,
  'a-of-f': 1,
};

const _bankVolumeForGospelLibrary = <String, ScriptureVolume>{
  'ot': ScriptureVolume.ot,
  'nt': ScriptureVolume.nt,
  'bofm': ScriptureVolume.bom,
  'dc-testament': ScriptureVolume.dc,
  'pgp': ScriptureVolume.pgp,
};

/// Content rules that sit on top of the v1 schema.
///
/// The loader already accepted [bank]. These checks use
/// [QuestionBankViolationKind.invalidValue] so the tool does not need a
/// new violation kind.
List<QuestionBankViolation> questionContentViolations(
  QuestionBank bank,
  QuestionAssets assets,
) {
  final violations = <QuestionBankViolation>[];
  final seenPrompts = <String, String>{};
  final nextIndex = <ScriptureVolume, int>{};

  for (final question in bank.questions) {
    final index = nextIndex[question.volume] ?? 0;
    nextIndex[question.volume] = index + 1;
    final path = assets.pathFor(question.volume);

    void add(String message, {required String field}) {
      violations.add(
        QuestionBankViolation(
          kind: QuestionBankViolationKind.invalidValue,
          message: message,
          assetPath: path,
          questionId: question.id,
          index: index,
          field: field,
        ),
      );
    }

    _checkEdgeWhitespace(question.prompt, 'prompt', add);
    _checkEdgeWhitespace(question.explanation, 'explanation', add);
    _checkEdgeWhitespace(question.reference, 'reference', add);
    for (var i = 0; i < question.options.length; i++) {
      _checkEdgeWhitespace(
        question.options[i],
        'options',
        add,
        label: 'Option ${i + 1}',
      );
    }
    if (question.prompt.contains('\n') || question.prompt.contains('\r')) {
      add('Field "prompt" must be a single line.', field: 'prompt');
    }

    final folded = _foldedPrompt(question.prompt);
    final previous = seenPrompts[folded];
    if (previous != null) {
      add(
        'Prompt repeats $previous after case-folding and collapsing whitespace.',
        field: 'prompt',
      );
    } else {
      seenPrompts[folded] = question.id;
    }

    final parsed = parseScriptureReference(question.reference);
    if (parsed == null) {
      add(
        'Reference "${question.reference}" does not parse as scripture.',
        field: 'reference',
      );
      continue;
    }

    final bookVolume = _bankVolumeForGospelLibrary[parsed.book.volume];
    if (bookVolume != question.volume) {
      add(
        'Reference "${question.reference}" belongs to '
        '${parsed.book.volume}, not ${question.volume.code}.',
        field: 'reference',
      );
    }

    final chapters = scriptureChapterCounts[parsed.book.slug];
    final chapter = int.tryParse(parsed.uri.pathSegments.last);
    if (chapters == null || chapter == null || chapter > chapters) {
      final name = parsed.book.names.first;
      final limit = chapters == null
          ? 'no recorded chapter count'
          : '$chapters chapters';
      add(
        'Reference "${question.reference}" uses chapter $chapter, but $name has $limit.',
        field: 'reference',
      );
    } else {
      for (final verse in _verseNumbers(parsed.uri)) {
        if (verse < 1 || verse > longestChapterVerseCount) {
          add(
            'Reference "${question.reference}" verse $verse is outside '
            '1–$longestChapterVerseCount.',
            field: 'reference',
          );
        }
      }
    }
  }

  return violations;
}

/// Verse numbers from a Gospel Library `id=p1,p6-p7` query.
Iterable<int> _verseNumbers(Uri uri) sync* {
  final id = uri.queryParameters['id'];
  if (id == null || id.isEmpty) return;
  final partPattern = RegExp(r'^p(\d+)(?:-p(\d+))?$');
  for (final part in id.split(',')) {
    final match = partPattern.firstMatch(part);
    if (match == null) continue;
    yield int.parse(match.group(1)!);
    final end = match.group(2);
    if (end != null) yield int.parse(end);
  }
}

/// Case-folded prompt with whitespace collapsed, for duplicate detection.
String _foldedPrompt(String prompt) {
  return prompt.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

void _checkEdgeWhitespace(
  String value,
  String field,
  void Function(String message, {required String field}) add, {
  String? label,
}) {
  if (value == value.trim()) return;
  final name = label ?? 'Field "$field"';
  add('$name has leading or trailing whitespace.', field: field);
}
