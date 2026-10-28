import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/data/driver_treasury_gateway.dart';

Map<String,dynamic> _balance({bool allow=false,String bank='verified'}) => {
  'payee_kind':'driver','payee_id':31,'currency':'MXN','unit':'centavos',
  'withdrawable_cents':'34567','already_requested_cents':'1200',
  'bank':{'status':bank},
  'server_allows_requests':allow,
  'payout_execution_enabled':allow,
  'blockers':<String>[],
  'eligible':true,
};
Map<String,dynamic> _history()=>{
  'payee_kind':'driver','payee_id':31,'currency':'MXN',
  'withdrawals':[
    {'id':'8','amount_cents':'1200','status':'review_required',
     'created_at':'2026-10-27T19:00:00Z'},
  ],
};
void main(){
  test('Driver Wallet uses server exact cents and never enables release by default',(){
    final s=DriverTreasurySnapshot.parse(31,_balance(allow:true),_history());
    expect(s.driverId,31);
    expect(s.withdrawableCents,34567);
    expect(s.requestedCents,1200);
    expect(s.history.single.status,'review_required');
    expect(s.canRequest,false);
    expect(kDriverBankWithdrawalUiEnabled,false);
    expect(driverMoneyCents(34567),'\$345.67 MXN');
  });
  test('server block and unverified bank keep request disabled',(){
    for(final data in [
      _balance(allow:false),
      _balance(allow:true,bank:'pending_verification'),
      _balance(allow:true)..['blockers']=['UNKNOWN_EXTERNAL_PAYOUT'],
    ]){
      final s=DriverTreasurySnapshot.parse(31,data,_history());
      expect(s.canRequest,false);
    }
  });
  test('money missing, wrong recipient, wrong currency, unexpected status all throw',(){
    final missing=_balance()..remove('withdrawable_cents');
    final wrong=_balance()..['payee_id']=32;
    final currency=_balance()..['currency']='USD';
    for(final obj in [missing,wrong,currency]){
      expect(()=>DriverTreasurySnapshot.parse(31,obj,_history()),
        throwsFormatException);
    }
    final bad=_history()..['withdrawals']=[
      {'id':'1','amount_cents':'900','status':'success',
       'created_at':'2026-10-27T19:00:00Z'},
    ];
    expect(()=>DriverTreasurySnapshot.parse(31,_balance(),bad),
      throwsFormatException);
  });
  test('centavos and unavailable data are not silently coerced to zero',(){
    final b=_balance()..['withdrawable_cents']=345.67;
    expect(()=>DriverTreasurySnapshot.parse(31,b,_history()),
      throwsFormatException);
    final invalid=_balance()..['withdrawable_cents']='-1';
    expect(()=>DriverTreasurySnapshot.parse(31,invalid,_history()),
      throwsFormatException);
  });
}
