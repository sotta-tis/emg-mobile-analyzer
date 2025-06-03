import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';

class FfiTestWidget extends StatefulWidget {
  const FfiTestWidget({super.key});

  @override
  State<FfiTestWidget> createState() => _FfiTestWidgetState();
}

class _FfiTestWidgetState extends State<FfiTestWidget> {
  final TextEditingController _aController = TextEditingController();
  final TextEditingController _bController = TextEditingController();
  int result = 0;

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('FFI Test Widget'),
        TextField(
          controller: _aController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '数値A'),
        ),
        TextField(
          controller: _bController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '数値B'),
        ),
        ElevatedButton(onPressed: _calculate, child: const Text('A + B を計算')),
        Text('計算結果: $result'),
      ],
    );
  }

  void _calculate() {
    final a = int.tryParse(_aController.text) ?? 0;
    final b = int.tryParse(_bController.text) ?? 0;
    final sum = add(a, b); // C++のadd関数を呼び出し
    setState(() {
      result = sum;
    });
  }

  int add(int a, int b) {
    final lib =
        Platform.isAndroid
            ? DynamicLibrary.open('libcalc.so')
            : DynamicLibrary.open('native_engine.framework/native_engine');

    final int Function(int, int) nativeAdd =
        lib
            .lookup<NativeFunction<Int32 Function(Int32, Int32)>>('add')
            .asFunction();

    return nativeAdd(a, b);
  }
}
