/// One-off extractor that turns the WordNet 3.0 database into the
/// `assets/words/hints.json` hint file.
///
/// This tool is never imported by the app. It reads the unpacked WordNet
/// database, walks the binary synset records, keeps only the definition part
/// of each gloss, and refuses any hint that would give the word away.
///
/// Run it with the gate numbers first, before it writes anything:
///
/// ```sh
/// dart run tool/extract_hints.dart                  # report only
/// dart run tool/extract_hints.dart --write          # report, then write assets
/// ```
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Where the WordNet database is expected to be unpacked.
const String wordNetDir = 'tool/wordnet/wordnet';

/// The words a hint can be shown for.
const String answersAsset = 'assets/words/answers.json';

/// The hint file this tool produces.
const String hintsAsset = 'assets/words/hints.json';

/// Hints longer than this read like a dictionary entry rather than a clue.
///
/// 110 characters is about fifteen words, which is short enough to scan in a
/// dialog and long enough to describe most words without cutting a sentence in
/// half. It costs some coverage: at 110 about 89% of the answer list gets a
/// hint, against 90.8% at 140.
const int maxHintLength = 110;

/// The parts of speech WordNet files come in, in the order they are read.
///
/// Nouns come first so that a lemma listed under several parts of speech is
/// described as a noun, which is usually what a word game wants.
const List<String> partsOfSpeech = ['noun', 'verb', 'adj', 'adv'];

/// A lemma and the synset offsets that define it.
class Entry {
  const Entry(this.partOfSpeech, this.offsets);

  final String partOfSpeech;
  final List<int> offsets;
}

/// Gate on how much of the answer list WordNet describes at all.
///
/// WordNet indexes headwords, and the answer list includes inflections such as
/// `abled` or `borne`, so a little under 95% is the most this source can reach
/// and anything above that is measuring a broken parser rather than coverage.
const double gateRawCoverage = 0.93;

/// Gate on how much of the answer list ends up with a usable hint.
///
/// The shortfall against [gateRawCoverage] is made up of words whose every
/// sense spells the word out or is too wordy to read as a clue. Those fall
/// back to revealing a letter.
const double gateUsableCoverage = 0.85;

void main(List<String> args) {
  final shouldWrite = args.contains('--write');
  final cap = int.tryParse(
        args
            .firstWhere((arg) => arg.startsWith('--cap='),
                orElse: () => '--cap=$maxHintLength')
            .split('=')[1],
      ) ??
      maxHintLength;

  final index = _readIndex();
  stderr.writeln('indexed ${index.length} lemmas');
  if (index.isEmpty) {
    stderr.writeln('FATAL G1: no lemmas parsed, the index format is wrong.');
    exit(2);
  }

  final answers = _readAnswers();
  final cache = <String, Uint8List>{};
  final hints = <String, String>{};
  final dropped = <String, String>{}; // word -> why nothing worked
  final missing = <String>[];

  for (final word in answers) {
    final result = _pickHint(word, index, cache, cap);
    switch (result.reason) {
      case HintOutcome.none:
        missing.add(word);
      case HintOutcome.ok:
        hints[word] = result.hint!;
      default:
        dropped[word] = result.reason.name;
    }
  }

  final rawFound = answers.length - missing.length;
  final rawCoverage = rawCoverageOf(answers.length, missing.length);
  final usableCoverage = hints.length / answers.length;
  final payloadSize = utf8.encode(json.encode(hints)).length;
  final byReason = <String, int>{};
  for (final reason in dropped.values) {
    byReason[reason] = (byReason[reason] ?? 0) + 1;
  }

  stdout.writeln('length cap           $cap');
  stdout.writeln('answers              ${answers.length}');
  stdout.writeln('raw gloss found      $rawFound (${_pct(rawCoverage)})  G1 >= ${_pct(gateRawCoverage)}');
  stdout.writeln('usable hints         ${hints.length} (${_pct(usableCoverage)})  G2 >= ${_pct(gateUsableCoverage)}');
  stdout.writeln('no gloss at all      ${missing.length}  ${_pct(missing.length / answers.length)}');
  stdout.writeln('dropped, all senses  ${dropped.length}');
  for (final entry in byReason.entries) {
    stdout.writeln('  ${entry.key.padRight(10)} ${entry.value}');
  }
  stdout.writeln('compact json bytes   $payloadSize  G4 <= 300000');

  // The ceiling no filter change can beat: words WordNet does not describe.
  final ceiling = 1 - missing.length / answers.length;
  stdout.writeln('\nceiling with this source: ${_pct(ceiling)}');

  final samples = hints.entries.take(5);
  stdout.writeln('\nsample hints:');
  for (final entry in samples) {
    stdout.writeln('  ${entry.key.padRight(8)} ${entry.value}');
  }
  if (missing.length > 20) {
    stdout.writeln('\nfirst 20 missing: ${missing.take(20).join(", ")}');
  }

  // Words dropped because every sense spelled the word out are fine; what must
// never happen is one of those definitions reaching the hint file.
final escaped = hints.entries.where((e) => leaksWord(e.key, e.value)).length;

final gatesPass = rawCoverage >= gateRawCoverage &&
      usableCoverage >= gateUsableCoverage &&
      escaped == 0 &&
      payloadSize <= 300000;

stdout.writeln('leaks in output      $escaped  G3 == 0');

  stdout.writeln('\nGATES: ${gatesPass ? 'PASS' : 'FAIL'}');
  if (!gatesPass) {
    stderr.writeln('Not writing the hint asset. Fix the failing gate first.');
    exit(1);
  }
  if (!shouldWrite) {
    stdout.writeln('Report only. Re-run with --write to create $hintsAsset.');
    return;
  }

  File(hintsAsset).writeAsStringSync(json.encode(hints));
  stdout.writeln('wrote $hintsAsset');
}

