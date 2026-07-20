import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  AssetType? _filterType;

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
    var purchases = StorageService.purchases..sort((a, b) => b.date.compareTo(a.date));
    if (_filterType != null) {
      purchases = purchases.where((p) => p.type == _filterType).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Покупки')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip(null, 'Все'),
                ...AssetType.values.map((t) => _filterChip(t, _typeLabel(t))),
              ],
            ),
          ),
          Expanded(
            child: purchases.isEmpty
                ? const Center(child: Text('Пока нет покупок'))
                : ListView.builder(
                    itemCount: purchases.length,
                    itemBuilder: (context, i) {
                      final p = purchases[i];
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
                          StorageService.deletePurchase(p.id);
                          setState(() {});
                        },
                        child: ListTile(
                          leading: CircleAvatar(child: Text(p.ticker.isNotEmpty ? p.ticker[0] : '?')),
                          title: Text('${p.ticker} — ${p.name}'),
                          subtitle: Text(
                            '${_dateFormat.format(p.date)} • ${p.quantity} шт × ${p.pricePerUnit} ${p.currency}\n'
                            '${_typeLabel(p.type)}${p.sector != null ? ' • ${p.sector}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            '${p.total.toStringAsFixed(0)} ${p.currency}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _filterChip(AssetType? type, String label) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = type),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final tickerCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '0');
    final sectorCtrl = TextEditingController();
    AssetType type = AssetType.stock;
    String currency = 'RUB';
    DateTime date = DateTime.now();

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
              const Text('Новая покупка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(labelText: 'Количество', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Цена за штуку', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Комиссия', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectorCtrl,
                decoration: const InputDecoration(labelText: 'Сектор (необязательно)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                child: Text('Дата: ${DateFormat('dd.MM.yyyy').format(date)}'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
                  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                  final fee = double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0;
                  if (tickerCtrl.text.isEmpty || qty == null || price == null) return;
                  StorageService.addPurchase(Purchase(
                    id: const Uuid().v4(),
                    date: date,
                    ticker: tickerCtrl.text.toUpperCase(),
                    name: nameCtrl.text.isEmpty ? tickerCtrl.text : nameCtrl.text,
                    type: type,
                    quantity: qty,
                    pricePerUnit: price,
                    fee: fee,
                    currency: currency,
                    sector: sectorCtrl.text.isEmpty ? null : sectorCtrl.text,
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
