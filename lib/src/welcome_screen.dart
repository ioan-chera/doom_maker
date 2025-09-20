import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({ super.key });

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
      // TODO
    }
  }
}
