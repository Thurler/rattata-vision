import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rattata_vision/views/common.dart';
import 'package:rattata_vision/widgets/common_scaffold.dart';
import 'package:rattata_vision/widgets/form.dart';
import 'package:rattata_vision/widgets/rounded_border.dart';
import 'package:rattata_vision/widgets/save_button.dart';

enum RefreshRate {
  fps60('Refresh 60 times per second', Duration(milliseconds: 16)),
  fps30('Refresh 30 times per second', Duration(milliseconds: 33)),
  fps20('Refresh 20 times per second', Duration(milliseconds: 50)),
  fps15('Refresh 15 times per second', Duration(milliseconds: 66)),
  fps10('Refresh 10 times per second', Duration(milliseconds: 100)),
  fps5('Refresh 5 times per second', Duration(milliseconds: 200)),
  fps2('Refresh 2 times per second', Duration(milliseconds: 500)),
  fps1('Refresh 1 time per second', Duration(seconds: 1)),
  fps050('Refresh every 2 seconds', Duration(seconds: 2)),
  fps033('Refresh every 3 seconds', Duration(seconds: 3)),
  fps020('Refresh every 5 seconds', Duration(seconds: 5)),
  manual('Only when recognizing text (No preview)', Duration.zero);

  final String dropdownText;
  final Duration refreshDuration;

  const RefreshRate(this.dropdownText, this.refreshDuration);
}

class Settings {
  RefreshRate refreshRate = RefreshRate.fps5;
  String credentialsPath = './credentials.json';
  String preferredLanguage = '';

  Settings.from(Settings other) : refreshRate = other.refreshRate;

  Settings.fromDefault();

  Settings.fromJson(String raw) {
    Map<String, dynamic> jsonContents = json.decode(raw);
    if (jsonContents.containsKey('refreshRate')) {
      refreshRate = RefreshRate.values.firstWhere(
        (RefreshRate r) => r.name == jsonContents['refreshRate'],
      );
    }
    if (jsonContents.containsKey('credentialsPath')) {
      credentialsPath = jsonContents['credentialsPath'];
    }
    if (jsonContents.containsKey('preferredLanguage')) {
      preferredLanguage = jsonContents['preferredLanguage'];
    }
  }

  String toJson() {
    Map<String, dynamic> result = <String, dynamic>{
      'refreshRate': refreshRate.name,
      'credentialsPath': credentialsPath,
      'preferredLanguage': preferredLanguage,
    };
    return json.encode(result);
  }
}

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => SettingsState();
}

class SettingsState extends CommonState<SettingsWidget> {
  Settings _settings = Settings.fromDefault();

  late TFormDropdown _refreshRateForm;
  final DropdownFormKey _refreshRateFormKey = DropdownFormKey();

  late TFormString _credentialsForm;
  final StringFormKey _credentialsFormKey = StringFormKey();

  late TFormString _preferredLanguageForm;
  final StringFormKey _preferredLanguageFormKey = StringFormKey();

  bool get _hasChanges {
    if (_refreshRateFormKey.currentState?.hasChanges ?? false) {
      return true;
    }
    if (_credentialsFormKey.currentState?.hasChanges ?? false) {
      return true;
    }
    if (_preferredLanguageFormKey.currentState?.hasChanges ?? false) {
      return true;
    }
    return false;
  }

  bool get _hasErrors {
    if (_refreshRateFormKey.currentState?.hasErrors ?? false) {
      return true;
    }
    if (_credentialsFormKey.currentState?.hasErrors ?? false) {
      return true;
    }
    if (_preferredLanguageFormKey.currentState?.hasErrors ?? false) {
      return true;
    }
    return false;
  }

  Future<void> _handleFileSystemException(FileSystemException e) {
    return handleException(
      dialogTitle: 'An error occured when saving the settings!',
      dialogBody: 'Make sure your user has permission to write a file in '
        'the folder this app is in.',
    );
  }

