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
- `options` — exactly four non-empty strings
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

That checks structure only. Pull-request CI runs this command. It passes while questions are still `draft`.

A release workflow should reject unapproved questions:

```sh
dart run tool/validate_questions.dart --require-approved
```

`--release` is an alias for `--require-approved`. The flag fails the run if any question is not `approved`. Point `--bank` at another directory of the five volume files to check fixtures or a future copy:

```sh
dart run tool/validate_questions.dart --bank test/fixtures/questions/v1
```

## Loading in the app

`loadBundledQuestionBank()` reads the bundled JSON offline. It throws `QuestionBankException` for malformed content. Show `QuestionBankException.userMessage` (`Content failed to load.`) and use `violations` in logs.

Release builds (`kReleaseMode`) pass the same approved-only rule as `--require-approved`. A draft question fails the whole load. It is not dropped. Debug and profile builds still load drafts so the game can be tried before review. The loader is not wired into the home screen yet.
