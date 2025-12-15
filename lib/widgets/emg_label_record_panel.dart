import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/emg_dataset_recorder_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EmgLabelRecordPanel extends ConsumerStatefulWidget {
  const EmgLabelRecordPanel({super.key});

  @override
  ConsumerState<EmgLabelRecordPanel> createState() =>
      _EmgLabelRecordPanelState();
}

class _EmgLabelRecordPanelState extends ConsumerState<EmgLabelRecordPanel> {
  String? _status;
  bool _busy = false;

  static const labels = ["paper", "cizer", "rock", "pinch"];
  static const recordDuration = Duration(seconds: 3);
  static const fileName = 'emg_dataset.json';

  Future<void> _record(String label) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Recording "$label" for ${recordDuration.inSeconds}s...';
    });

    try {
      final recorder = ref.read(emgDatasetRecorderProvider);

      await recorder.recordForLabelToMemory(
        label: label,
        duration: recordDuration,
      );

      setState(() {
        _status =
            'Recorded "$label" (total ${recorder.dataset.length} rows in memory)';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Saving(overwrite)...';
    });

    try {
      final recorder = ref.read(emgDatasetRecorderProvider);

      // ✅ ここ：まとめて上書き保存
      final file = await recorder.saveDatasetOverwrite(fileName: fileName);

      setState(() {
        _status =
            'Saved(overwrite) ${file.path} (total ${recorder.dataset.length} rows)';
      });
    } catch (e) {
      setState(() => _status = 'Save error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _clear() {
    if (_busy) return;
    final r = ref.read(emgDatasetRecorderProvider);
    r.clearDataset();
    setState(() => _status = 'Cleared (memory)');
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(emgDatasetRecorderProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dataset Recorder',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('rows(in memory): ${recorder.dataset.length}'),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  labels
                      .map(
                        (label) => ElevatedButton(
                          onPressed: _busy ? null : () => _record(label),
                          child: Text(_busy ? 'REC...' : label.toUpperCase()),
                        ),
                      )
                      .toList(),
            ),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text('SAVE (overwrite) → $fileName'),
            ),

            TextButton(
              onPressed: _busy ? null : _clear,
              child: const Text('CLEAR (memory)'),
            ),

            if (_status != null) ...[const SizedBox(height: 8), Text(_status!)],
            ElevatedButton(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        setState(() {
                          _busy = true;
                          _status = 'Exporting...';
                        });
                        try {
                          final dir = await getApplicationDocumentsDirectory();
                          final file = File('${dir.path}/emg_dataset.json');

                          if (!await file.exists()) {
                            setState(
                              () => _status = 'No file found. Save first.',
                            );
                            return;
                          }

                          await Share.shareXFiles([
                            XFile(file.path),
                          ], text: 'emg_dataset.json');

                          setState(() => _status = 'Opened share sheet.');
                        } catch (e) {
                          setState(() => _status = 'Export error: $e');
                        } finally {
                          setState(() => _busy = false);
                        }
                      },
              child: const Text('EXPORT (Share Sheet)'),
            ),
          ],
        ),
      ),
    );
  }
}
