# Tests

Run the suite in a random order:

```sh
flutter test --test-randomize-ordering-seed=random
```

The run prints the seed it used:

```text
Shuffling test order with --test-randomize-ordering-seed=762719892
```

Repeat that order by passing the same number:

```sh
flutter test --test-randomize-ordering-seed=762719892
```
