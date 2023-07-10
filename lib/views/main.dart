import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_vision/google_vision.dart' as gv;
import 'package:rattata_vision/views/common.dart';
import 'package:rattata_vision/views/settings.dart';
import 'package:rattata_vision/widgets/button.dart';
import 'package:rattata_vision/widgets/common_scaffold.dart';
import 'package:rattata_vision/widgets/spaced_row.dart';
import 'package:window_manager/window_manager.dart';

class UnsupportedPlatformException implements Exception {
  const UnsupportedPlatformException() : super();
}

class MainWidget extends StatefulWidget {
  const MainWidget({super.key});

  @override
  State<MainWidget> createState() => MainState();
}

class MainState extends CommonState<MainWidget> with WindowListener {
  static const MethodChannel subwindowMethodChannel = MethodChannel(
    'subwindow_channel',
  );
  static final String filename = Platform.isLinux
    ? '/tmp/rattata.png'
    : Platform.isWindows
      ? './rattata.bmp'
      : '';

  Settings _settings = Settings.fromDefault();
  Timer? _timer;
  FileImage? _image;
  bool _showSubwindow = true;
  String _recognizedText = '';

  Future<void> _navigateToSettings() async {
    _timer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsWidget(),
      ),
    );
    _startImageRefresh();
  }

  void _startImageRefresh() {
    try {
      File settingsFile = File('./settings.json');
      if (settingsFile.existsSync()) {
        _settings = Settings.fromJson(settingsFile.readAsStringSync());
      }
    } catch (e) {
      // If we fail to load the settings file, keep going with current settings
    }
    if (_settings.refreshRate != RefreshRate.manual) {
      _timer = Timer.periodic(
        _settings.refreshRate.refreshDuration,
        (Timer t) async => _updateImage(),
      );
    }
  }

  Future<void> _toggleSubwindow() async {
    if (_showSubwindow) {
      await subwindowMethodChannel.invokeMethod('hideSubwindow');
    } else {
      await subwindowMethodChannel.invokeMethod('showSubwindow');
    }
    setState(() {
      _showSubwindow = !_showSubwindow;
    });
  }

  Future<ProcessResult> _takeScreenshot(List<int> boxDimensions) async {
    if (Platform.isLinux) {
      return Process.run(
        'scrot',
        <String>[
          '-a', boxDimensions.join(','), // Rectangle to screenshot
          '-m', // Multi-display compatibility
          '-o', // Overwrite previous file
          '-z', // Quiet mode
          filename,
        ],
      );
    } else if (Platform.isWindows) {
      await subwindowMethodChannel.invokeMethod('makeScreenshot');
      return ProcessResult(0, 0, '', '');
    } else {
      throw const UnsupportedPlatformException();
    }
  }

  Future<void> _updateImage() async {
    NavigatorState state = Navigator.of(context);
    // Get the current boundaries for the snapshot from native code
    List<int> boxDimensions = await subwindowMethodChannel.invokeMethod(
      'getSubwindowBox',
    );
    // Invoke the native process to generate a screenshot, handling all errors
    try {
      ProcessResult result = await _takeScreenshot(boxDimensions);
      if (result.exitCode != 0) {
        await handleException(
          dialogTitle: 'An error occured when taking a screenshot!',
          dialogBody: 'Make sure you have installed scrot and that it works. '
                      'Automatic refreshing has been turned off to prevent '
                      'further errors.'
                      '\n\nSTDOUT: ${result.stdout}\nSTDERR: ${result.stderr}',
        );
        _timer?.cancel();
        return;
      }
    } on UnsupportedPlatformException {
      await handleException(
        dialogTitle: 'This platform is not currently supported!',
        dialogBody: 'The software only supports Linux and Windows systems.',
      );
      _timer?.cancel();
      return;
    } on ProcessException catch (e, s) {
      await handleException(
        dialogTitle: 'An exception occured when taking a screenshot!',
        dialogBody: 'Make sure you have installed scrot and that it works. '
                    'Automatic refreshing has been turned off to prevent '
                    'further errors.',
        exception: e,
        trace: s,
      );
      _timer?.cancel();
      return;
    } on Exception catch (e, s) {
      await handleUnexpectedException(e, s);
      _timer?.cancel();
      return;
    }
    // Evict the previous image from the cache, since we keep the same filename
    await _image?.evict();
    _image = FileImage(File(filename));
    if (!state.mounted) {
      return;
    }
    // Precache the new image to avoid flickering when rebuilding state
    await precacheImage(_image!, context);
    setState((){});
  }

  Future<void> _recognizeText() async {
    // If we're in manual mode, take a screenshot now
    if (_settings.refreshRate == RefreshRate.manual) {
      await _updateImage();
    }
    late gv.AnnotatedResponses responses;
    try {
      // Open a session with stored credentials
      gv.GoogleVision vision = await gv.GoogleVision.withJwt(
        _settings.credentialsPath,
      );
      // Query the API asking for text detection based on current image
      gv.ImageContext? context;
      if (_settings.preferredLanguage.isNotEmpty) {
        context = gv.ImageContext(
          languageHints: <String>[
            '${_settings.preferredLanguage}-t-i0-handwrit',
          ],
        );
      }
      responses = await vision.annotate(
        requests: gv.AnnotationRequests(
          requests: <gv.AnnotationRequest>[
            gv.AnnotationRequest(
              image: gv.Image(painter: gv.Painter.fromFile(File(filename))),
              features: <gv.Feature>[
                gv.Feature(maxResults: 10, type: 'TEXT_DETECTION'),
              ],
              imageContext: context,
            ),
          ],
        ),
      );
    } on Exception catch (e, s) {
      await handleUnexpectedException(e, s);
      return;
    }
    // Show the detected text and put it on system clipboard
    List<String> texts = <String>[];
    for (gv.AnnotateImageResponse response in responses.responses) {
      gv.FullTextAnnotation? textAnnotation = response.fullTextAnnotation;
      if (textAnnotation != null) {
        texts.add(textAnnotation.text);
      }
    }
    String finalText = texts.join('\n');
    await Clipboard.setData(ClipboardData(text: finalText));
    setState((){
      _recognizedText = finalText;
    });
  }

  @override
  Future<void> onWindowClose() async {
    await subwindowMethodChannel.invokeMethod('closeSubwindow');
    await windowManager.destroy();
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    _startImageRefresh();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Rattata Vision - v1.0.0',
      settingsLink: _navigateToSettings,
      children: <Widget>[
        SpacedRow(
          mainAxisAlignment: MainAxisAlignment.center,
          spacer: const SizedBox(width: 15),
          children: <Widget>[
            TButton(
              text: '${_showSubwindow ? 'Hide' : 'Show'} area selector',
              onPressed: _toggleSubwindow,
              usesMaxWidth: false,
            ),
            TButton(
              text: 'Update image',
              onPressed: _updateImage,
              usesMaxWidth: false,
            ),
            TButton(
              text: 'Recognize text',
              onPressed: _recognizeText,
              usesMaxWidth: false,
            ),
          ],
        ),
        const Text(
          'The recongnized text will show up below and automatically be '
          'copied to your clipboard',
        ),
        SelectableText(
          _recognizedText,
          style: const TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const Text(
          "A live preview of what will be sent to Google's API is shown below",
        ),
        if (_image != null)
          Image.file(
            _image!.file,
            key: UniqueKey(),
          ),
      ],
    );
  }
}
