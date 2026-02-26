import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';

import 'package:ingresoya_admin/src/domain/entities/university_entities.dart';
import 'package:ingresoya_admin/src/domain/entities/profession_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

class UniversityDetailsSheet extends ConsumerWidget {
  const UniversityDetailsSheet({super.key, required this.u});
  final UniversityEntity u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uniRepo = ref.watch(universityRepoProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .90,
      minChildSize: .62,
      maxChildSize: .97,
      builder: (context, scroll) {
        return DefaultTabController(
          length: 3,
          child: Container(
            decoration: AppTheme.cardDeco(radius: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _TopBar(title: u.name),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TabBar(
                    indicatorColor: AppTheme.accent,
                    labelColor: Colors.white.withOpacity(.92),
                    unselectedLabelColor: Colors.white.withOpacity(.60),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                    tabs: const [
                      Tab(text: 'Datos'),
                      Tab(text: 'Modalidades'),
                      Tab(text: 'Profesiones'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DatosTab(u: u),
                      _ModesTab(u: u, uniRepo: uniRepo),
                      _ProfessionsTab(u: u),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          )
        ],
      ),
    );
  }
}

class _DatosTab extends StatelessWidget {
  const _DatosTab({required this.u});
  final UniversityEntity u;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: u.acronym.isEmpty ? '—' : u.acronym),
                  _Pill(text: u.active ? 'Activa' : 'Inactiva', tone: u.active ? _PillTone.good : _PillTone.bad),
                  if (u.department.trim().isNotEmpty || u.province.trim().isNotEmpty)
                    _Pill(text: '${u.department} • ${u.province}'),
                  if (u.district.trim().isNotEmpty) _Pill(text: u.district),
                ],
              ),
              const SizedBox(height: 12),

