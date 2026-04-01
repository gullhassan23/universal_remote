/// App key (KEY_*) to Sony API button name. Used to match getRemoteControllerInfo response.
const Map<String, String> sonyKeyToApiName = {
  'KEY_VOLUP': 'VolumeUp',
  'KEY_VOLDOWN': 'VolumeDown',
  'KEY_MUTE': 'Mute',
  'KEY_CHUP': 'ChannelUp',
  'KEY_CHDOWN': 'ChannelDown',
  'KEY_UP': 'Up',
  'KEY_DOWN': 'Down',
  'KEY_LEFT': 'Left',
  'KEY_RIGHT': 'Right',
  'KEY_ENTER': 'Confirm',
  'KEY_POWER': 'PowerOff',
  'KEY_HOME': 'Home',
  'KEY_RETURN': 'Back',
  'KEY_MENU': 'Menu',
  'KEY_KEYBOARD': 'Num1', // fallback; TV may use different name
  'KEY_GUIDE': 'Guide',
  'KEY_TOOLS': 'SyncMenu',
  'KEY_INPUT': 'Input',
};

/// Fallback: app key -> IRCC code when TV does not return getRemoteControllerInfo.
final Map<String, String> sonyIrccCodes = {
  // Volume
  'KEY_VOLUP': 'AAAAAQAAAAEAAAASAw==',
  'KEY_VOLDOWN': 'AAAAAQAAAAEAAAATAw==',
  'KEY_MUTE': 'AAAAAQAAAAEAAAAUAw==',
  // Channel
  'KEY_CHUP': 'AAAAAQAAAAEAAAAQAw==',
  'KEY_CHDOWN': 'AAAAAQAAAAEAAAARAw==',
  // Navigation
  'KEY_UP': 'AAAAAQAAAAEAAABHAw==',
  'KEY_DOWN': 'AAAAAQAAAAEAAABIAw==',
  'KEY_LEFT': 'AAAAAQAAAAEAAABGAw==',
  'KEY_RIGHT': 'AAAAAQAAAAEAAABFAw==',
  'KEY_ENTER': 'AAAAAQAAAAEAAABlAw==',
  // Power & system
  'KEY_POWER': 'AAAAAQAAAAEAAAAVAw==',
  'KEY_HOME': 'AAAAAQAAAAEAAABgAw==',
  'KEY_RETURN': 'AAAAAQAAAAEAAAAgAw==',
  'KEY_MENU': 'AAAAAQAAAAEAAAAXAw==',
  'KEY_KEYBOARD': 'AAAAAQAAAAEAAABoAw==',
  'KEY_GUIDE': 'AAAAAQAAAAEAAABYAw==',
  'KEY_TOOLS': 'AAAAAQAAAAEAAAAlAw==',
  // Input
  'KEY_INPUT': 'AAAAAQAAAAEAAAAlAw==',
};
