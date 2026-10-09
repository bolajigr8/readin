import 'package:dio/dio.dart';

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';

class DictionaryDefinition {
  const DictionaryDefinition({required this.text, this.example});
  final String text;
  final String? example;
}

class DictionaryMeaning {
  const DictionaryMeaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
  });
  final String partOfSpeech;
  final List<DictionaryDefinition> definitions;
  final List<String> synonyms;
}

class DictionaryEntry {
  const DictionaryEntry({required this.word, this.phonetic, required this.meanings});
  final String word;
  final String? phonetic;
  final List<DictionaryMeaning> meanings;
}

/// Returns the selected text as ONE clean word, or null when the selection is a
/// phrase / sentence / number (then "Define" is not offered).
String? cleanWord(String selection) {
  final t = selection
      .trim()
      .replaceAll(RegExp(r'^[\s"“”‘’\x27(\[{.,;:!?\-–—]+'), '')
      .replaceAll(RegExp(r'[\s"“”‘’\x27)\]}.,;:!?\-–—]+$'), '');
  if (!RegExp(r"^[A-Za-z][A-Za-z'’\-]{1,29}$").hasMatch(t)) return null;
  return t.replaceAll('’', "'").toLowerCase();
}

/// Parses `https://api.dictionaryapi.dev/api/v2/entries/en/<word>` (a JSON list).
DictionaryEntry? parseDictionaryResponse(dynamic json) {
  if (json is! List || json.isEmpty || json.first is! Map) return null;

  final meanings = <DictionaryMeaning>[];
  String? phonetic;
  String word = '';

  for (final raw in json.whereType<Map>()) {
    final e = Map<String, dynamic>.from(raw);
    if (word.isEmpty) word = (e['word'] ?? '').toString();
    phonetic ??= _phonetic(e);

    final ms = e['meanings'];
    if (ms is! List) continue;
    for (final m in ms.whereType<Map>()) {
      final defs = <DictionaryDefinition>[];
      final rawDefs = m['definitions'];
      if (rawDefs is List) {
        for (final d in rawDefs.whereType<Map>()) {
          final text = (d['definition'] ?? '').toString().trim();
          if (text.isEmpty) continue;
          final ex = (d['example'] ?? '').toString().trim();
          defs.add(DictionaryDefinition(text: text, example: ex.isEmpty ? null : ex));
        }
      }
      if (defs.isEmpty) continue;
      final syn = m['synonyms'];
      meanings.add(
        DictionaryMeaning(
          partOfSpeech: (m['partOfSpeech'] ?? '').toString(),
          definitions: defs,
          synonyms: syn is List ? syn.map((x) => x.toString()).toList() : const [],
        ),
      );
    }
  }
  if (meanings.isEmpty) return null;
  return DictionaryEntry(word: word, phonetic: phonetic, meanings: meanings);
}

String? _phonetic(Map<String, dynamic> e) {
  final p = (e['phonetic'] ?? '').toString().trim();
  if (p.isNotEmpty) return p;
  final list = e['phonetics'];
  if (list is List) {
    for (final x in list.whereType<Map>()) {
      final t = (x['text'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

/// Free Dictionary API (no key). Own Dio: no auth header leaves the app.
class DictionaryService {
  DictionaryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.dictionaryapi.dev/api/v2/entries/en/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<ApiResult<DictionaryEntry>> lookup(String word) async {
    try {
      final res = await _dio.get<dynamic>(Uri.encodeComponent(word));
      final entry = parseDictionaryResponse(res.data);
      if (entry == null) {
        return Failure(NotFoundException(message: 'No definition found for "$word".'));
      }
      return Success(entry);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Failure(NotFoundException(message: 'No definition found for "$word".'));
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const Failure(NetworkException());
      }
      return const Failure(UnknownException(message: 'Dictionary is unavailable right now.'));
    } catch (_) {
      return const Failure(UnknownException(message: 'Dictionary is unavailable right now.'));
    }
  }
}
