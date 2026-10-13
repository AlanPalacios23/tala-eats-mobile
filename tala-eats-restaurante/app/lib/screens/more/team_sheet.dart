import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';

const Map<String, String> _roleHelp = <String, String>{
  'manager': 'Gestiona menú, pedidos y equipo.',
  'cashier': 'Atiende pedidos y cobros.',
  'kitchen': 'Ve y avanza comandas en cocina.',
};

Future<void> showTeamSheet(BuildContext context, OperationsController ops) {
  ops.loadTeam();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: _TeamSheet(ops: ops),
        ),
      ),
    ),
  );
}

class _TeamSheet extends StatefulWidget {
  const _TeamSheet({required this.ops});

  final OperationsController ops;

  @override
  State<_TeamSheet> createState() => _TeamSheetState();
}

class _TeamSheetState extends State<_TeamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = 'kitchen';
  bool _saving = false;
  bool _attempted = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() => _attempted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final failure = await widget.ops.inviteEmployee(_email.text.trim(), _role);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      showFailureSnack(context, failure);
      return;
    }
    showAppSnack(
      context,
      '${_email.text.trim()} se agregó como ${employeeRoleLabel(_role).toLowerCase()}.',
      tone: AlertTone.success,
    );
    _email.clear();
    setState(() => _attempted = false);
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.ops;
    return ListenableBuilder(
      listenable: ops,
      builder: (context, _) {
        final Widget list;
        if (ops.teamStatus == LoadStatus.failure && ops.teamFailure != null) {
          list = StateView.failure(
            ops.teamFailure!,
            onRetry: ops.loadTeam,
            compact: true,
          );
        } else if (ops.teamStatus != LoadStatus.ready) {
          list = Shimmer(
            child: Column(
              children: List<Widget>.generate(
                2,
                (i) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Bone(width: 40, height: 40, radius: 20),
                      SizedBox(width: 12),
                      Expanded(child: Bone(height: 14)),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (ops.team.isEmpty) {
          list = const StateView(
            compact: true,
            icon: Icons.groups_outlined,
            title: 'Aún no agregas a tu equipo',
            message: 'Agrega a quien te ayuda en caja o cocina para que '
                'entre con su propia cuenta.',
          );
        } else {
          list = SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < ops.team.length; i++) ...<Widget>[
                  if (i > 0) const Divider(indent: 68),
                  _MemberRow(member: ops.team[i]),
                ],
              ],
            ),
          );
        }

        return Form(
          key: _formKey,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: <Widget>[
              Text(
                'Equipo y permisos',
                style: AppText.headline.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada persona entra con su correo y ve solo lo que su rol permite.',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 20),
              list,
              const SectionHeader('Agregar al equipo'),
              AppField(
                controller: _email,
                label: 'Correo de la persona',
                hint: 'nombre@correo.com',
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              const Text('Rol', style: AppText.label),
              const SizedBox(height: 8),
              SuggestionChips(
                options: const <String>['Gerente', 'Caja', 'Cocina'],
                selected: employeeRoleLabel(_role),
                onSelected: (label) => setState(() {
                  _role = label == 'Gerente'
                      ? 'manager'
                      : label == 'Caja'
                          ? 'cashier'
                          : 'kitchen';
                }),
              ),
              const SizedBox(height: 8),
              Text(_roleHelp[_role] ?? '', style: AppText.caption),
              const SizedBox(height: 20),
              AppButton(
                label: 'Agregar al equipo',
                loadingLabel: 'Agregando…',
                loading: _saving,
                onPressed: _add,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final EmployeeInfo member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.sunken,
            child: Text(
              initials(member.name),
              style: AppText.label.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.name,
                  style: AppText.subtitle.copyWith(fontSize: 15),
                ),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tag(label: employeeRoleLabel(member.role)),
        ],
      ),
    );
  }
}
