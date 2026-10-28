import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../data/driver_treasury_gateway.dart';
import '../core/theme.dart';
import 'common.dart';

/// Real read-only wallet for RC9. The payout button remains disabled unless
/// BOTH the authenticated backend and mobile release explicitly allow it.
class DriverTreasuryCard extends StatefulWidget {
  const DriverTreasuryCard({super.key,required this.controller});
  final DriverController controller;
  @override
  State<DriverTreasuryCard> createState() => _DriverTreasuryCardState();
}
class _DriverTreasuryCardState extends State<DriverTreasuryCard> {
  DriverTreasurySnapshot? _snapshot;
  bool _loading=false;
  bool _failed=false;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)_refresh();
    });
  }
  Future<void> _refresh() async{
    if(_loading||widget.controller.connectBackend==null)return;
    setState((){
      _loading=true;_failed=false;_snapshot=null;
    });
    try{
      final api=widget.controller.connectBackend!.api;
      final value=await DriverTreasuryGateway(api).load();
      if(mounted)setState(()=>_snapshot=value);
    }catch(_){
      if(mounted)setState(()=>_failed=true);
    }finally{
      if(mounted)setState(()=>_loading=false);
    }
  }
  Future<void> _request() async{
    final snapshot=_snapshot, backend=widget.controller.connectBackend;
    if(snapshot==null||backend==null||!snapshot.canRequest||_loading)return;
    final amount=TextEditingController();
    final totp=TextEditingController();
    try{
      final result=await showDialog<(int,String)>(
        context:context,builder:(dialogContext)=>AlertDialog(
        title:const Text('Retirar ganancias'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Disponible: ${driverMoneyCents(snapshot.withdrawableCents)}'),
          const SizedBox(height:12),
          TextField(controller:amount,keyboardType:
            const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Importe en MXN')),
          TextField(controller:totp,maxLength:6,obscureText:true,
            keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Código 2FA')),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),
            child:const Text('Cancelar')),
          TextButton(onPressed:(){
            final match=RegExp(r'^([0-9]{1,7})(?:[.,]([0-9]{1,2}))?$')
              .firstMatch(amount.text.trim());
            if(match==null||!RegExp(r'^\d{6}$').hasMatch(totp.text.trim()))return;
            final pesos=int.parse(match.group(1)!);
            final cents=int.parse((match.group(2)??'').padRight(2,'0').isEmpty?
              '0':(match.group(2)??'').padRight(2,'0'));
            final value=pesos*100+cents;
            if(value>=100&&value<=snapshot.withdrawableCents){
              Navigator.pop(dialogContext,(value,totp.text.trim()));
            }
          },child:const Text('Solicitar')),
        ],
      ));
      if(!mounted||result==null)return;
      setState(()=>_loading=true);
      try{
        await DriverTreasuryGateway(backend.api).request(
          snapshot:snapshot,amountCents:result.$1,totp:result.$2);
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Solicitud recibida. Aún no es un depósito bancario.')));
        }
      }catch(_){
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Retiro sin confirmar. Consulta historial antes de reintentar.')));
        }
      }finally{
        if(mounted)setState(()=>_loading=false);
        if(mounted)await _refresh();
      }
    }finally{
      amount.clear();amount.dispose();totp.clear();totp.dispose();
    }
  }
  @override
  Widget build(BuildContext context)=>SurfaceCard(
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Wallet · retiros',style:AppText.title),
      const SizedBox(height:Space.s),
      if(_loading)const LinearProgressIndicator()
      else if(_failed)
        const Text('Saldo no disponible. No pudimos verificar tus fondos.',
          style:AppText.bodyMuted)
      else if(_snapshot==null)
        const Text('Consulta el saldo confirmado por el servidor.',
          style:AppText.bodyMuted)
      else ...[
        const Text('Disponible para retirar',style:AppText.caption),
        const SizedBox(height:4),
        Text(driverMoneyCents(_snapshot!.withdrawableCents),
          style:AppText.money),
        const SizedBox(height:Space.s),
        Text('Solicitudes en curso: ${driverMoneyCents(_snapshot!.requestedCents)}',
          style:AppText.caption),
        Text('Cuenta: ${_snapshot!.bankStatus=='verified'?'Verificada':'Pendiente'}',
          style:AppText.caption),
        if(_snapshot!.history.isNotEmpty)...[
          const SizedBox(height:Space.m),
          const Text('Retiros recientes',style:AppText.caption),
          for(final item in _snapshot!.history.take(3))
            Padding(padding:const EdgeInsets.symmetric(vertical:3),
              child:Text('${driverMoneyCents(item.amountCents)} · '
                '${item.status=='paid'?'Pagado':item.status}',
                style:AppText.caption)),
        ],
        const SizedBox(height:Space.m),
        SizedBox(height:48,child:FilledButton(
          key:const ValueKey('driver-request-treasury-withdrawal'),
          onPressed:_snapshot!.canRequest&&!_loading?_request:null,
          child:const Text('Retirar ganancias'),
        )),
        if(!_snapshot!.canRequest)
          const Text('No disponible hasta que el backend confirme la cuenta, '
            'el saldo y la autorización de retiros.',style:AppText.caption),
      ],
      TextButton.icon(
        key:const ValueKey('driver-refresh-treasury'),
        onPressed:_loading?null:_refresh,
        icon:const Icon(Icons.refresh_rounded),
        label:const Text('Actualizar Wallet'),
      ),
    ]),
  );
}
