import 'package:flutter/material.dart';

import '../../assets/asset_index.dart' show AssetIndex;
import '../../assets/package_asset_paths.dart';
import '../../io/io.dart';
import '../../look/editor_metrics.dart';
import '../../look/editor_theme.dart';
import '../../look/inspector_field.dart';

// ── Asset path picker row ─────────────────────────────────────────────────────

/// A project file picked by path: a box showing the path that opens a
/// searchable list of the files with one of [extensions] under `assets/`
/// (and the installed packages' as `packages/<name>/…`). A file dragged
/// from the editor's asset browser can be dropped on the box.
class AssetRefFieldRow extends StatefulWidget {
  const AssetRefFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.extensions = const ['png'],
    this.onGenerate,
    this.assets,
  });

  /// The field's name, in the label column.
  final String label;

  /// The chosen file's path, relative to the project (`assets/…`); empty
  /// for none, which reads `Select PNG…` (the [extensions], in capitals).
  final String value;

  /// Called with the path picked from the list, dropped on the box, or
  /// returned by [onGenerate].
  final ValueChanged<String> onChanged;

  /// The file endings listed and accepted on a drop, without the dot and
  /// in any case: `['png']` by default. `json` matches `material.json`.
  final List<String> extensions;

  /// The project's files as the editor already knows them (the scope's
  /// `assets`): listed from memory, and kept current as files come and go.
  /// Without it the assets folder is read when the list is opened.
  final AssetIndex? assets;

  /// When set, a "Generate template JSON" button beside the box runs it. It
  /// returns the new file's path, which becomes the value, or null to keep
  /// the value as it is.
  final Future<String?> Function()? onGenerate;

  @override
  State<AssetRefFieldRow> createState() => _AssetRefFieldRowState();
}

