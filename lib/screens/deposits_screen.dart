import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/deposit.dart';
import '../services/storage_service.dart';

class DepositsScreen extends StatefulWidget {
  const DepositsScreen({super.key});

  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    final deposits = StorageService.deposits
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = deposits.fold<double>(0, (s, d) => s + d.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Пополнения')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Всего внесено'),
                    Text(
                      _currencyFormat.format(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: deposits.isEmpty
                ? const Center(child: Text('Пока нет пополнений'))
                : ListView.builder(
                    itemCount: deposits.length,
                    itemBuilder: (context, i) {
                      final d = deposits[i];
                      return Dismissible(
                        key: Key(d.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          StorageService.deleteDeposit(d.id);
                          setState(() {});
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: const Icon(Icons.add),
                          ),
                          title: Text(_currencyFormat.format(d.amount)),
                          subtitle: Text(
                            [
                              _dateFormat.format(d.date),
                              if (d.broker?.isNotEmpty == true) d.broker,
                              if (d.note?.isNotEmpty == true) d.note,
                            ].whereType<String>().join(' • '),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final brokerCtrl = TextEditingController();
    String currency = 'RUB';
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новое пополнение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Сумма', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currency,
                      decoration: const InputDecoration(labelText: 'Валюта', border: OutlineInputBorder()),
                      items: ['RUB', 'USD', 'EUR', 'CNY']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => currency = v ?? 'RUB'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2015),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Text(DateFormat('dd.MM.yyyy').format(date)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brokerCtrl,
                decoration: const InputDecoration(labelText: 'Брокер (необязательно)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Заметка (необязательно)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return;
                  StorageService.addDeposit(Deposit(
                    id: const Uuid().v4(),
                    date: date,
                    amount: amount,
                    currency: currency,
                    broker: brokerCtrl.text.isEmpty ? null : brokerCtrl.text,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
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
