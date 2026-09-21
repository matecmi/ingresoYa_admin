import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repo/university_repo.dart';
import '../../../../domain/entities/university_entities.dart';

class ModeFormDialog extends StatefulWidget {
  const ModeFormDialog({
    super.key,
    required this.repo,
    required this.universityId,
    this.editing,
  });
  final UniversityRepo repo;
  final String universityId;
  final ModeEntity? editing;
  @override
  State<ModeFormDialog> createState() => _ModeFormDialogState();
}

class _ModeFormDialogState extends State<ModeFormDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.editing?.name ?? '');
  late final acronym = TextEditingController(
    text: widget.editing?.acronym ?? '',
  );
  late final id = widget.editing?.id ?? const Uuid().v4();
  late bool active = widget.editing?.active ?? true;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    acronym.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repo.upsertMode(
        universityId: widget.universityId,
        modeId: id,
        name: name.text,
        acronym: acronym.text,
        active: active,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FirebaseException && e.code == 'permission-denied'
              ? 'Tu sesión no tiene permiso para guardar modalidades. Comprueba el acceso de administrador.'
              : 'No se pudo guardar la modalidad. Revisa la conexión y que la universidad siga disponible. Puedes volver a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(
        widget.editing == null ? 'Nueva modalidad' : 'Editar modalidad',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre de la modalidad'
                      : null,
                ),
                TextFormField(
                  controller: acronym,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Sigla'),
                ),
                SwitchListTile(
                  title: const Text('Activa'),
                  value: active,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => active = value),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
