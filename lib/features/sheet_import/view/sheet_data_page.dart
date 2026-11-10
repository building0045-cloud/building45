import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/import_item.dart';

/// Read-only view of the cells imported from the old spreadsheet, exactly
/// as written there, grouped by sheet.
class SheetDataPage extends StatefulWidget {
  const SheetDataPage({super.key});

  @override
  State<SheetDataPage> createState() => _SheetDataPageState();
}

class _SheetDataPageState extends State<SheetDataPage> {
  late final Stream<List<ImportItem>> _items = context
      .read<ImportRepository>()
      .watchAll();
  String? _sheetGid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات الشيت القديم')),
      body: StreamBuilder<List<ImportItem>>(
        stream: _items,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('تعذر تحميل البيانات'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          if (all.isEmpty) {
            return const Center(child: Text('لم تُستورد بيانات بعد'));
          }
          // Monthly sheets in date order, then project sheets.
          final sheets =
              <String, ImportItem>{for (final i in all) i.sheetGid: i}.values
                  .toList()
                ..sort(
                  (a, b) => (a.period ?? 'z${a.sheetName}').compareTo(
                    b.period ?? 'z${b.sheetName}',
                  ),
                );
          final gid = _sheetGid ?? sheets.last.sheetGid;
          final items = all.where((i) => i.sheetGid == gid).toList()
            ..sort(
              (a, b) => a.row != b.row
                  ? a.row.compareTo(b.row)
                  : a.col.compareTo(b.col),
            );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      initialValue: gid,
                      decoration: const InputDecoration(labelText: 'الشيت'),
                      items: [
                        for (final s in sheets)
                          DropdownMenuItem(
                            value: s.sheetGid,
                            child: Text(s.sheetName),
                          ),
                      ],
                      onChanged: (v) => setState(() => _sheetGid = v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'هذه نسخة مطابقة لما كُتب في الشيت للمراجعة فقط، وليست '
                      'أرصدة أو حركات مؤكدة.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ListTile(
                          leading: item.apartmentNumber == null
                              ? const CircleAvatar(
                                  child: Icon(Icons.notes, size: 20),
                                )
                              : CircleAvatar(
                                  child: Text('${item.apartmentNumber}'),
                                ),
                          title: Text(item.originalText.trim()),
                          subtitle: Text(
                            '${item.kind.label} · خانة ${item.cell}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