  String _validateJsonFileExists(String value) {
    if (value.isEmpty) {
      return 'Value cannot be empty';
    }
    File target = File(value);
    if (!target.existsSync()) {
      return "File doesn't exist";
    }
    try {
      json.decode(target.readAsStringSync());
    } catch (e) {
      return 'File is not a valid JSON';
    }
    return '';
  }

  Future<bool> _checkChangesAndConfirm() async {
    if (!_hasChanges) {
      return true;
    }
    return showUnsavedChangesDialog();
  }

  Future<void> _saveChanges() async {
    String chosenOption = _refreshRateFormKey.currentState!.value;
    _settings.refreshRate = RefreshRate.values.firstWhere(
      (RefreshRate r) => r.dropdownText == chosenOption,
    );
    _settings.credentialsPath = _credentialsFormKey.currentState!.value;
    _settings.preferredLanguage = _preferredLanguageFormKey.currentState!.value;
    try {
      File settingsFile = File('./settings.json');
      settingsFile.writeAsStringSync('${_settings.toJson()}\n');
    } on FileSystemException catch (e) {
      await _handleFileSystemException(e);
      return;
    } on Exception catch (e, s) {
      await handleUnexpectedException(e, s);
      return;
    }
    // Reset initial values to remove the has changes flag
    _refreshRateFormKey.currentState!.resetInitialValue();
    _credentialsFormKey.currentState!.resetInitialValue();
    _preferredLanguageFormKey.currentState!.resetInitialValue();
    setState((){});
  }

  Future<void> _changeRefreshRate(String? chosen) async {
    if (chosen == null) {
      return;
    }
    setState((){});
  }

  @override
  void initState() {
    super.initState();
    try {
      File settingsFile = File('./settings.json');
      if (settingsFile.existsSync()) {
        _settings = Settings.fromJson(settingsFile.readAsStringSync());
      }
    } catch (e) {
      // If we fail to load the settings file, keep going with default settings
    }
    _refreshRateForm = TFormDropdown(
      enabled: true,
      title: 'Refresh Rate',
      subtitle: 'Specifies how often Rattata updates the live preview\nCPU '
                'and disc usage might go up considerably at higher settings',
      hintText: 'Select a refresh rate',
      options: RefreshRate.values.map(
        (RefreshRate r) => r.dropdownText,
      ).toList(),
      initialValue: _settings.refreshRate.dropdownText,
      onValueChanged: _changeRefreshRate,
      key: _refreshRateFormKey,
    );
    _credentialsForm = TFormString(
      enabled: true,
      title: 'JSON credentials path',
      subtitle: "File path for Google API's JSON credentials\nBoth absolute "
                'and relative paths are compatible',
      hintText: 'Please enter the file location',
      initialValue: _settings.credentialsPath,
      onValueChanged: (String? v) => setState((){}),
      validationCallback: _validateJsonFileExists,
      key: _credentialsFormKey,
    );
    _preferredLanguageForm = TFormString(
      enabled: true,
      title: 'Language hint',
      subtitle: "Specify a hint to Google's API telling it what language the "
                'content is in\nLeave blank for automatic language detection',
      hintText: 'Example: "ja" for Japanese, "en" for English',
      initialValue: _settings.preferredLanguage,
      onValueChanged: (String? v) => setState((){}),
      key: _preferredLanguageFormKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _checkChangesAndConfirm,
      child: CommonScaffold(
        title: 'Rattata Vision - Settings',
        floatingActionButton: _hasChanges && !_hasErrors
          ? TSaveButton(onPressed: _saveChanges)
          : null,
        children: <Widget>[
          RoundedBorder(
            color: TFormTitle.subtitleColor,
            childPadding: const EdgeInsets.fromLTRB(0, 5, 15, 5),
            child: _refreshRateForm,
          ),
          RoundedBorder(
            color: TFormTitle.subtitleColor,
            childPadding: const EdgeInsets.fromLTRB(0, 5, 15, 5),
            child: _credentialsForm,
          ),
          RoundedBorder(
            color: TFormTitle.subtitleColor,
            childPadding: const EdgeInsets.fromLTRB(0, 5, 15, 5),
            child: _preferredLanguageForm,
          ),
        ],
      ),
    );
  }
}
