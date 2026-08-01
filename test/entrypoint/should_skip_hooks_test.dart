import 'package:hooksman/entrypoint/execute_hook.dart';
import 'package:test/test.dart';

void main() {
  group('shouldSkipHooks', () {
    test('HOOKSMAN=0 → skip', () {
      expect(shouldSkipHooks({'HOOKSMAN': '0'}), isTrue);
    });

    test('SKIP=1 → skip', () {
      expect(shouldSkipHooks({'SKIP': '1'}), isTrue);
    });

    test('SKIP=true → skip', () {
      expect(shouldSkipHooks({'SKIP': 'true'}), isTrue);
    });

    test('SKIP=0 → do not skip', () {
      expect(shouldSkipHooks({'SKIP': '0'}), isFalse);
    });

    test('unset → do not skip', () {
      expect(shouldSkipHooks(const {}), isFalse);
    });

    test('HOOKSMAN=1 → do not skip', () {
      expect(shouldSkipHooks({'HOOKSMAN': '1'}), isFalse);
    });
  });
}
