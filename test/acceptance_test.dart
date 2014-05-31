import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:markdown/markdown.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

String html = new File('test.html').readAsStringSync().trimRight();
String markdown = new File('test.markdown').readAsStringSync().trimRight();
String converted = markdownToHtml(markdown);

main() {
  if (html == converted) {
    print("Test Passed in ${(new MarkdownBench().measure()/1000 * 100).round()/100}ms");
  }
  else {
    print("Test Failed");
    List<String> htmlList = html.split('\n');
    List<String> convertedList = converted.split('\n');

    for (int i = 0; i < htmlList.length; i++) {
      if (htmlList[i] != convertedList[i]) {
        print("Error on line ${i+1}");
        print("Expected: ${htmlList[i]}");
        print(" Instead: ${convertedList[i]}");
        print("");
      }
    }

    print("Expected: ${html.replaceAll('\n', '\n          ')}");
    print("");
    print(" Instead: ${converted.replaceAll('\n', '\n          ')}");
    throw new Exception("Test Failed");
  }
}

class MarkdownBench extends BenchmarkBase {
  const MarkdownBench():super("Markdown");

  void run() {
    markdownToHtml(markdown);
  }
}

