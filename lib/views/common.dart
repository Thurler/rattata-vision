import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rattata_vision/widgets/dialog.dart';

abstract class CommonState<T extends StatefulWidget> extends State<T> {
  Future<void> handleException({
    required String dialogTitle,
    required String dialogBody,
    Exception? exception,
    StackTrace? trace,
  }) async {
    if (exception != null && trace != null) {
      File exceptionLog = File('./lastException.txt');
      exceptionLog.writeAsStringSync(
        'Exception: $exception\nStackTrace: $trace',
      );
    }
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return TWarningDialog(
          title: dialogTitle,
          body: dialogBody,
          confirmText: 'OK',
        );
      },
    );
  }

  Future<void> handleUnexpectedException(Exception e, StackTrace s) {
    return handleException(
      dialogTitle: 'An unexpected error occured!',
      dialogBody: 'Please report this as an issue at the link below. Please '
        'include the "lastException.txt" file that should be next to your '
        '.exe file when submitting the issue:\n'
        'https://github.com/Thurler/rattata-vision/issues',
      exception: e,
      trace: s,
    );
  }

  Future<bool> showUnsavedChangesDialog() async {
    bool? canDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const TBoolDialog(
          title: 'You have unsaved changes!',
          body: 'Are you sure you want to go back and discard your changes?',
          confirmText: 'Yes, discard them',
          cancelText: 'No, keep me here',
        );
      },
    );
    return canDiscard ?? false;
  }
}
