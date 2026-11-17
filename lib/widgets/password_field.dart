import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.helperText,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helperText,
      helperMaxLines: 3,
      errorMaxLines: 3,
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator:
        widget.validator ??
        (value) => value == null || value.isEmpty ? 'Isi kata sandi' : null,
  );
}
