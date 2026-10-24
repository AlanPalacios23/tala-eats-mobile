import 'package:flutter/material.dart';
import '../data/remote/remote_api.dart';

/// Amounts read from the server's held-payee ledger. Does not show bank
/// deposits as completed until backend settlement reconciliation exists.
class RestaurantSettlementBalances extends StatefulWidget {
  const RestaurantSettlementBalances({
    super.key,required this.api,required this.restaurantId,
  });
  final RemoteApi api;
  final int restaurantId;
  @override
  State<RestaurantSettlementBalances> createState()=>_RestaurantSettlementBalancesState();
}
class _RestaurantSettlementBalancesState extends State<RestaurantSettlementBalances> {
  late Future<dynamic> _future;
  @override
  void initState(){super.initState();_reload();}
  @override
  void didUpdateWidget(covariant RestaurantSettlementBalances old){
    super.didUpdateWidget(old);
    if(old.restaurantId!=widget.restaurantId||old.api!=widget.api)_reload();
  }
  void _reload(){
    _future=widget.api.get('/owner/finance/earnings/'+widget.restaurantId.toString());
  }
  void _retry()=>setState(_reload);
  int _sum(dynamic source,String name,String state){
    if(source is! List)return 0;
    var value=0;
    for(final row in source){
      if(row is! Map)continue;
      if((row['state']??row['status']).toString()!=state)continue;
      final minor=int.tryParse((row[name]??'').toString());
      if(minor!=null&&minor>=0&&minor<100000000)value+=minor;
    }
    return value;
  }
  String _money(int minor) => 'MXN '+(minor/100).toStringAsFixed(2);
  Widget _line(String name,int minor)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:6),
    child:Row(children:[
      Expanded(child:Text(name)),
      Text(_money(minor),style:const TextStyle(fontWeight:FontWeight.w700)),
    ]),
  );
  @override
  Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(16),child:FutureBuilder<dynamic>(
      future:_future,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done){
          return const Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[Text('Liquidaciones Tala Eats',style:TextStyle(fontWeight:FontWeight.bold)),
            SizedBox(height:10),LinearProgressIndicator()]);
        }
        if(snapshot.hasError||snapshot.data is! Map){
          return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('No se pudo verificar la conciliación financiera.'),
            const SizedBox(height:8),
            const Text('Los importes de ventas no son depósitos bancarios.'),
            TextButton.icon(onPressed:_retry,icon:const Icon(Icons.refresh),
              label:const Text('Reintentar')),
          ]);
        }
        final data=Map<dynamic,dynamic>.from(snapshot.data as Map);
        final earnings=data['earnings_by_status'],cash=data['physical_cash_due_to_platform'];
        final held=_sum(earnings,'total_minor','held');
        final reviewed=_sum(earnings,'total_minor','reviewed');
        final due=_sum(cash,'due_minor','awaiting_evidence')+
          _sum(cash,'due_minor','submitted')+_sum(cash,'due_minor','reviewed');
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Liquidaciones y efectivo',
            style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
          const SizedBox(height:12),
          _line('Pendiente de revisión',held),
          _line('Revisado (no transferido)',reviewed),
          _line('Efectivo por rendir',due),
          const SizedBox(height:8),
          const Text('La transferencia Stripe Connect y el depósito al banco '
            'son estados distintos. Los saldos se actualizan desde el servidor.',
            style:TextStyle(fontSize:12)),
          Align(alignment:Alignment.centerRight,child:TextButton.icon(
            onPressed:_retry,icon:const Icon(Icons.refresh),label:const Text('Actualizar'))),
        ]);
      },
    )),
  );
}
