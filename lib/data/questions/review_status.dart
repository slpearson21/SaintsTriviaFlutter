/// Doctrinal review state stored on each question.
///
/// The shipped bank stays `draft` until review. Release loads and the
/// validator's `--require-approved` flag reject anything that is not
/// [approved].
enum ReviewStatus {
  draft('draft'),
  approved('approved');

  const ReviewStatus(this.value);

  /// JSON value.
  final String value;

  static ReviewStatus? tryParse(String value) {
    for (final status in ReviewStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}
