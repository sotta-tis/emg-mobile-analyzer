import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/core_ml_service.dart';

// Core ML機能のUI（音声機能を除く）

class CoreMLWidget extends StatefulWidget {
  const CoreMLWidget({super.key});

  @override
  State<CoreMLWidget> createState() => _CoreMLWidgetState();
}

class _CoreMLWidgetState extends State<CoreMLWidget> {
  final TextEditingController _textController = TextEditingController();
  List<String> _availableModels = [];
  List<ClassificationResult> _classificationResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableModels() async {
    try {
      print('📱 Widget: Loading available models...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final models = await CoreMLService.getAvailableModels();
      print('📱 Widget: Loaded models: $models');
      setState(() {
        _availableModels = models;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Widget: Error loading models: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _classifyText() async {
    if (_textController.text.isEmpty) {
      setState(() {
        _errorMessage = 'テキストを入力してください';
      });
      return;
    }

    try {
      print('📱 Widget: Starting text classification...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await CoreMLService.classifyText(_textController.text);
      print('📱 Widget: Text classification completed: $results');
      print('📱 Widget: Results count: ${results.length}');
      setState(() {
        _classificationResults = results;
        _isLoading = false;
      });
      print(
        '📱 Widget: State updated, _classificationResults length: ${_classificationResults.length}',
      );
    } catch (e) {
      print('❌ Widget: Error in text classification: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndClassifyImage() async {
    try {
      print('📱 Widget: Starting image picker...');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        print('📱 Widget: No image selected');
        return;
      }

      print('📱 Widget: Image selected: ${image.path}');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final Uint8List imageData = await image.readAsBytes();
      print('📱 Widget: Image data size: ${imageData.length}');

      final results = await CoreMLService.classifyImage(imageData);
      print('📱 Widget: Image classification completed: $results');

      setState(() {
        _classificationResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Widget: Error in image classification: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Core ML モデル'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // スクロール可能なコンテンツ
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 利用可能なモデル表示
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '利用可能なモデル',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const CircularProgressIndicator()
                            else if (_errorMessage != null)
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              )
                            else
                              ..._availableModels.map(
                                (model) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text('• $model'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // テキスト分類
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'テキスト分類',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: '分類したいテキストを入力',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _classifyText,
                              child: const Text('テキストを分類'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 画像分類
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '画像分類',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _pickAndClassifyImage,
                              icon: const Icon(Icons.image),
                              label: const Text('画像を選択して分類'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 分類結果表示
                    if (_classificationResults.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '分類結果',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                  minHeight: 50,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _classificationResults.length,
                                  itemBuilder: (context, index) {
                                    final result =
                                        _classificationResults[index];
                                    return ListTile(
                                      title: Text(result.identifier),
                                      subtitle: Text(
                                        '信頼度: ${(result.confidence * 100).toStringAsFixed(1)}%',
                                      ),
                                      trailing: SizedBox(
                                        width: 60,
                                        child: LinearProgressIndicator(
                                          value: result.confidence,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                result.confidence > 0.7
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