              if (u.slogan.trim().isNotEmpty) ...[
                Text(
                  u.slogan,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.80),
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _KV(label: 'Dirección', value: u.address),
              _KV(label: 'Ubigeo', value: u.ubigeo),
              _KV(label: 'Location', value: u.location),

              const SizedBox(height: 12),
              Text(
                'Links',
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if ((u.links ?? const []).isEmpty)
                Text(
                  'Sin links',
                  style: TextStyle(color: Colors.white.withOpacity(.60), fontWeight: FontWeight.w700),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (u.links ?? const [])
                      .map((l) => _Pill(text: l, tone: _PillTone.neutral))
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(.60),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: Colors.white.withOpacity(.86),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================
/// MODES TAB (UI PRO)
/// ============================

class _ModesTab extends StatelessWidget {
  const _ModesTab({required this.u, required this.uniRepo});
  final UniversityEntity u;
  final UniversityRepo uniRepo;


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ModeEntity>>(
      stream: uniRepo.watchModes(u.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _SectionHeader(
              title: 'Modalidades',
              subtitle: '${items.length} registradas',
              actionLabel: 'Agregar',
              onAction: () => _modeDialog(context, uniRepo, u.id),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty)
              _EmptyCard(text: 'Aún no hay modalidades.'),
            ...items.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RowCard(
                  icon: Icons.verified_rounded,
                  title: m.name,
                  subtitle: m.acronym,
                  rightPill: m.active ? 'Activa' : 'Inactiva',
                  rightPillTone: m.active ? _PillTone.good : _PillTone.bad,
                  onDelete: () async {
                    final ok = await _confirmPro(
                      context,
                      title: 'Eliminar modalidad',
                      message: 'Se eliminará "${m.name}".',
                      primary: 'Eliminar',
                    );
                    if (!ok) return;
                    await uniRepo.deleteMode(universityId: u.id, modeId: m.id);
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _modeDialog(BuildContext context, dynamic repo, String universityId,
      {ModeEntity? editing}) async {
    final name = TextEditingController(text: editing?.name ?? '');
    final acronym = TextEditingController(text: editing?.acronym ?? '');
    bool active = editing?.active ?? true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          editing == null ? 'Nueva modalidad' : 'Editar modalidad',
          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogTF(ctrl: name, label: 'Nombre'),
            _DialogTF(ctrl: acronym, label: 'Sigla'),
            SwitchListTile(
              value: active,
              onChanged: (v) => active = v,
              activeColor: AppTheme.accent,
              title: Text('Activa', style: TextStyle(color: Colors.white.withOpacity(.90), fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.75))),
          ),
          ElevatedButton(
            onPressed: () async {
              await repo.upsertMode(
                universityId: universityId,
                modeId: editing?.id,
                name: name.text,
                acronym: acronym.text,
                active: active,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

/// ============================
/// PROFESSIONS TAB (nuevo modelo)
/// - catálogo global + relación uni_professions
/// ============================

class _ProfessionsTab extends ConsumerWidget {
  const _ProfessionsTab({required this.u});
  final UniversityEntity u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uniRepo = ref.watch(universityRepoProvider);
    final profRepo = ref.watch(professionRepoProvider);

    // ✅ ahora escuchamos LISTA desde el doc universidad (array professions)
    return StreamBuilder<List<ProfessionEntity>>(
      stream: uniRepo.watchUniversityProfessions(u.id),
      builder: (context, uniSnap) {
        final uniList = uniSnap.data ?? const <ProfessionEntity>[];

        // lookup rápido por id
        final selectedMap = {for (final p in uniList) p.id: p};

        return StreamBuilder<List<ProfessionEntity>>(
          stream: profRepo.watchProfessions(),
          builder: (context, catSnap) {
            if (catSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final catalog = catSnap.data ?? const <ProfessionEntity>[];

            // 🔥 lista final: seleccionadas primero
            final selected = uniList.toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _SectionHeader(
                  title: 'Profesiones',
                  subtitle: '${selected.length} seleccionadas',
                  actionLabel: 'Seleccionar',
                  onAction: () => _openPicker(context, ref, catalog, selectedMap),
                  icon: Icons.playlist_add_rounded,
                ),
                const SizedBox(height: 10),

                if (selected.isEmpty)
                  _EmptyCard(text: 'Aún no seleccionaste profesiones para esta universidad.'),

                ...selected.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RowCard(
                      icon: Icons.work_rounded,
                      title: p.name,
                      subtitle: p.acronym.isEmpty ? '—' : p.acronym,
                      rightPill: p.active ? 'Activa' : 'Inactiva',
                      rightPillTone: p.active ? _PillTone.good : _PillTone.bad,
                      onEdit: () => _editInternalProfessionDialog(context, ref, p),
                      onDelete: () async {
                        final ok = await _confirmPro(
                          context,
                          title: 'Quitar profesión',
                          message: 'Se quitará "${p.name}" de ${u.name}.',
                          primary: 'Quitar',
                        );
                        if (!ok) return;

                        await uniRepo.removeProfessionFromUniversity(
                          universityId: u.id,
                          professionId: p.id,
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    List<ProfessionEntity> catalog,
    Map<String, ProfessionEntity> selectedMap,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProfessionPickerSheet(
        universityId: u.id,
        all: catalog,
        initiallySelected: selectedMap.keys.toSet(),
      ),
    );
  }

  /// ✅ Edita la profesión dentro del ARRAY (solo para esta universidad)
  Future<void> _editInternalProfessionDialog(
    BuildContext context,
    WidgetRef ref,
    ProfessionEntity current,
  ) async {
    final name = TextEditingController(text: current.name);
    final acr = TextEditingController(text: current.acronym);
    bool active = current.active;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Editar (interno universidad)',
          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esto NO cambia el catálogo global, solo la lista interna de la universidad.',
              style: TextStyle(
                color: Colors.white.withOpacity(.70),
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            _DialogTF(ctrl: name, label: 'Nombre'),
            _DialogTF(ctrl: acr, label: 'Sigla'),
            SwitchListTile(
              value: active,
              onChanged: (v) => active = v,
              activeColor: AppTheme.accent,
              title: Text(
                'Activa',
                style: TextStyle(color: Colors.white.withOpacity(.90), fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.75))),
          ),
          ElevatedButton(
            onPressed: () async {
              final uniRepo = ref.read(universityRepoProvider);

              await uniRepo.updateUniversityProfession(
                universityId: u.id,
                professionId: current.id,
                name: name.text,
                acronym: acr.text,
                active: active,
              );

              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}


/// ============================
/// Picker con Search + Checkboxes
/// ============================

class _ProfessionPickerSheet extends ConsumerStatefulWidget {
  const _ProfessionPickerSheet({
    required this.universityId,
    required this.all,
    required this.initiallySelected,
  });

  final String universityId;
  final List<ProfessionEntity> all;
  final Set<String> initiallySelected;

  @override
  ConsumerState<_ProfessionPickerSheet> createState() => _ProfessionPickerSheetState();
}

class _ProfessionPickerSheetState extends ConsumerState<_ProfessionPickerSheet> {
  final _search = TextEditingController();
  String _q = '';

  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uniRepo = ref.watch(universityRepoProvider);

    final filtered = _q.trim().isEmpty
        ? widget.all
        : widget.all.where((p) {
            final q = _q.toLowerCase();
            return p.name.toLowerCase().contains(q) || p.acronym.toLowerCase().contains(q);
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      minChildSize: .60,
      maxChildSize: .97,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.26),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seleccionar profesiones',
                        style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.85)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _SearchBarPro(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _q = '');
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final checked = _selected.contains(p.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            if (checked) {
                              _selected.remove(p.id);
                            } else {
                              _selected.add(p.id);
                            }
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          decoration: AppTheme.cardDeco(radius: 18, color: Colors.white.withOpacity(.03)),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: checked
                                      ? Colors.white.withOpacity(.92)
                                      : Colors.white.withOpacity(.10),
                                  border: Border.all(color: Colors.white.withOpacity(.18)),
                                ),
                                child: checked
                                    ? Icon(Icons.check_rounded, size: 18, color: AppTheme.accent.withOpacity(.95))
                                    : const SizedBox.shrink(),
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
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.acronym.isEmpty ? '—' : p.acronym,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.70),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _Pill(
                                text: p.active ? 'Activa' : 'Inactiva',
                                tone: p.active ? _PillTone.good : _PillTone.bad,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
onPressed: () async {
  final uniRepo = ref.read(universityRepoProvider);

  final before = widget.initiallySelected;
  final after = _selected;

  final toAdd = after.difference(before);
  final toRemove = before.difference(after);

  // 🔥 Para agregar necesitamos el objeto completo (id, idDoc, name, acronym, active)
  final byId = {for (final p in widget.all) p.id: p};

  for (final id in toAdd) {
    final p = byId[id];
    if (p == null) continue;
    await uniRepo.addProfessionToUniversity(
      universityId: widget.universityId,
      profession: p,
    );
  }

  for (final id in toRemove) {
    await uniRepo.removeProfessionFromUniversity(
      universityId: widget.universityId,
      professionId: id,
    );
  }

  if (!context.mounted) return;
  Navigator.pop(context);
},

                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          'Guardar (${_selected.length})',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
}

/// ============================
/// UI atoms (pro)
/// ============================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(.65), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _GlassBtn(icon: icon, label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rightPill,
    required this.rightPillTone,
    this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final String rightPill;
  final _PillTone rightPillTone;

  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
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
              child: Icon(icon, color: Colors.white.withOpacity(.92)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.70),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Pill(text: rightPill, tone: rightPillTone),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (onEdit != null) ...[
              _IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit!),
              const SizedBox(width: 8),
            ],
            _IconMiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(.75), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DialogTF extends StatelessWidget {
  const _DialogTF({required this.ctrl, required this.label});
  final TextEditingController ctrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
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
    );
  }
}

class _SearchBarPro extends StatelessWidget {
  const _SearchBarPro({
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
              style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Buscar profesión…',
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
                style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
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
        text.isEmpty ? '—' : text,
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

/// Confirm PRO (estable)
Future<bool> _confirmPro(
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
          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(.80), height: 1.25),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop(false);
            },
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.78))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(primary, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      );
    },
  );

  return res == true;
}
