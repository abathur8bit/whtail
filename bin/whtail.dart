import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:whtail/version.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'follow',
      abbr: 'f',
      negatable: false,
      help: 'Print the last 10 lines, then continue following changes.',
    )
    ..addFlag(
      'directory',
      abbr: 'd',
      negatable: false,
      help: 'Also watch the parent directory so recreated/rotated files are reattached.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help.',
    );

  late final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Argument error: $e');
    stderr.writeln();
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (args['help'] == true) {
    _printUsage(parser);
    return;
  }

  final files = args.rest;
  if (files.isEmpty) {
    stderr.writeln('No files specified.');
    stderr.writeln();
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  final follow = args['follow'] as bool;
  final watchDirectory = args['directory'] as bool;

  final watchers = <ColoredTailTarget>[
    for (int i = 0; i < files.length; i++)
      ColoredTailTarget(
        displayPath: files[i],
        file: File(files[i]),
        color: ((i % 15) + 1),
        watchDirectory: watchDirectory,
      ),
  ];

  for (final watcher in watchers) {
    await watcher.start(follow: follow, lastLines: 10);
  }

  if (!follow) {
    return;
  }

  stdout.writeln('Following ${watchers.length} file(s). Press Ctrl+C to stop.');

  await ProcessSignal.sigint.watch().first;
  for (final watcher in watchers) {
    await watcher.dispose();
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Usage: dart run whtail.dart [options] file1 [file2 ...]');
  stdout.writeln("Version $appVersion");
  stdout.writeln("Written by the Weathered Hiker");
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  dart run whtail.dart app.log');
  stdout.writeln('  dart run whtail.dart -f app.log ../other.log /var/log/syslog');
  stdout.writeln('  dart run whtail.dart -f -d app.log');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

class ColoredTailTarget {
  ColoredTailTarget({
    required this.displayPath,
    required this.file,
    required this.color,
    required this.watchDirectory,
  });

  final String displayPath;
  final File file;
  final int color;
  final bool watchDirectory;

  StreamSubscription<FileSystemEvent>? _fileSub;
  StreamSubscription<FileSystemEvent>? _dirSub;
  Timer? _debounce;
  int _offset = 0;
  String _partialLine = '';

  String get _targetName => _basename(file.path);

  Future<void> start({
    required bool follow,
    required int lastLines,
  }) async {
    final exists = await file.exists();

    if (exists) {
      final lines = await _readLastLines(file, lastLines);
      for (final line in lines) {
        _printColored(line);
      }
      _offset = await file.length();
    } else {
      stderr.writeln('Missing: $displayPath');
      if (!follow) {
        return;
      }
      if (!watchDirectory) {
        stderr.writeln('Cannot follow missing file without -d: $displayPath');
      }
    }

    if (!follow) {
      return;
    }

    if (exists) {
      await _attachFileWatch();
    }

    if (watchDirectory) {
      await _attachDirectoryWatch();
    }
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _fileSub?.cancel();
    await _dirSub?.cancel();
  }

  Future<void> _attachFileWatch() async {
    await _fileSub?.cancel();
    if (!await file.exists()) {
      return;
    }

    _fileSub = file.watch(events: FileSystemEvent.all).listen(
          (event) {
        if (event is FileSystemDeleteEvent) {
          _offset = 0;
          _partialLine = '';
          return;
        }
        _scheduleRead();
      },
      onError: (Object error, StackTrace stackTrace) {
        stderr.writeln('File watch error for $displayPath: $error');
      },
    );
  }

  Future<void> _attachDirectoryWatch() async {
    await _dirSub?.cancel();

    final parent = file.parent;
    if (!await parent.exists()) {
      stderr.writeln('Parent directory missing for $displayPath: ${parent.path}');
      return;
    }

    _dirSub = parent.watch(events: FileSystemEvent.all).listen(
          (event) async {
        if (_basename(event.path) != _targetName) {
          return;
        }

        if (event is FileSystemDeleteEvent) {
          _offset = 0;
          _partialLine = '';
          return;
        }

        await _attachFileWatch();
        _scheduleRead();
      },
      onError: (Object error, StackTrace stackTrace) {
        stderr.writeln('Directory watch error for $displayPath: $error');
      },
    );
  }

  void _scheduleRead() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      unawaited(_readAppendedContent());
    });
  }

  Future<void> _readAppendedContent() async {
    try {
      if (!await file.exists()) {
        return;
      }

      final length = await file.length();

      if (length < _offset) {
        _offset = 0;
        _partialLine = '';
      }

      if (length == _offset) {
        return;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead(_offset, length)) {
        builder.add(chunk);
      }

      _offset = length;

      final text =
          _partialLine + utf8.decode(builder.takeBytes(), allowMalformed: true);

      final endsWithNewline = text.endsWith('\n');
      final parts = text.split('\n');

      if (endsWithNewline) {
        _partialLine = '';
        if (parts.isNotEmpty && parts.last.isEmpty) {
          parts.removeLast();
        }
      } else {
        _partialLine = parts.isNotEmpty ? parts.removeLast() : '';
      }

      for (var line in parts) {
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }
        _printColored(line);
      }
    } catch (e) {
      stderr.writeln('Read error for $displayPath: $e');
    }
  }

  void _printColored(String line) {
    stdout.write('\x1b[38;5;${color}m');
    stdout.write('[$displayPath] ');
    stdout.write(line);
    stdout.write('\x1b[0m\n');
  }
}

Future<List<String>> _readLastLines(File file, int lineCount) async {
  final raf = await file.open();
  try {
    final length = await raf.length();
    if (length == 0) {
      return <String>[];
    }

    const chunkSize = 4096;
    int position = length;
    int newlineCount = 0;
    final chunks = <List<int>>[];

    while (position > 0 && newlineCount <= lineCount) {
      final start = max(0, position - chunkSize);
      final size = position - start;

      await raf.setPosition(start);
      final chunk = await raf.read(size);

      chunks.add(chunk);

      for (final b in chunk) {
        if (b == 10) {
          newlineCount++;
        }
      }

      position = start;
    }

    final builder = BytesBuilder(copy: false);
    for (final chunk in chunks.reversed) {
      builder.add(chunk);
    }

    final text = utf8.decode(builder.takeBytes(), allowMalformed: true);
    final lines = text.split('\n');

    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].endsWith('\r')) {
        lines[i] = lines[i].substring(0, lines[i].length - 1);
      }
    }

    if (lines.length <= lineCount) {
      return lines;
    }

    return lines.sublist(lines.length - lineCount);
  } finally {
    await raf.close();
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? path : parts.last;
}