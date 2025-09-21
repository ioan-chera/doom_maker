import 'doom_level/level.dart';
import 'map_editor_view.dart';
import 'wad_data.dart';

import '../l10n/app_localizations.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({ super.key });

  static const routeName = '/';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['wad'],
      );
      if(result != null) {
        String? path = result.files.single.path;
        if(path != null) {
          if(mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MapEditorView(
                  filePath: path,
                  level: Level.fromWad(WadData.fromFile(path), 'MAP01')
                )
              )
            );
          }
        }
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingFile(e.toString())),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.of(context)!.welcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 240,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadFile,
                  icon: _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.folder_open),
                    label: Text(_isLoading ? AppLocalizations.of(context)!.loading : AppLocalizations.of(context)!.loadWadFile),
                    style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 16))
                )
              )
            ],
          )
        )
      )
    );
  }
}
