import 'package:flutter/material.dart';
import 'package:dream_journal/l10n/strings.dart';

/// Toolbar with only Cut, Copy, Paste — replaces the default Android
/// context menu (which would also surface Lookup, Web search, etc.).
Widget buildLimitedContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final value = editableTextState.textEditingValue;
  final selection = value.selection;
  final hasSelection = selection.isValid && !selection.isCollapsed;

  final items = <ContextMenuButtonItem>[
    ContextMenuButtonItem(
      label: L.tr(context, 'cut'),
      type: ContextMenuButtonType.cut,
      onPressed: hasSelection
          ? () {
              // cutSelection already writes the selection to the clipboard
              // and removes the text from the field.
              editableTextState.cutSelection(SelectionChangedCause.toolbar);
            }
          : null,
    ),
    ContextMenuButtonItem(
      label: L.tr(context, 'copy'),
      type: ContextMenuButtonType.copy,
      onPressed: hasSelection
          ? () {
              // copySelection already writes selection to clipboard; no need
              // to set Clipboard data manually.
              editableTextState.copySelection(SelectionChangedCause.toolbar);
            }
          : null,
    ),
    ContextMenuButtonItem(
      label: L.tr(context, 'paste'),
      type: ContextMenuButtonType.paste,
      onPressed: () {
        editableTextState.pasteText(SelectionChangedCause.toolbar);
      },
    ),
  ];

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
