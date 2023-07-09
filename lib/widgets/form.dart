import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rattata_vision/widgets/spaced_row.dart';

typedef FormKey = GlobalKey<TFormState<TForm>>;
typedef DropdownFormKey = GlobalKey<TFormDropdownState>;
typedef StringFormKey = GlobalKey<TFormStringState<TFormString>>;

class TFormTitle extends StatelessWidget {
  static const Color subtitleColor = Colors.grey;

  final String title;
  final String subtitle;
  final String errorMessage;

  const TFormTitle({
    required this.title,
    required this.subtitle,
    required this.errorMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: RichText(
        text: TextSpan(
          style: const TextStyle(color: subtitleColor),
          children: <TextSpan>[
            TextSpan(text: subtitle),
            TextSpan(
              text: errorMessage != '' ? '\n$errorMessage' : '',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class TFormField extends StatelessWidget {
  const TFormField({super.key});
}

class TFormDropdownField extends TFormField {
  final bool enabled;
  final String value;
  final String hintText;
  final List<String> options;
  final void Function(String? value) updateValue;

  const TFormDropdownField({
    required this.enabled,
    required this.value,
    required this.hintText,
    required this.options,
    required this.updateValue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      isExpanded: true,
      hint: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 15),
        child: Text(hintText),
      ),
      value: (value != '') ? value : null,
      onChanged: enabled ? updateValue : null,
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(option),
          ),
        );
      }).toList(),
    );
  }
}

class TFormStringField extends TFormField {
  final bool enabled;
  final String hintText;
  final TextEditingController controller;
  final List<TextInputFormatter> formatters;

  const TFormStringField({
    required this.enabled,
    required this.hintText,
    required this.controller,
    required this.formatters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      style: const TextStyle(fontSize: 18),
      inputFormatters: formatters,
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      ),
    );
  }
}

abstract class TForm extends StatefulWidget {
  static String _alwaysValid(String value) => '';

  final bool enabled;
  final String title;
  final String subtitle;
  final String errorMessage;
  final String initialValue;
  final String Function(String) validationCallback;
  final ValueChanged<String?>? onValueChanged;

  const TForm({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.initialValue,
    this.validationCallback = _alwaysValid,
    this.errorMessage = '',
    this.onValueChanged,
    super.key,
  });  
}

abstract class TFormState<T extends TForm> extends State<T> {
  String errorMessage = '';
  String initialValue = '';

  String _title = '';
  String get title => _title;
  set title(String newValue) {
    setState(() {
      _title = newValue;
    });
  }

  String _subtitle = '';
  String get subtitle => _subtitle;
  set subtitle(String newValue) {
    setState(() {
      _subtitle = newValue;
    });
  }

  TFormField get field;

  bool get hasChanges => value != initialValue;
  bool get hasErrors => errorMessage != '';

  String _value = '';
  String get value => _value;
  set value(String newValue) {
    _value = newValue;
    validate();
  }

  int get intValue => int.parse(_value.replaceAll(',', ''));
  BigInt get bigIntValue => BigInt.parse(_value.replaceAll(',', ''));

  void validate() {
    setState(() {
      errorMessage = widget.validationCallback(value);
    });
  }

  void resetInitialValue() {
    initialValue = value;
  }

  String saveValue() {
    resetInitialValue();
    return value;
  }

  int saveIntValue() {
    resetInitialValue();
    return intValue;
  }

  BigInt saveBigIntValue() {
    resetInitialValue();
    return bigIntValue;
  }

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _subtitle = widget.subtitle;
    value = widget.initialValue;
    initialValue = widget.initialValue;
    validate();
  }

  @override
  Widget build(BuildContext context) {
    return SpacedRow(
      children: <Widget>[
        TFormTitle(
          title: _title,
          subtitle: _subtitle,
          errorMessage: errorMessage,
        ),
        field,
      ],
    );
  }
}

class TFormDropdown extends TForm {
  final List<String> options;
  final String hintText;

  const TFormDropdown({
    required this.hintText,
    required this.options,
    required super.enabled,
    required super.title,
    required super.subtitle,
    required super.initialValue,
    super.validationCallback,
    super.onValueChanged,
    super.errorMessage,
    super.key,
  });

  @override
  State<TFormDropdown> createState() => TFormDropdownState();
}

class TFormDropdownState extends TFormState<TFormDropdown> {
  void _updateValue(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      super.value = value;
    });
    widget.onValueChanged?.call(value);
  }

  @override
  TFormField get field => TFormDropdownField(
    enabled: widget.enabled,
    value: super.value,
    hintText: widget.hintText,
    options: widget.options,
    updateValue: _updateValue,
  );
}

class TFormString extends TForm {
  final List<TextInputFormatter> formatters;
  final String hintText;

  const TFormString({
    required super.enabled,
    required super.title,
    required super.subtitle,
    required super.initialValue,
    this.hintText = '',
    this.formatters = const <TextInputFormatter>[],
    super.errorMessage = '',
    super.validationCallback,
    super.onValueChanged,
    super.key,
  });

  @override
  State<TFormString> createState() => TFormStringState<TFormString>();
}

class TFormStringState<T extends TFormString> extends TFormState<T> {
  final TextEditingController controller = TextEditingController();
  late List<TextInputFormatter> formatters;

  @override
  set value(String newValue) {
    controller.text = newValue;
    formatters = widget.formatters;
    super.value = newValue;
  }

  @override
  void initState() {
    super.initState();
    controller.text = widget.initialValue;
    controller.addListener(() {
      super.value = controller.text;
      widget.onValueChanged?.call(controller.text);
    });
  }

  @override
  TFormField get field => TFormStringField(
    enabled: widget.enabled,
    hintText: widget.hintText,
    controller: controller,
    formatters: formatters,
  );
}
