import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaron/widgets/place_picker_field.dart';

void main() {
  testWidgets('suggestion list closes when tapping outside the field', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlacePickerField(
                label: 'Qayerdan',
                hint: 'hint',
                controller: controller,
                accent: Colors.blue,
                mapOpen: false,
                onMapTap: () {},
                showMap: false,
              ),
              const Expanded(child: ColoredBox(color: Colors.white)),
            ],
          ),
        ),
      ),
    );

    // Tap the field to gain focus and open the suggestion list.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);

    // Tap a neutral area elsewhere on screen — the list must close.
    await tester.tapAt(const Offset(200, 500));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
}
