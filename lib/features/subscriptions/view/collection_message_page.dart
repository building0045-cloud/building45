import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../../core/phone.dart';
import '../../apartments/cubit/apartments_cubit.dart';
import '../../apartments/view/apartments_page.dart' show whatsappGreen;
import '../../auth/cubit/session_cubit.dart';
import '../../ledger/cubit/ledger_cubit.dart';
import '../data/arrears.dart';
import '../data/collection_message.dart';

/// Builds the monthly collection message for the building's WhatsApp
/// group from the current arrears, ready to copy or share.
class CollectionMessagePage extends StatefulWidget {
  const CollectionMessagePage({super.key});

  @override
  State<CollectionMessagePage> createState() => _CollectionMessagePageState();
}

class _CollectionMessagePageState extends State<CollectionMessagePage> {
  late final Stream<CollectionTemplate> _template = context
      .read<LedgerCubit>()
      .repo
      .watchCollectionTemplate();
  final _text = TextEditingController();
  String _period = currentPeriod();

  /// Last generated text; the field follows it until the user edits.
  String? _generated;
  bool _edited = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _sync(String message) {
    if (message == _generated) return;
    _generated = message;
    // The field cannot change while it is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_edited) _text.text = message;
    });
  }

  void _shift(int months) {
    final p = shiftPeriod(_period, months);
    if (p.compareTo(duesStartPeriod) < 0 || p.compareTo(currentPeriod()) > 0) {
      return;
    }
    setState(() {
      _period = p;
      _edited = false;
      _generated = null;
    });
  }

  void _regenerate() => setState(() {
    _edited = false;
    _text.text = _generated ?? '';
  });

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _text.text));
    messenger.showSnackBar(const SnackBar(content: Text('تم نسخ الرسالة')));
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchWhatsApp(text: _text.text)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح واتساب، انسخ الرسالة بدلًا من ذلك'),
        ),
      );
    }
  }

  Future<void> _editTemplate(CollectionTemplate current) async {
    final session = context.read<SessionCubit>().state;
    if (session is! SessionActive) return;
    final repo = context.read<LedgerCubit>().repo;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<CollectionTemplate>(
      context: context,
      builder: (_) => _TemplateDialog(initial: current),
    );
    if (result == null) return;
    try {
      await repo.saveCollectionTemplate(result, byUid: session.user.uid);
      if (mounted) setState(() => _edited = false);
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ القالب')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionCubit>().state;
    final isAdmin = session is SessionActive && session.member.isAdmin;
    final apartmentsState = context.watch<ApartmentsCubit>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('رسالة التحصيل')),
      body: StreamBuilder<CollectionTemplate>(
        stream: _template,
        builder: (context, templateSnap) => ArrearsBuilder(
          to: _period,
          builder: (context, arrears) {
            final template = templateSnap.data;
            if (arrears == null ||
                template == null ||
                apartmentsState is! ApartmentsLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            _sync(
              buildCollectionMessage(
                arrears: arrears,
                apartments: apartmentsState.apartments,
                template: template,
                period: _period,
              ),
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'الشهر السابق',
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          periodLabel(_period),
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          tooltip: 'الشهر التالي',
                          onPressed: () => _shift(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${toArabicDigits('${arrears.apartmentsOwing}')} شقة '
                      'عليها اشتراكات حتى ${periodLabel(_period)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      maxLines: null,
                      minLines: 12,
                      onChanged: (_) => _edited = true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        helperText: 'يمكنك تعديل النص قبل الإرسال؛ التعديل هنا لهذه المرة فقط.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _share,
                          style: FilledButton.styleFrom(
                            backgroundColor: whatsappGreen,
                          ),
                          icon: const FaIcon(FontAwesomeIcons.whatsapp),
                          label: const Text('مشاركة على واتساب'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy),
                          label: const Text('نسخ'),
                        ),
                        TextButton.icon(
                          onPressed: _regenerate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة التوليد'),
                        ),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () => _editTemplate(template),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('تعديل القالب'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.initial});

  final CollectionTemplate initial;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final _header = TextEditingController(text: widget.initial.header);
  late final _footer = TextEditingController(text: widget.initial.footer);

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('قالب رسالة التحصيل'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '{month} = اسم الشهر، {monthNumber} = رقم الشهر. '
                'قائمة الشقق تُضاف تلقائيًا بين البداية والنهاية.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _header,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'بداية الرسالة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _footer,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'نهاية الرسالة (المبالغ وطرق التحويل)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _header.text = CollectionTemplate.defaults.header;
            _footer.text = CollectionTemplate.defaults.footer;
          },
          child: const Text('النص الافتراضي'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(CollectionTemplate(header: _header.text, footer: _footer.text)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
