import 'package:flutter_test/flutter_test.dart';

import 'package:all_in_1_downloader/main.dart';

void main() {
  testWidgets('Home screen shows the app heading', (WidgetTester tester) async {
    await tester.pumpWidget(const AllIn1DownloaderApp());

    expect(find.text('All in 1 Downloader'), findsOneWidget);
    expect(find.text('Download Video'), findsOneWidget);
    expect(find.text('Download Audio'), findsOneWidget);
  });
}
