import 'package:flutter/material.dart';
import '../data/remote_api.dart';

/// Backend-verified accounting entries. A held balance is NOT a bank payout.
class DriverSettlementBalances extends StatefulWidget {
  const DriverSettlementBalances({super.key, required this.api});
  final RemoteApi api;
  @override
  State<DriverSettlementBalances> createState() => _DriverSettlementBalancesState();
}
class _DriverSettlementBalancesState extends State<DriverSettlementBalances> {
  late Future<dynamic> _future;
  @override
  void initState() {super.initState();_refresh();}
  void _refresh() {_future=widget.api.get('/driver/finance/earnings');}
  void _retry() => setState(_refresh);
  int _total(List<dynamic> rows,String field,{String? state}) {
    var cents=0;
    for(final row in rows){
      if(row is! Map)continue;
      if(state!=null && (row['state']??row['status']).toString()!=state)continue;
      final next=int.tryParse((row[field]??'').toString());
      if(next!=null && next>=0 && next<100000000)cents+=next;
    }
    return cents;
  }
  String _money(int cents) => 'MXN ' + (cents/100).toStringAsFixed(2);
  @override
  Widget build(BuildContext context) => Card(
    child:Padding(padding:const EdgeInsets.all(16),
      child:FutureBuilder<dynamic>(future:_future,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done){
          return const Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[Text('Saldo conciliado con Tala Eats',
               style:TextStyle(fontWeight:FontWeight.bold)),
              SizedBox(height:12),LinearProgressIndicator()]);
        }
        if(snapshot.hasError||snapshot.data is! Map){
          return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('No es posible verificar tus saldos ahora.',
              style:TextStyle(fontWeight:FontWeight.w600)),
            const SizedBox(height:8),
            const Text('Las estimaciones de entregas no equivalen a depósitos.'),
            TextButton.icon(onPressed:_retry,icon:const Icon(Icons.refresh),
              label:const Text('Reintentar')),
          ]);
        }
        final data=Map<dynamic,dynamic>.from(snapshot.data as Map);
        final allocations=(data['earnings_by_status'] as List?)??const [];
        final cash=(data['physical_cash_due_to_platform'] as List?)??const [];
        final held=_total(allocations,'total_minor',state:'held');
        final reviewed=_total(allocations,'total_minor',state:'reviewed');
        final due=_total(cash,'due_minor',state:'awaiting_evidence')+
          _total(cash,'due_minor',state:'submitted')+
          _total(cash,'due_minor',state:'reviewed');
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Conciliación de ganancias',
            style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),
          const SizedBox(height:12),
          _line('Pendiente de revisión',_money(held)),
          _line('Revisado (no depositado)',_money(reviewed)),
          _line('Efectivo por rendir',_money(due)),
          const SizedBox(height:8),
          const Text('Los depósitos bancarios requieren una liquidación confirmada. '
            'El efectivo debe rendirse con evidencia.',
            style:TextStyle(fontSize:12)),
          Align(alignment:Alignment.centerRight,child:TextButton.icon(
            onPressed:_retry,icon:const Icon(Icons.refresh),
            label:const Text('Actualizar'))),
        ]);
      }),
    ),
  );
  Widget _line(String label,String amount)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:6),
    child:Row(children:[
      Expanded(child:Text(label)),
      Text(amount,style:const TextStyle(fontWeight:FontWeight.w700)),
    ]),
  );
}
