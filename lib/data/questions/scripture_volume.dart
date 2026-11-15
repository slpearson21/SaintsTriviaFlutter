/// A standard-works volume in the trivia bank.
///
/// [code] is the JSON value. [idPrefix] is the lowercase prefix on question
/// ids (`ot-0001`). [fileName] is the v1 asset file for that volume.
enum ScriptureVolume {
  ot('OT', 'ot', 'old_testament.json', 'Old Testament'),
  nt('NT', 'nt', 'new_testament.json', 'New Testament'),
  bom('BOM', 'bom', 'book_of_mormon.json', 'Book of Mormon'),
  dc('DC', 'dc', 'doctrine_and_covenants.json', 'Doctrine and Covenants'),
  pgp('PGP', 'pgp', 'pearl_of_great_price.json', 'Pearl of Great Price');

  const ScriptureVolume(this.code, this.idPrefix, this.fileName, this.label);

  final String code;
  final String idPrefix;
  final String fileName;
  final String label;

  static ScriptureVolume? tryParse(String code) {
    for (final volume in ScriptureVolume.values) {
      if (volume.code == code) {
        return volume;
      }
    }
    return null;
  }

  /// Ids look like `ot-0001`: a known prefix, a hyphen, and four digits.
  static final RegExp idPattern = RegExp(
    '^('
    '${ScriptureVolume.values.map((volume) => volume.idPrefix).join('|')}'
    r')-(\d{4})$',
  );

  /// The volume whose [idPrefix] matches [id], or null when [id] is not a
  /// v1 id.
  static ScriptureVolume? volumeForId(String id) {
    final match = idPattern.firstMatch(id);
    if (match == null) {
      return null;
    }
    final prefix = match.group(1);
    for (final volume in ScriptureVolume.values) {
      if (volume.idPrefix == prefix) {
        return volume;
      }
    }
    return null;
  }
}
