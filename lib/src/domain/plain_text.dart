/// Texto plano de un enunciado en el formato de compatibilidad
/// (`valor[@]TIPO` unidos por `[#]` y `[%]`) para listas y búsquedas.
String plainStatement(String raw) {
  final parts = <String>[];
  for (final line in raw.split('[%]')) {
    for (final chunk in line.split('[#]')) {
      final at = chunk.lastIndexOf('[@]');
      final value = (at < 0 ? chunk : chunk.substring(0, at)).trim();
      final type = at < 0 ? 'TEXT' : chunk.substring(at + 3).trim();
      if (value.isEmpty) continue;
      parts.add(type == 'URL' ? '[imagen]' : value);
    }
  }
  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
