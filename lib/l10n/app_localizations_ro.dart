// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'doom_maker';

  @override
  String get welcomeTitle => 'Bine ați venit în DoomMaker';

  @override
  String get loadWadFile => 'Încarcă un fișier WAD';

  @override
  String get loadFile => 'Încarcă fișier';

  @override
  String get loading => 'Se încarcă...';

  @override
  String errorLoadingFile(String error) {
    return 'Eroare încărcare fișier: $error';
  }
}
