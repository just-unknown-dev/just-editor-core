// What modules add to windows: tools, sections and overlays for a window
// by its id, in order, built from the view the window hands them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_editor_core/just_editor_core.dart';
import 'package:just_game_engine/just_game_engine.dart';

class _Adds extends EditorModule {
  final List<String> pressed = [];

  @override
  String get id => 'adds';

  @override
  String get name => 'Adds';

  @override
  List<WorkspaceContribution> get workspaceContributions => [
    WorkspaceTool(
      workspaceId: 'w',
      id: 'second',
      order: 2,
      icon: Icons.star,
      tooltip: 'Second',
      onTap: (v) => pressed.add('second ${v.path}'),
    ),
    WorkspaceTool(
      workspaceId: 'w',
      id: 'first',
      order: 1,
      icon: Icons.add,
      tooltip: 'First',
      isActive: (v) => true,
      onTap: (v) => pressed.add('first ${v.path}'),
    ),
    WorkspaceTool(
      workspaceId: 'other',
      id: 'elsewhere',
      icon: Icons.close,
      tooltip: 'Elsewhere',
      onTap: (_) {},
    ),
    WorkspaceSection(
      workspaceId: 'w',
      id: 'notes',
      title: 'Notes',
      build: (context, v) => Text('About ${v.path}'),
    ),
    WorkspaceOverlay(
      workspaceId: 'w',
      id: 'mark',
      build: (context, v, size) => Text('Over ${size.width.round()}'),
    ),
  ];
}

class _View implements WorkspaceView {
  _View(this.scope);

  @override
  final EditorScope scope;

  @override
  String get workspaceId => 'w';

  @override
  String? get path => 'a.json';

  @override
  final ValueNotifier<int> changes = ValueNotifier(0);
}

void main() {
  late _Adds module;
  late EditorScope scope;

  setUp(() {
    module = _Adds();
    scope = EditorScope(world: World()..initialize(), modules: [module]);
  });
  tearDown(() => scope.dispose());

  test("a window's own, by kind, in order", () {
    expect(
      [
        for (final t in scope.workspaceContributionsFor<WorkspaceTool>('w'))
          t.id,
      ],
      ['first', 'second'],
    );
    expect(
      scope.workspaceContributionsFor<WorkspaceSection>('w').single.id,
      'notes',
    );
    expect(
      scope.workspaceContributionsFor<WorkspaceTool>('other').single.id,
      'elsewhere',
    );
    expect(
      scope.workspaceContributionsFor<WorkspaceOverlay>('nothing'),
      isEmpty,
    );
    expect(WorkspaceIds.material2D, 'materials.material2D');
  });

  testWidgets('built from the view the window hands them', (tester) async {
    final view = _View(scope);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WorkspaceToolButtons(view: view),
              WorkspaceSections(view: view),
              SizedBox(
                width: 300,
                height: 100,
                child: Stack(
                  children: workspaceOverlays(view, const Size(300, 100)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('First'));
    await tester.tap(find.byTooltip('Second'));
    expect(module.pressed, ['first a.json', 'second a.json']);
    expect(find.byTooltip('Elsewhere'), findsNothing, reason: 'another window');
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('About a.json'), findsOneWidget);
    expect(find.text('Over 300'), findsOneWidget);
  });
}
