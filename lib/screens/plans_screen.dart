import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  String _typeLabel(AssetType t) {
    switch (t) {
      case AssetType.stock:
        return 'Акция';
      case AssetType.bond:
        return 'Облигация';
      case AssetType.etf:
        return 'Фонд';
      case AssetType.currency:
        return 'Валюта';
      case AssetType.other:
        return 'Другое';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = StorageService.plans
      ..sort((a, b) {
        // активные сверху, потом по дате цели
        if (a.status != b.status) {
          return a.status == PlanStatus.active ? -1 : 1;
        }
        return (a.targetDate ?? DateTime(2100)).compareTo(b.targetDate ?? DateTime(2100));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Планы покупок')),
      body: plans.isEmpty
          ? const Center(child: Text('Пока нет запланированных покупок'))
          : ListView.builder(
              itemCount: plans.length,
              itemBuilder: (context, i) {
                final p = plans[i];
                final isDone = p.status == PlanStatus.done;
                final isCancelled = p.status == PlanStatus.cancelled;

                return Dismissible(
                  key: Key(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    StorageService.deletePlan(p.id);
                    setState(() {});
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Checkbox(
                        value: isDone,
                        onChanged: (v) {
                          p.status = v == true ? PlanStatus.done : PlanStatus.active;
                          StorageService.updatePlan(p);
                          setState(() {});
                        },
                      ),
                      title: Text(
                        '${p.ticker} — ${p.name}',
                        style: TextStyle(
                          decoration: isDone || isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        '${_typeLabel(p.type)} • цель: ${p.targetQuantity} шт'
                        '${p.targetPrice != null ? " по ${p.targetPrice} " : ""}'
                        '${p.estimatedTotal != null ? "(≈${p.estimatedTotal!.toStringAsFixed(0)})" : ""}\n'
                        '${p.targetDate != null ? "к ${_dateFormat.format(p.targetDate!)}" : "без срока"}'
                        '${p.note?.isNotEmpty == true ? " • ${p.note}" : ""}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<PlanStatus>(
                        onSelected: (s) {
                          p.status = s;
                          StorageService.updatePlan(p);
                          setState(() {});
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: PlanStatus.active, child: Text('Активный')),
                          PopupMenuItem(value: PlanStatus.done, child: Text('Выполнен')),
                          PopupMenuItem(value: PlanStatus.cancelled, child: Text('Отменён')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final tickerCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    AssetType type = AssetType.stock;
    DateTime? targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новый план', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tickerCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Тикер', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Тип актива', border: OutlineInputBorder()),
                items: AssetType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                    .toList(),
                onChanged: (v) => setSheetState(() => type = v ?? AssetType.stock),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Кол-во (цель)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Желаемая цена', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: targetDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => targetDate = picked);
                },
                child: Text(targetDate == null
                    ? 'Срок (необязательно)'
                    : 'Срок: ${DateFormat('dd.MM.yyyy').format(targetDate!)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Заметка (необязательно)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
                  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                  if (tickerCtrl.text.isEmpty || qty == null) return;
                  StorageService.addPlan(Plan(
                    id: const Uuid().v4(),
                    ticker: tickerCtrl.text.toUpperCase(),
                    name: nameCtrl.text.isEmpty ? tickerCtrl.text : nameCtrl.text,
                    type: type,
                    targetQuantity: qty,
                    targetPrice: price,
                    targetDate: targetDate,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
