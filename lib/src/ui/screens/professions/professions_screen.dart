import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';

import '../../theme/app_theme.dart';
import '../../../domain/entities/profession_entity.dart';

class ProfessionsScreen extends ConsumerStatefulWidget {
  const ProfessionsScreen({super.key});

  @override
  ConsumerState<ProfessionsScreen> createState() => _ProfessionsScreenState();
}

class _ProfessionsScreenState extends ConsumerState<ProfessionsScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(professionRepoProvider);

    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: AppTheme.headerGradient(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Profesiones',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                _GlassBtn(
                  icon: Icons.add_rounded,
                  label: 'Crear',
                  onTap: () => _openForm(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _SearchBar(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              onClear: () {
                _search.clear();
                setState(() => _q = '');
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProfessionEntity>>(
              stream: repo.watchProfessions(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const [];

                final filtered = _q.trim().isEmpty
                    ? all
                    : all.where((p) {
                        final q = _q.toLowerCase();
                        return p.name.toLowerCase().contains(q) ||
                            p.acronym.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: AppTheme.cardDeco(radius: 22),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No hay profesiones (o tu búsqueda no encontró resultados).',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return _ProCard(
                      p: p,
                      onEdit: () => _openForm(context, p: p),
                      onDelete: () => _delete(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {ProfessionEntity? p}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ProfessionFormSheet(p: p),
    );
  }

  Future<void> _delete(BuildContext context, ProfessionEntity p) async {
    final ok = await _confirm(
      context,
      title: 'Eliminar profesión',
      message: 'Se eliminará "${p.name}".',
      primary: 'Eliminar',
    );
    if (!ok) return;

    await ref.read(professionRepoProvider).delete(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eliminada ✅')),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({
    required this.p,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfessionEntity p;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Icon(Icons.work_rounded, color: Colors.white.withOpacity(.92)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(text: p.acronym.isEmpty ? '—' : p.acronym),
                      _Pill(
                        text: p.active ? 'Activa' : 'Inactiva',
                        tone: p.active ? _PillTone.good : _PillTone.bad,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit),
            const SizedBox(width: 8),
            _IconMiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

class _ProfessionFormSheet extends ConsumerStatefulWidget {
  const _ProfessionFormSheet({this.p});
  final ProfessionEntity? p;

  @override
  ConsumerState<_ProfessionFormSheet> createState() => _ProfessionFormSheetState();
}

class _ProfessionFormSheetState extends ConsumerState<_ProfessionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController acronym;
  bool active = true;

  @override
  void initState() {
    name = TextEditingController(text: widget.p?.name ?? '');
    acronym = TextEditingController(text: widget.p?.acronym ?? '');
    active = widget.p?.active ?? true;
    super.initState();
  }

  @override
  void dispose() {
    name.dispose();
    acronym.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.p != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .55,
      maxChildSize: .92,
      builder: (context, scroll) {
        return Container(
          decoration: AppTheme.cardDeco(radius: 24),
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scroll,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Editar profesión' : 'Nueva profesión',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.92),
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.85)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _tf(name, 'Nombre *', requiredField: true),
                    _tf(acronym, 'Sigla'),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: active,
                      activeColor: AppTheme.accent,
                      title: Text(
                        'Activa',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => active = v);
                        HapticFeedback.selectionClick();
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        isEdit ? 'Guardar cambios' : 'Crear',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tf(TextEditingController c, String label, {bool requiredField = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.70)),
          filled: true,
          fillColor: Colors.white.withOpacity(.05),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
          ),
        ),
        validator: (v) {
          if (!requiredField) return null;
          if (v == null || v.trim().isEmpty) return 'Requerido';
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(professionRepoProvider);

    if (widget.p == null) {
      await repo.create(name: name.text, acronym: acronym.text, active: active);
    } else {
      await repo.update(widget.p!.id, {
        'name': name.text.trim(),
        'acronym': acronym.text.trim(),
        'active': active,
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
class _IconMiniBtn extends StatelessWidget {
  const _IconMiniBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.90), size: 18),
        ),
      ),
    );
  }
}

enum _PillTone { neutral, good, bad }

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.tone = _PillTone.neutral});
  final String text;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (tone == _PillTone.good) {
      bg = const Color(0xFF22C55E).withOpacity(.14);
      border = const Color(0xFF22C55E).withOpacity(.35);
    } else if (tone == _PillTone.bad) {
      bg = const Color(0xFFEF4444).withOpacity(.14);
      border = const Color(0xFFEF4444).withOpacity(.35);
    } else {
      bg = Colors.white.withOpacity(.06);
      border = Colors.white.withOpacity(.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(.90),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String primary,
}) async {
  if (!context.mounted) return false;

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(.80), height: 1.25),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(false);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withOpacity(.78)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(primary, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      );
    },
  );

  return res == true;
}
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 20),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withOpacity(.78)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, sigla, ubicación…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          _IconMiniBtn(icon: Icons.close_rounded, onTap: onClear),
        ],
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
