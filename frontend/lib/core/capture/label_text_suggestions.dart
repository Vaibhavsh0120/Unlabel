/// Suggestions retain printed wording. They never infer nutrition, absence or safety.
class LabelTextSuggestions {
  const LabelTextSuggestions({
    this.name,
    this.ingredients,
    this.contains,
    this.mayContain,
  });
  final String? name, ingredients, contains, mayContain;

  factory LabelTextSuggestions.fromText(String front, String back) {
    final frontLines = front
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final first = frontLines.isEmpty ? null : frontLines.first;
    final name =
        first != null &&
            first.length <= 256 &&
            RegExp(r'[A-Za-z\u0900-\u097F]').hasMatch(first)
        ? first
        : null;
    final sections = <String, List<String>>{};
    final duplicated = <String>{};
    String? active;
    final heading = RegExp(
      r'^(ingredients?|contains|may\s+contain|सामग्री|अवयव)\s*[:：]\s*(.*)$',
      caseSensitive: false,
    );
    final stop = RegExp(
      r'^(nutrition|nutritional|nutrition\s+facts|allergen|storage|directions|manufactur|best\s+before|net\s+weight|per\s|energy|protein|carbohydrate|total\s+fat|sodium)',
      caseSensitive: false,
    );
    for (final raw in back.split('\n')) {
      final line = raw.trim();
      final match = heading.firstMatch(line);
      if (match != null) {
        final marker = match.group(1)!.toLowerCase();
        active = marker.startsWith('may')
            ? 'may'
            : marker == 'contains'
            ? 'contains'
            : 'ingredients';
        if (sections.containsKey(active)) duplicated.add(active);
        sections[active] = [match.group(2)!.trim()];
      } else if (line.isEmpty || stop.hasMatch(line)) {
        active = null;
      } else if (active != null) {
        sections[active]!.add(line);
      }
    }
    String? section(String key) {
      final value = sections[key]?.where((line) => line.isNotEmpty).join(' ');
      return duplicated.contains(key) ||
              value == null ||
              value.isEmpty ||
              value.length > 16000
          ? null
          : value;
    }

    return LabelTextSuggestions(
      name: name,
      ingredients: section('ingredients'),
      contains: section('contains'),
      mayContain: section('may'),
    );
  }
}
