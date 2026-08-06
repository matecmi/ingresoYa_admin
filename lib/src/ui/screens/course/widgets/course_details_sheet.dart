import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/topic_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/Info_card.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/subtopics_part_tab.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/subtopics_tab.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/topics_tab.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_pro.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';

class CourseDetailsSheet extends ConsumerStatefulWidget {
  const CourseDetailsSheet({super.key, required this.course});
  final CourseEntity course;

  @override
  ConsumerState<CourseDetailsSheet> createState() => _CourseDetailsSheetState();
}

class _CourseDetailsSheetState extends ConsumerState<CourseDetailsSheet> {
  String? _topicSelectedId;
  String? _topicSelectedName;
  String? _subtopicSelectedId;
  String? _subtopicSelectedName;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepoProvider);
    final c = widget.course;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .62,
      maxChildSize: .97,
      builder: (context, scroll) {
        return DefaultTabController(
          length: 4,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.92),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(.85),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: AppTheme.accent,
                  labelColor: Colors.white.withOpacity(.92),
                  unselectedLabelColor: Colors.white.withOpacity(.60),
                  tabs: const [
                    Tab(text: 'Datos'),
                    Tab(text: 'Temas'),
                    Tab(text: 'Subtemas'),
                    Tab(text: 'Partes'),

                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DatosTab(course: c),
                      TopicsTab(
                        courseId: c.id,
                        repo: repo,
                        onTopicSelected: (id, name) {
                          setState(() {
                            _topicSelectedId = id;
                            _topicSelectedName = name;
                          });
                        },
                        selectedTopicId: _topicSelectedId,
                      ),
                      SubtopicsTab(
                        courseId: c.id,
                        repo: repo,
                        topicId: _topicSelectedId,
                        topicName: _topicSelectedName,
                        onSubtopicSelected: (id, name) {
                          setState(() {
                            _subtopicSelectedId = id;
                            _subtopicSelectedName = name;
                          });
                        },
                        selectedSubtopicId: _subtopicSelectedId,
                      ),
                      SubtopicsPartTab(
                        courseId: c.id,
                        repo: repo,
                        topicId: _topicSelectedId,
                        topicName: _topicSelectedName,
                        subtopicId: _subtopicSelectedId,
                        subtopicName: _subtopicSelectedName,

                      ),
              
              
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

class _DatosTab extends StatelessWidget {
  const _DatosTab({required this.course});
  final CourseEntity course;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        InfoCard(
          icon: Icons.menu_book_rounded,
          title: course.name,
          subtitle: course.description.isEmpty
              ? 'Sin descripción'
              : course.description,
          pills: [_Pill(text: 'idDoc: ${course.idDoc}')],
        ),
      ],
    );
  }
}


// ---------- UI components PRO ----------



class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return PillPro(text: text, tone: PillTone.neutral);
  }
}