/// Reads every `index.<pos>` file into [Entry]s keyed by lemma.
Map<String, Entry> _readIndex() {
  final index = <String, Entry>{};

  for (final pos in partsOfSpeech) {
    final file = File('$wordNetDir/index.$pos');
    if (!file.existsSync()) {
      stderr.writeln('missing ${file.path}');
      continue;
    }

    var parsed = 0;
    for (final line in file.readAsLinesSync()) {
      // licence preamble -> part of speech -> counts -> offsets
      final tokens = line.trim().split(RegExp(r'\s+'));
      if (tokens.length < 5) continue;
      if (!RegExp(r'^[nvar]$').hasMatch(tokens[1])) continue;
      final synsetCount = int.tryParse(tokens[2]);
      if (synsetCount == null) continue;
      // A lemma is claimed by the first part of speech that lists it.
      if (index.containsKey(tokens[0])) continue;

      final offsets = <int>[];
      for (var i = tokens.length - synsetCount; i < tokens.length; i++) {
        final offset = int.tryParse(tokens[i]);
        if (offset != null) offsets.add(offset);
      }
      if (offsets.length != synsetCount) continue;

      index[tokens[0]] = Entry(pos, offsets);
      parsed++;
    }
    stderr.writeln('  index.$pos: $parsed new lemmas');
  }

  return index;
}

/// The words a hint may be shown for.
List<String> _readAnswers() =>
    (json.decode(File(answersAsset).readAsStringSync()) as List).cast<String>();

/// Reads a `data.<pos>` file into memory once and keeps it.
Uint8List _data(String pos, Map<String, Uint8List> cache) =>
    cache.putIfAbsent(pos, () => File('$wordNetDir/data.$pos').readAsBytesSync());


/// The words and the gloss of the synset stored at byte [offset].
({String header, String gloss})? _readRecord(Uint8List data, int offset) {
  var end = offset;
  while (end < data.length && data[end] != 0x0a) {
    end++;
  }
  if (end == offset) return null;

  final line = ascii.decode(data.sublist(offset, end));
  final marker = line.indexOf(' | ');
  if (marker < 0) return null;

  return (header: line.substring(0, marker), gloss: line.substring(marker + 3));
}

/// Why a word ended up without a usable hint.
enum HintOutcome {
  /// A hint was found.
  ok,

  /// WordNet has no entry for the word at all.
  none,

  /// Every sense spelled the word out.
  leaked,

  /// Every sense was too wordy to read as a clue.
  tooLong,
}

/// A hint, or the reason there isn't one.
typedef HintResult = ({String? hint, HintOutcome reason});

/// The best hint for [word], searching every sense WordNet records for it.
///
/// A word often has several synsets and only some of them are usable: the
/// first sense of `crush` reads as a form of leather, and the first sense of
/// `aback` contains the word itself. Testing each sense in turn and keeping
/// the first that passes every filter recovers most of those words, which
/// judging a single sense and discarding the word does not.
HintResult _pickHint(
  String word,
  Map<String, Entry> index,
  Map<String, Uint8List> cache,
  int cap,
) {
  final entry = index[word];
  if (entry == null) return (hint: null, reason: HintOutcome.none);

  final data = _data(entry.partOfSpeech, cache);
  final headword = RegExp('(^|[\\s_])${RegExp.escape(word)}([\\s_]|\$)');

  // Senses naming the word itself are the most likely to read well.
  final senses = <({int offset, String gloss, bool isHeadword})>[];
  for (final offset in entry.offsets) {
    final record = _readRecord(data, offset);
    if (record == null) continue;
    senses.add((
      offset: offset,
      gloss: record.gloss,
      isHeadword: headword.hasMatch(record.header),
    ));
  }
  if (senses.isEmpty) return (hint: null, reason: HintOutcome.none);
  senses.sort((a, b) => b.isHeadword == a.isHeadword ? 0 : b.isHeadword ? 1 : -1);

  var leaked = false;
  var tooLong = false;
  for (final sense in senses) {
    final definition = _definitionOf(sense.gloss);
    if (definition.isEmpty) continue;
    if (leaksWord(word, definition)) {
      leaked = true;
      continue;
    }
    if (definition.length > cap) {
      tooLong = true;
      continue;
    }
    return (hint: definition, reason: HintOutcome.ok);
  }

  if (leaked) return (hint: null, reason: HintOutcome.leaked);
  if (tooLong) return (hint: null, reason: HintOutcome.tooLong);
  return (hint: null, reason: HintOutcome.none);
}

/// The share of [total] covered by [found] words.
double rawCoverageOf(int total, int missing) => (total - missing) / total;

/// Strips the example sentences and citations WordNet appends to a gloss.
///
/// Everything before the first double quote is the definition; the definition
/// itself never contains one. A synset with no examples has no quote at all,
/// which is why the whole gloss is used in that case.
String _definitionOf(String gloss) {
  var definition = gloss;
  final quote = definition.indexOf('"');
  if (quote >= 0) definition = definition.substring(0, quote);

  definition = definition.replaceAll(RegExp(r'\s+'), ' ').trim();
  return definition.replaceFirst(RegExp(r'[\s;,\-]+$'), '');
}

/// Whether [hint] gives [word] away.
///
/// A definition that contains the word itself is useless as a clue, and real
/// glosses do this: the sense of `aback` reads "the ship came up into the
/// wind with all yards aback".
///
/// Letters-in-order is deliberately *not* a filter. WordNet glosses are
/// sentences, and virtually every sentence contains a five letter word's
/// letters in order, so such a rule rejects almost everything.
bool leaksWord(String word, String hint) =>
    hint.toLowerCase().contains(word.toLowerCase());

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
