import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  test('range resolver returns whole block when offset is at the root', () {
    final generator = MarkdownGenerator();
    final results = generator.buildWidgetsWithSpans(
      '# Hello World\n\nThis is a paragraph with **bold** text.',
    );
    expect(results.length, greaterThanOrEqualTo(2));
    final headingIdx = SpanNodeIndex.build(results[0].rootSpan);
    final whole = headingIdx.wholeRange(results[0].rootSpan);
    expect(whole.text.contains('Hello'), isTrue);

    final paraIdx = SpanNodeIndex.build(results[1].rootSpan);
    expect(paraIdx.text.contains('bold'), isTrue);
    final boldOffset = paraIdx.text.indexOf('bold');
    final resolved =
        paraIdx.resolve(results[1].rootSpan, boldOffset, inlinePreferred: true);
    // Inline-preferred resolution should select something narrower than the
    // whole paragraph.
    expect(resolved.text.length < paraIdx.text.length, isTrue);
    expect(resolved.text.contains('bold'), isTrue);
  });

  test('CustomSelectionConfig defaults', () {
    const cfg = CustomSelectionConfig();
    expect(cfg.enable, isTrue);
    expect(cfg.selectTextLabel, '选取文字');
    expect(cfg.copyLabel, '复制');
  });
}
