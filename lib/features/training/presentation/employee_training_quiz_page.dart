import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

class EmployeeTrainingQuizPage extends ConsumerStatefulWidget {
  const EmployeeTrainingQuizPage({
    required this.courseId,
    required this.courseName,
    super.key,
  });

  final int courseId;
  final String courseName;

  @override
  ConsumerState<EmployeeTrainingQuizPage> createState() =>
      _EmployeeTrainingQuizPageState();
}

class _EmployeeTrainingQuizPageState
    extends ConsumerState<EmployeeTrainingQuizPage> {
  bool _loading = true;
  bool _submitting = false;
  bool _hasSubmitted = false;
  String? _error;
  int _index = 0;
  bool _allowResultPop = false;
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _answers = {};
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questions = await ref
          .read(employeeRepositoryProvider)
          .getTrainingQuizQuestions(widget.courseId);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được câu hỏi trắc nghiệm.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || _questions.isEmpty) return;
    final answers = <Map<String, dynamic>>[];
    for (final question in _questions) {
      final id = (question['questionId'] as num?)?.toInt();
      final selected = id == null ? null : _answers[id];
      if (id == null || selected == null) {
        _message('Hãy chọn đáp án cho tất cả câu hỏi.');
        return;
      }
      answers.add({'questionId': id, 'selectedOption': selected});
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(employeeRepositoryProvider)
          .submitTrainingQuiz(widget.courseId, answers);
      if (mounted) {
        setState(() {
          _result = result;
          _hasSubmitted = true;
        });
      }
    } on ApiException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Không gửi được bài trắc nghiệm. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _leave() {
    if (!_hasSubmitted || _allowResultPop) {
      Navigator.of(context).pop(_hasSubmitted);
      return;
    }
    setState(() => _allowResultPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  void _retake() {
    setState(() {
      _result = null;
      _answers.clear();
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_hasSubmitted || _allowResultPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasSubmitted) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Bài trắc nghiệm'),
          leading: IconButton(
            tooltip: 'Quay lại đào tạo',
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _loadError()
                  : _result != null
                  ? _resultView()
                  : _quizView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại câu hỏi'),
          ),
        ],
      ),
    ),
  );

  Widget _quizView() {
    if (_questions.isEmpty) {
      return const Center(child: Text('Khóa học chưa có câu hỏi trắc nghiệm.'));
    }
    final question = _questions[_index];
    final questionId = (question['questionId'] as num?)?.toInt();
    final options = question['options'] is List
        ? (question['options'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final selected = questionId == null ? null : _answers[questionId];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.courseName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _questions.length,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/${_questions.length}'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    (question['questionText'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) {
                  if (value == null || questionId == null || _submitting) {
                    return;
                  }
                  setState(() => _answers[questionId] = value);
                },
                child: Column(
                  children: [
                    for (final option in options)
                      Card(
                        color: AppColors.surface,
                        clipBehavior: Clip.antiAlias,
                        child: RadioListTile<String>(
                          value: (option['key'] ?? '').toString(),
                          title: Text(
                            '${option['key'] ?? ''}. ${option['text'] ?? ''}',
                          ),
                          activeColor: AppColors.primary,
                          enabled: questionId != null && !_submitting,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _index == 0 || _submitting
                    ? null
                    : () => setState(() => _index--),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Trước'),
              ),
              const Spacer(),
              if (_index < _questions.length - 1)
                FilledButton.icon(
                  onPressed: selected == null || _submitting
                      ? null
                      : () => setState(() => _index++),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Tiếp theo'),
                )
              else
                FilledButton.icon(
                  onPressed: _submitting || selected == null ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_submitting ? 'Đang chấm điểm' : 'Nộp bài'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultView() {
    final result = _result!;
    final passed = result['passed'] == true;
    final answers = result['answers'] is List
        ? (result['answers'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        passed ? Icons.verified_outlined : Icons.refresh,
                        color: passed ? AppColors.secondary : AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        passed
                            ? 'Bạn đã đạt khóa học'
                            : 'Chưa đạt điểm yêu cầu',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatScore(result['score'])} điểm · cần ${formatScore(result['passScore'])} điểm',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${result['correctAnswers'] ?? 0}/${result['totalQuestions'] ?? 0} câu đúng',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Xem lại câu trả lời',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < answers.length; i++)
                _answerReview(i + 1, answers[i]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: passed
                ? FilledButton.icon(
                    onPressed: _leave,
                    icon: const Icon(Icons.check),
                    label: const Text('Hoàn tất'),
                  )
                : FilledButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.replay),
                    label: const Text('Làm lại bài trắc nghiệm'),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _answerReview(int number, Map<String, dynamic> answer) {
    final correct = answer['correct'] == true;
    return Card(
      color: AppColors.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (correct ? AppColors.secondary : AppColors.error)
              .withValues(alpha: .12),
          child: Icon(
            correct ? Icons.check : Icons.close,
            color: correct ? AppColors.secondary : AppColors.error,
          ),
        ),
        title: Text('$number. ${answer['questionText'] ?? ''}'),
        subtitle: Text(
          'Bạn chọn ${answer['selectedOption'] ?? '—'} · đáp án ${answer['correctOption'] ?? '—'}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
