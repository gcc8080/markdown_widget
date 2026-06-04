import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/configs.dart';
import '../../proxy_rich_text.dart';
import '../../selection/selection_config.dart';
import '../../span_node.dart';
import '../../widget_visitor.dart';

class TableConfig implements ContainerConfig {
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth? defaultColumnWidth;
  final TextDirection? textDirection;
  final TableBorder? border;
  final TableCellVerticalAlignment? defaultVerticalAlignment;
  final TextBaseline? textBaseline;
  final Decoration? headerRowDecoration;
  final Decoration? bodyRowDecoration;
  final TextStyle? headerStyle;
  final TextStyle? bodyStyle;
  final EdgeInsets headPadding;
  final EdgeInsets bodyPadding;
  final WidgetWrapper? wrapper;

  const TableConfig({
    this.columnWidths,
    this.defaultColumnWidth,
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment,
    this.textBaseline,
    this.headerRowDecoration,
    this.bodyRowDecoration,
    this.headerStyle,
    this.bodyStyle,
    this.wrapper,
    this.headPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
    this.bodyPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
  });

  @nonVirtual
  @override
  String get tag => MarkdownTag.table.name;
}

class TableNode extends ElementNode {
  final MarkdownConfig config;

  TableNode(this.config);

  TableConfig get tbConfig => config.table;

  @override
  InlineSpan build() {
    List<TableRow> rows = [];

    int cellCount = 0;

    for (var child in children) {
      if (child is THeadNode) {
        cellCount = child.cellCount;
        rows.addAll(child.rows);
      } else if (child is TBodyNode) {
        rows.addAll(child.buildRows(cellCount));
      }
    }

    final tableWidget = Table(
      columnWidths: tbConfig.columnWidths,
      defaultColumnWidth: tbConfig.defaultColumnWidth ?? IntrinsicColumnWidth(),
      textBaseline: tbConfig.textBaseline,
      textDirection: tbConfig.textDirection,
      border: tbConfig.border ??
          TableBorder.all(
              color: parentStyle?.color ??
                  config.p.textStyle.color ??
                  Colors.grey),
      defaultVerticalAlignment: tbConfig.defaultVerticalAlignment ??
          TableCellVerticalAlignment.middle,
      children: rows,
    );

    return WidgetSpan(
        child: config.table.wrapper?.call(tableWidget) ?? tableWidget);
  }

  @override
  String get markdownTag => MarkdownTag.table.name;

  @override
  bool get canSelectText => false;
}

class THeadNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  THeadNode(this.config, this.visitor);

  List<TableRow> get rows => List.generate(children.length, (index) {
        final trChild = children[index] as TrNode;
        return TableRow(
            decoration: config.table.headerRowDecoration,
            children: List.generate(trChild.children.length, (index) {
              final currentTh = trChild.children[index];
              final cell = Center(
                child: Padding(
                    padding: config.table.headPadding,
                    child: ProxyRichText(
                      currentTh.build(),
                      richTextBuilder: visitor.richTextBuilder,
                    )),
              );
              return visitor.wrapSelectionTarget(
                cell,
                currentTh,
                type: MarkdownSelectionTargetType.tableCell,
                tag: MarkdownTag.th.name,
              );
            }));
      });

  int get cellCount => (children.first as TrNode).children.length;

  @override
  TextStyle? get style =>
      config.table.headerStyle?.merge(parentStyle) ??
      parentStyle ??
      config.p.textStyle.copyWith(fontWeight: FontWeight.bold);

  @override
  String get markdownTag => MarkdownTag.thead.name;
}

class TBodyNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  TBodyNode(this.config, this.visitor);

  List<TableRow> buildRows(int cellCount) {
    return List.generate(children.length, (index) {
      final child = children[index] as TrNode;
      final List<Widget> widgets =
          List.generate(cellCount, (index) => Container());
      for (var i = 0; i < child.children.length; ++i) {
        var c = child.children[i];
        final cell = Padding(
            padding: config.table.bodyPadding,
            child: ProxyRichText(
              c.build(),
              richTextBuilder: visitor.richTextBuilder,
            ));
        widgets[i] = visitor.wrapSelectionTarget(
          cell,
          c,
          type: MarkdownSelectionTargetType.tableCell,
          tag: MarkdownTag.td.name,
        );
      }
      return TableRow(
          decoration: config.table.bodyRowDecoration, children: widgets);
    });
  }

  @override
  TextStyle? get style =>
      config.table.headerStyle?.merge(parentStyle) ??
      parentStyle ??
      config.p.textStyle;

  @override
  String get markdownTag => MarkdownTag.tbody.name;
}

class TrNode extends ElementNode {
  @override
  TextStyle? get style => parentStyle;

  @override
  String get markdownTag => MarkdownTag.tr.name;
}

class ThNode extends ElementNode {
  @override
  TextStyle? get style => parentStyle;

  @override
  String get markdownTag => MarkdownTag.th.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.tableCell;
}

class TdNode extends ElementNode {
  final Map<String, String> attribute;
  final WidgetVisitor visitor;

  TdNode(this.attribute, this.visitor);

  @override
  InlineSpan build() {
    final align = attribute['align'] ?? '';
    InlineSpan result = childrenSpan;
    if (align.contains('left')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.centerLeft,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    } else if (align.contains('center')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.center,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    } else if (align.contains('right')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.centerRight,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    }
    return result;
  }

  @override
  TextStyle? get style => parentStyle;

  @override
  String get markdownTag => MarkdownTag.td.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.tableCell;
}
