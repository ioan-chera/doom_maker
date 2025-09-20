// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'doom_maker';

  @override
  String get welcomeTitle => 'Welcome to DoomMaker';

  @override
  String get loadWadFile => 'Load a WAD file';

  @override
  String get loadFile => 'Load File';

  @override
  String get loading => 'Loading...';

  @override
  String errorLoadingFile(String error) {
    return 'Error loading file: $error';
  }
}
