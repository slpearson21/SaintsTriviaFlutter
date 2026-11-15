# SaintsTriviaFlutter

Offline scripture trivia. The question bank ships in the app as JSON assets. The quiz does not use the network.

## Question bank

Schema v1 lives in `assets/questions/v1/`. Each file is a JSON array of questions for one volume:

| File | Volume | Id prefix |
| --- | --- | --- |
| `old_testament.json` | OT | `ot-` |
| `new_testament.json` | NT | `nt-` |
| `book_of_mormon.json` | BOM | `bom-` |
| `doctrine_and_covenants.json` | DC | `dc-` |
| `pearl_of_great_price.json` | PGP | `pgp-` |

Question fields:

- `id` — prefix plus four digits, such as `ot-0001`
- `volume` — `OT`, `NT`, `BOM`, `DC`, or `PGP`
- `reference` — display string, not empty
- `prompt` — not empty, at most 140 characters
- `options` — exactly four non-empty strings, distinct after trimming and case-folding
- `answerIndex` — integer 0–3
- `explanation` — one line, not empty, at most 160 characters
- `reviewStatus` — `draft` or `approved`

Ids are unique across the whole bank. The id prefix has to match `volume`, and `volume` has to match the file it is in. The current bank is entirely `draft` until doctrinal review.

`test/fixtures/questions/v1/` has the first five questions of each volume for tests. Those fixtures are not bundled in the app.

## Validate

From the repository root:

```sh
dart run tool/validate_questions.dart
```

That checks structure only, including the rule that `assets/questions/v1/` has at least 100 questions in each volume. Pull-request CI runs this command. It passes while questions are still `draft`. Fixture directories such as `test/fixtures/questions/v1/` are not held to the 100-question minimum.

The release gate rejects unapproved questions and, for the bundled bank, counts only approved questions toward that minimum:

```sh
dart run tool/validate_questions.dart --require-approved
```

`--release` is an alias for `--require-approved`. The current bank is entirely `draft`, so this command fails until doctrinal review. Pull-request CI does not run it.

STRIV-19's release pipeline should call the reusable workflow [`.github/workflows/validate-question-bank-release.yml`](.github/workflows/validate-question-bank-release.yml):

```yaml
jobs:
  question-bank:
    uses: ./.github/workflows/validate-question-bank-release.yml
```

That workflow is also available from the Actions tab (`workflow_dispatch`). Point `--bank` at another directory to check fixtures or a future copy:

```sh
dart run tool/validate_questions.dart --bank test/fixtures/questions/v1
```

## Loading in the app

`loadBundledQuestionBank()` reads the bundled JSON offline and returns the `QuestionBank`. It throws `QuestionBankException` for malformed content. Show `QuestionBankException.userMessage` (`Content failed to load.`) and use `violations` in logs.

A release build skips questions that are not `approved`. Debug and profile builds still load drafts, so the full bank is available for development and performance testing. Skipping drafts does not throw. `QuestionBank.availableVolumes` lists the volumes that still have questions, and `forVolume` is empty when a volume has none. That is the "no questions for this selection" state. The loader is not wired into the home screen yet.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) has two checks. Draft pull requests skip both until they are marked ready for review. A skipped check still satisfies branch protection.

**Analyze, test, and debug APK** runs on Linux for every pull request that changes the app, for every push to `main`, and for a manual run. A pull request that only changes Markdown (`**/*.md`), files under `docs/`, or CSV review files outside `assets/` and `test/` skips this job. Anything under `assets/` is app content, and anything under `test/` is what this job runs, including CSV or Markdown in either tree.

**iOS simulator build** runs on macOS only when one of these is true:

- the pull request changes `ios/`, `pubspec.yaml`, `pubspec.lock`, `.github/workflows/`, or native plugin config (`Podfile`, `Podfile.lock`, or a `.podspec`)
- the pull request has the `ios` label
- the event is a push to `main`
- someone starts the workflow by hand (**Actions → CI → Run workflow**)

The macOS job starts after the Linux job succeeds, so a failed analyze or test does not spend macOS minutes. On a docs-only pull request the Linux job is skipped; the `ios` label, or an iOS path in that diff, still runs the macOS job.

To force the iOS build on a pull request that would otherwise skip it, add the `ios` label. The label is ignored while the pull request is a draft. A manual run from the Actions tab runs both jobs on the branch you pick.