class _AssetRefFieldRowState extends State<AssetRefFieldRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _sizeAnim;
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filePaths = [];
  bool _isExpanded = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: EditorMetrics.motionFast,
    );
    _sizeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    widget.assets?.revision.addListener(_indexChanged);
    // Nothing read until the list is opened: an inspector shows many of
    // these, and each one walking the assets folder as it was built made
    // every selection read the disk.
  }

  @override
  void didUpdateWidget(AssetRefFieldRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.assets, widget.assets)) {
      old.assets?.revision.removeListener(_indexChanged);
      widget.assets?.revision.addListener(_indexChanged);
      if (_isExpanded) _scanFiles();
    }
  }

  @override
  void dispose() {
    widget.assets?.revision.removeListener(_indexChanged);
    _anim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _indexChanged() {
    if (_isExpanded) _scanFiles();
  }

  /// Whether [path] ends in `.` and one of [endings] (lower case).
  static bool _hasEnding(String path, Iterable<String> endings) {
    final lower = path.toLowerCase();
    return endings.any((e) => lower.endsWith('.$e'));
  }

  Future<void> _scanFiles() async {
    final exts = widget.extensions.map((e) => e.toLowerCase()).toSet();
    final index = widget.assets;
    final List<String> paths;
    try {
      paths = index != null
          ? [
              // By ending, so `material.json` (two dots) matches as `json`.
              for (final e in index.entries)
                if (!e.isDirectory && _hasEnding(e.path, exts)) e.path,
            ]
          : await _readFiles(exts);
    } on FileSystemException catch (e) {
      // A folder that cannot be read: the list shows what it had.
      debugPrint('Listing assets: ${e.message} ${e.path ?? ''}');
      return;
    }
    paths.sort();
    if (!mounted) return;
    setState(() => _filePaths = paths);
  }

  /// The files under the project's assets folder, and the installed
  /// packages' assets as `packages/<name>/…`, with one of [exts].
  static Future<List<String>> _readFiles(Set<String> exts) async {
    final base = Directory.current.path.replaceAll(r'\', '/');
    final assetsDir = Directory('$base/assets');
    final paths = <String>[];
    if (await assetsDir.exists()) {
      final listing = assetsDir
          .list(recursive: true, followLinks: false)
          .handleError(
            (Object _) {},
            test: (error) => error is FileSystemException,
          );
      await for (final entity in listing) {
        // By ending, so `material.json` (two dots) matches as `json` does.
        if (entity is File && _hasEnding(entity.path, exts)) {
          paths.add(
            entity.path.replaceAll(r'\', '/').replaceFirst('$base/', ''),
          );
        }
      }
    }
    paths.addAll(
      PackageAssetPaths.of(
        base,
      ).packageFiles(endings: [for (final e in exts) '.$e']),
    );
    return paths;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _anim.forward();
        // Read now — what is there now, a file added since included.
        _scanFiles();
      } else {
        _anim.reverse();
      }
    });
  }

  void _selectPath(String path) {
    widget.onChanged(path);
    setState(() {
      _isExpanded = false;
      _anim.reverse();
    });
  }

  Future<void> _handleGenerate() async {
    if (_isGenerating || widget.onGenerate == null) return;
    setState(() => _isGenerating = true);
    try {
      final path = await widget.onGenerate!();
      if (path != null && mounted) {
        widget.onChanged(path);
        await _scanFiles();
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _filePaths
        : _filePaths
              .where(
                (p) =>
                    p.split('/').last.toLowerCase().contains(query) ||
                    p.toLowerCase().contains(query),
              )
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: InspectorField.labelWidth,
              child: Text(widget.label, style: InspectorField.labelStyle),
            ),
            Expanded(
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) => _hasEnding(
                  details.data,
                  widget.extensions.map((e) => e.toLowerCase()),
                ),
                onAcceptWithDetails: (details) => _selectPath(details.data),
                builder: (context, candidateData, rejectedData) {
                  Color borderColor = EditorTheme.border;
                  if (candidateData.isNotEmpty) {
                    borderColor = EditorTheme.success;
                  } else if (rejectedData.isNotEmpty) {
                    borderColor = EditorTheme.error;
                  }
                  return GestureDetector(
                    onTap: _toggleExpanded,
                    child: Container(
                      height: InspectorField.height,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: EditorTheme.inputBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            widget.extensions.length == 1 &&
                                    widget.extensions.first.toLowerCase() ==
                                        'json'
                                ? Icons.data_object_rounded
                                : Icons.image_outlined,
                            size: 12,
                            color: EditorTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.value.isEmpty
                                  ? 'Select ${widget.extensions.map((e) => e.toUpperCase()).join('/')}…'
                                  : widget.value,
                              style: TextStyle(
                                color: widget.value.isEmpty
                                    ? EditorTheme.textMuted
                                    : EditorTheme.textPrimary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 14,
                            color: EditorTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.onGenerate != null) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: _isGenerating
                    ? Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: EditorTheme.primaryActive,
                        ),
                      )
                    : Tooltip(
                        message: 'Generate template JSON',
                        child: InkWell(
                          onTap: _handleGenerate,
                          borderRadius: BorderRadius.circular(4),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: EditorTheme.primaryMuted,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
        SizeTransition(
          sizeFactor: _sizeAnim,
          child: Container(
            margin: const EdgeInsets.only(left: 96, top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: EditorTheme.surfaceDark,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    height: 24,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: EditorTheme.textPrimary,
                        fontSize: 11,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText:
                            'Search '
                            '${widget.extensions.map((e) => e.toUpperCase()).join('/')}'
                            ' files…',
                        hintStyle: TextStyle(
                          color: EditorTheme.textMuted,
                          fontSize: 11,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 14,
                          color: EditorTheme.textMuted,
                        ),
                        filled: true,
                        fillColor: EditorTheme.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: EditorTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: EditorTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: EditorTheme.primaryActive,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: EditorTheme.border),
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _filePaths.isEmpty
                                ? 'No ${widget.extensions.join('/').toUpperCase()} files found in assets/'
                                : 'No matches for "$query"',
                            style: TextStyle(
                              color: EditorTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final path = filtered[index];
                            final isSelected = path == widget.value;
                            final filename = path.split('/').last;
                            return InkWell(
                              onTap: () => _selectPath(path),
                              child: Container(
                                color: isSelected
                                    ? EditorTheme.selectionBg
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.image_outlined,
                                      size: 12,
                                      color: Color(0xFF7DD8E0),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            filename,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? EditorTheme.textPrimary
                                                  : EditorTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            path,
                                            style: TextStyle(
                                              color: EditorTheme.textMuted,
                                              fontSize: 9,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 12,
                                        color: EditorTheme.primaryMutedLight,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
