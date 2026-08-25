import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/login_screen/components/form_builder_continuous_text_box.dart';
import 'package:h3xboard/views/login_screen/login_screen_controller.dart';

/// The border the field draws around itself — told apart from the framework's
/// other decorations by the shape the app gives every control.
BorderSide _borderOf(WidgetTester tester) {
  final decorated = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(ContinuousTextBox), matching: find.byType(DecoratedBox)).first,
  );
  final shape = (decorated.decoration as ShapeDecoration).shape as ContinuousRectangleBorder;

  return shape.side;
}

/// The field in a column, the way the login form holds it: an unbounded height
/// is what makes the box shrink-wrap to its content instead of filling the page.
Widget _host(Widget child) => FluentApp(
  home: Center(
    child: SizedBox(
      width: 360,
      child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
    ),
  ),
);

/// The login screen's email field, wired the way the screen wires it.
Widget _hostForm(
  GlobalKey<FormBuilderState> key, {
  AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
}) => _host(
  FormBuilder(
    key: key,
    autovalidateMode: autovalidateMode,
    child: FormBuilderContinuousTextBox(
      name: LoginScreenController.emailField,
      validator: LoginScreenController.emailValidator,
      valueTransformer: (value) => value?.trim(),
    ),
  ),
);

bool _boxHasFocus(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus;

void main() {
  group('the email rule', () {
    test('rejects a blank field', () {
      expect(LoginScreenController.emailValidator(''), isNotNull);
      expect(LoginScreenController.emailValidator(null), isNotNull);
    });

    test('rejects something that is not an address', () {
      expect(LoginScreenController.emailValidator('sander'), isNotNull);
      expect(LoginScreenController.emailValidator('sander@'), isNotNull);
      expect(LoginScreenController.emailValidator('sander@thenextapp'), isNotNull);
    });

    test('says the field is blank rather than malformed when it is blank', () {
      // The composed order (required, then email) is what makes these differ; a
      // lone email() would answer "not an address" to an untouched field.
      expect(LoginScreenController.emailValidator(''), isNot(LoginScreenController.emailValidator('sander')));
    });

    test('accepts an ordinary address', () {
      expect(LoginScreenController.emailValidator('sander@thenextapp.nl'), isNull);
      expect(LoginScreenController.emailValidator('sander+board@thenextapp.nl'), isNull);
    });
  });

  group('the password rule', () {
    test('only asks for something to be there', () {
      expect(LoginScreenController.passwordValidator(''), isNotNull);
      expect(LoginScreenController.passwordValidator(null), isNotNull);
      // Deliberately no length, case or symbol rule here: the server owns those.
      expect(LoginScreenController.passwordValidator('x'), isNull);
    });
  });

  group('a field carrying an error', () {
    testWidgets('writes the message underneath itself', (tester) async {
      await tester.pumpWidget(_host(const ContinuousTextBox(errorText: 'Nope')));

      expect(find.text('Nope'), findsOneWidget);
      expect(
        tester.getRect(find.text('Nope')).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(TextBox)).bottom),
      );
    });

    testWidgets('turns its border critical, and keeps it there while focused', (tester) async {
      await tester.pumpWidget(_host(const ContinuousTextBox()));
      final resting = _borderOf(tester);

      await tester.pumpWidget(_host(const ContinuousTextBox(errorText: 'Nope')));
      final invalid = _borderOf(tester);
      expect(invalid.color, isNot(resting.color));

      // Focus normally paints the border with the accent color; the error has to
      // outrank it, or fixing the field would hide what is wrong with it.
      await tester.tap(find.byType(TextBox));
      await tester.pump();

      expect(_borderOf(tester).color, invalid.color);
    });

    testWidgets('leaves no room for a message when there is none', (tester) async {
      await tester.pumpWidget(_host(const ContinuousTextBox()));
      final clean = tester.getSize(find.byType(ContinuousTextBox)).height;

      await tester.pumpWidget(_host(const ContinuousTextBox(errorText: 'Nope')));

      expect(tester.getSize(find.byType(ContinuousTextBox)).height, greaterThan(clean));
    });
  });

  group('the field inside a form', () {
    testWidgets('hands the form its trimmed value', (tester) async {
      final key = GlobalKey<FormBuilderState>();
      await tester.pumpWidget(_hostForm(key));

      // The trailing space a tablet keyboard adds after autocompleting.
      await tester.enterText(find.byType(TextBox), 'sander@thenextapp.nl ');

      expect(key.currentState!.saveAndValidate(), isTrue);
      expect(key.currentState!.value[LoginScreenController.emailField], 'sander@thenextapp.nl');
    });

    testWidgets('refuses a bad address and writes the reason into the box', (tester) async {
      final key = GlobalKey<FormBuilderState>();
      await tester.pumpWidget(_hostForm(key));
      await tester.enterText(find.byType(TextBox), 'sander');

      expect(key.currentState!.saveAndValidate(), isFalse);
      await tester.pump();

      expect(find.text(LoginScreenController.emailValidator('sander')!), findsOneWidget);
    });

    testWidgets('keeps the focus it is given while it is invalid', (tester) async {
      // FormState re-validates every field on every build once the user has
      // interacted, and the package's validate() focuses its own
      // `effectiveFocusNode` whenever an invalid field is left with no field
      // focused. Hand that node to anything other than the box and the two
      // disagree: the box holds the focus, the check says nothing does, and the
      // steal drops it — which on a device is the keyboard opening and shutting.
      //
      // The rebuild below is what a real keyboard does for free: it changes
      // MediaQuery.viewInsets, which ScaffoldPage reads, so the whole form
      // rebuilds the moment the keyboard appears.
      final key = GlobalKey<FormBuilderState>();
      await tester.pumpWidget(_hostForm(key, autovalidateMode: AutovalidateMode.onUserInteraction));
      await tester.enterText(find.byType(TextBox), 'sander');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextBox));
      await tester.pumpAndSettle();
      expect(_boxHasFocus(tester), isTrue, reason: 'the tap itself must focus the box');

      await tester.pumpWidget(_hostForm(key, autovalidateMode: AutovalidateMode.onUserInteraction));
      await tester.pumpAndSettle();

      expect(_boxHasFocus(tester), isTrue);
    });

    testWidgets('empties the box when the form is reset', (tester) async {
      // The value lives on the field and the text lives on a controller inside
      // the box; this is the direction that only works if the two are synced.
      final key = GlobalKey<FormBuilderState>();
      await tester.pumpWidget(_hostForm(key));
      await tester.enterText(find.byType(TextBox), 'sander@thenextapp.nl');

      key.currentState!.reset();
      await tester.pump();

      expect(find.text('sander@thenextapp.nl'), findsNothing);
      expect(key.currentState!.instantValue[LoginScreenController.emailField], anyOf(isNull, isEmpty));
    });
  });
}
