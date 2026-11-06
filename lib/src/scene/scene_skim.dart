import 'dart:convert';

import 'package:meta/meta.dart';

/// What the Scenes list shows of a scene file's [text] — its `mode` and
/// how many `entities` it holds — read without building any of it: a 3-D
/// level of megabytes is gone through once, for two values, and no map or
/// list is made of it.
///
/// The text is still checked to be JSON, as `jsonDecode` would: null when
/// it is not, when it is not an object, or when its `entities` is there
/// and is not a list (`null` counts as none). Where a key repeats, the
/// last one counts, as it does for `jsonDecode`. `mode` is null when it is
/// not text.
@internal
({String? mode, int entityCount})? skimScene(String text) {
  try {
    return _SceneSkim(text).read();
  } on FormatException {
    return null;
  }
}

/// One pass over a scene file's text; see [skimScene].
final class _SceneSkim {
  _SceneSkim(this._text);

  final String _text;
  int _at = 0;

  static const int _quote = 0x22, _comma = 0x2C, _colon = 0x3A;
  static const int _openObject = 0x7B, _closeObject = 0x7D;
  static const int _openList = 0x5B, _closeList = 0x5D;
  static const int _backslash = 0x5C, _minus = 0x2D, _plus = 0x2B;
  static const int _zero = 0x30, _nine = 0x39, _dot = 0x2E;

  int get _next => _at < _text.length ? _text.codeUnitAt(_at) : -1;

  Never _wrong() => throw FormatException('Not JSON', _text, _at);

  ({String? mode, int entityCount})? read() {
    String? mode;
    var count = 0;
    var entitiesAreList = true;
    _space();
    if (_next != _openObject) return null;
    _at++;
    _space();
    if (_next == _closeObject) {
      _at++;
    } else {
      while (true) {
        _space();
        final key = _string(keep: true);
        _space();
        _expect(_colon);
        _space();
        if (key == 'mode') {
          mode = _next == _quote ? _string(keep: true) : null;
          if (mode == null) _value();
        } else if (key == 'entities') {
          if (_next == _openList) {
            count = _countList();
            entitiesAreList = true;
          } else {
            entitiesAreList = _text.startsWith('null', _at);
            count = 0;
            _value();
          }
        } else {
          _value();
        }
        _space();
        if (_next == _comma) {
          _at++;
          continue;
        }
        _expect(_closeObject);
        break;
      }
    }
    _space();
    if (_at != _text.length) _wrong();
    return entitiesAreList ? (mode: mode, entityCount: count) : null;
  }

  /// Goes past a list, and says how many values it held.
  int _countList() {
    _expect(_openList);
    _space();
    if (_next == _closeList) {
      _at++;
      return 0;
    }
    var count = 0;
    while (true) {
      _value();
      count++;
      _space();
      if (_next == _comma) {
        _at++;
        continue;
      }
      _expect(_closeList);
      return count;
    }
  }

  /// Goes past one value, of any shape. What is open is kept in a list
  /// rather than in calls: nothing a file holds can run the stack out.
  void _value() {
    final open = <int>[];
    while (true) {
      _space();
      switch (_next) {
        case _openObject:
          _at++;
          _space();
          if (_next == _closeObject) {
            _at++;
          } else {
            open.add(_openObject);
            _key();
            continue;
          }
        case _openList:
          _at++;
          _space();
          if (_next == _closeList) {
            _at++;
          } else {
            open.add(_openList);
            continue;
          }
        case _quote:
          _string(keep: false);
        case 0x74: // t
          _word('true');
        case 0x66: // f
          _word('false');
        case 0x6E: // n
          _word('null');
        default:
          _number();
      }
      // A value is done: what holds it goes on to its next, or is done in
      // turn.
      while (true) {
        if (open.isEmpty) return;
        _space();
        if (_next == _comma) {
          _at++;
          if (open.last == _openObject) _key();
          break;
        }
        _expect(open.last == _openObject ? _closeObject : _closeList);
        open.removeLast();
      }
    }
  }

  /// Goes past an object's key and its colon.
  void _key() {
    _space();
    _string(keep: false);
    _space();
    _expect(_colon);
  }

  /// Goes past a string; with [keep], what it says.
  String? _string({required bool keep}) {
    _expect(_quote);
    final start = _at;
    var escaped = false;
    while (true) {
      final c = _next;
      if (c == _quote) break;
      if (c < 0x20) _wrong(); // the end, or a control character
      if (c == _backslash) {
        escaped = true;
        _at++;
        switch (_next) {
          case 0x22 || 0x5C || 0x2F || 0x62 || 0x66 || 0x6E || 0x72 || 0x74:
            _at++;
          case 0x75: // u, then four hex digits
            _at++;
            for (var i = 0; i < 4; i++) {
              final h = _next;
              final isHex =
                  (h >= _zero && h <= _nine) ||
                  (h >= 0x41 && h <= 0x46) ||
                  (h >= 0x61 && h <= 0x66);
              if (!isHex) _wrong();
              _at++;
            }
          default:
            _wrong();
        }
        continue;
      }
      _at++;
    }
    final end = _at;
    _at++;
    if (!keep) return null;
    return escaped
        ? jsonDecode(_text.substring(start - 1, end + 1)) as String
        : _text.substring(start, end);
  }

  /// Goes past a number, as JSON writes one.
  void _number() {
    if (_next == _minus) _at++;
    if (_next == _zero) {
      _at++;
    } else if (_next > _zero && _next <= _nine) {
      _digits();
    } else {
      _wrong();
    }
    if (_next == _dot) {
      _at++;
      _digits();
    }
    if (_next == 0x65 || _next == 0x45) {
      _at++;
      if (_next == _plus || _next == _minus) _at++;
      _digits();
    }
  }

  /// Goes past one digit or more.
  void _digits() {
    if (!(_next >= _zero && _next <= _nine)) _wrong();
    while (_next >= _zero && _next <= _nine) {
      _at++;
    }
  }

  void _word(String word) {
    if (!_text.startsWith(word, _at)) _wrong();
    _at += word.length;
  }

  void _expect(int c) {
    if (_next != c) _wrong();
    _at++;
  }

  void _space() {
    while (true) {
      final c = _next;
      if (c != 0x20 && c != 0x0A && c != 0x0D && c != 0x09) return;
      _at++;
    }
  }
}
