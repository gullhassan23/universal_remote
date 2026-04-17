/// Normalizes typed characters to keys Android TV can reliably inject.
String _normalizeTypedChar(String char) {
  if (char.isEmpty) return char;

  switch (char) {
    case '\r':
      return '\n';
    case '\t':
      return ' ';
    // Smart/full-width variants commonly produced by phone keyboards.
    case '–':
    case '—':
    case '−':
      return '-';
    case '．':
    case '。':
      return '.';
    case '，':
    case '、':
    case '،':
      return ',';
    case '＠':
      return '@';
  }

  final code = char.runes.first;
  // Full-width 0-9
  if (code >= 0xFF10 && code <= 0xFF19) {
    return String.fromCharCode(0x30 + (code - 0xFF10));
  }
  // Full-width A-Z
  if (code >= 0xFF21 && code <= 0xFF3A) {
    return String.fromCharCode(0x41 + (code - 0xFF21));
  }
  // Full-width a-z
  if (code >= 0xFF41 && code <= 0xFF5A) {
    return String.fromCharCode(0x61 + (code - 0xFF41));
  }

  return char;
}

/// Returns the character that should be sent through [sendKey], or null.
String? mapTypedCharToRemoteKey(String char) {
  if (char.length != 1) return null;
  final normalized = _normalizeTypedChar(char);
  return mapCharToAndroidKeyCode(normalized) == null ? null : normalized;
}

/// Maps a single typed character to an Android KeyEvent keycode (for text input).
int? mapCharToAndroidKeyCode(String char) {
  if (char.length != 1) return null;
  final normalized = _normalizeTypedChar(char);
  final code = normalized.codeUnitAt(0);
  // 0–9
  if (code >= 0x30 && code <= 0x39) return 7 + (code - 0x30);
  // a–z
  if (code >= 0x61 && code <= 0x7a) return 29 + (code - 0x61);
  // A–Z (same keycodes as lowercase; TV/search UIs usually accept this)
  if (code >= 0x41 && code <= 0x5a) return 29 + (code - 0x41);
  switch (normalized) {
    case ' ':
      return 62; // KEYCODE_SPACE
    case '\n':
      return 66; // KEYCODE_ENTER (text field)
    case '.':
      return 56;
    case ',':
      return 55;
    case '-':
      return 69;
    case '@':
      return 77;
    case '/':
      return 76; // KEYCODE_SLASH
    default:
      return null;
  }
}

/// Maps [RemoteController.send] key names to Android KeyEvent keycodes.
int? mapRemoteKeyToAndroidKeyCode(String key) {
  if (key.length == 1) {
    return mapCharToAndroidKeyCode(key);
  }
  switch (key) {
    case 'KEY_VOLUP':
      return 24;
    case 'KEY_VOLDOWN':
      return 25;
    case 'KEY_MUTE':
      return 91;
    case 'KEY_POWER':
      return 26;
    case 'KEY_BACKSPACE':
      return 67; // KEYCODE_DEL
    case 'KEY_RETURN':
      return 4;
    case 'KEY_CHUP':
      return 166;
    case 'KEY_CHDOWN':
      return 167;
    case 'KEY_RED':
      return 183;
    case 'KEY_GREEN':
      return 184;
    case 'KEY_YELLOW':
      return 185;
    case 'KEY_BLUE':
      return 186;
    case 'KEY_REWIND':
      return 89;
    case 'KEY_SEARCH':
      return 84;
    case 'KEY_PAUSE':
      return 127;
    case 'KEY_PLAY':
      return 126;
    case 'KEY_FF':
      return 90;
    case 'KEY_UP':
      return 19;
    case 'KEY_DOWN':
      return 20;
    case 'KEY_LEFT':
      return 21;
    case 'KEY_RIGHT':
      return 22;
    case 'KEY_ENTER':
      // Use DPAD_CENTER so "OK" selects focused item in Android TV UI/keyboard.
      return 23;
    case 'KEY_MENU':
      return 82;
    case 'KEY_HOME':
      return 3;
    case 'KEY_GUIDE':
      return 172;
    case 'KEY_TOOLS':
      return 176;
    case 'KEY_0':
      return 7;
    case 'KEY_1':
      return 8;
    case 'KEY_2':
      return 9;
    case 'KEY_3':
      return 10;
    case 'KEY_4':
      return 11;
    case 'KEY_5':
      return 12;
    case 'KEY_6':
      return 13;
    case 'KEY_7':
      return 14;
    case 'KEY_8':
      return 15;
    case 'KEY_9':
      return 16;

    default:
      return null;
  }
}
