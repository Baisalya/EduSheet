import 'package:edusheet/shared/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20);
  final establishedUser = now.subtract(const Duration(days: 7));

  test('waits until the user has enough launches and successful exports', () {
    expect(
      ReviewPromptPolicy.isEligible(
        launchCount: 2,
        successfulExports: 2,
        firstUsedAt: establishedUser,
        now: now,
      ),
      isFalse,
    );
    expect(
      ReviewPromptPolicy.isEligible(
        launchCount: 3,
        successfulExports: 1,
        firstUsedAt: establishedUser,
        now: now,
      ),
      isFalse,
    );
  });

  test('allows a prompt after meaningful use', () {
    expect(
      ReviewPromptPolicy.isEligible(
        launchCount: 3,
        successfulExports: 2,
        firstUsedAt: establishedUser,
        now: now,
      ),
      isTrue,
    );
  });

  test('enforces a long cooldown after a review request', () {
    expect(
      ReviewPromptPolicy.isEligible(
        launchCount: 20,
        successfulExports: 20,
        firstUsedAt: establishedUser,
        lastPromptAt: now.subtract(const Duration(days: 30)),
        now: now,
      ),
      isFalse,
    );
    expect(
      ReviewPromptPolicy.isEligible(
        launchCount: 20,
        successfulExports: 20,
        firstUsedAt: establishedUser,
        lastPromptAt: now.subtract(const Duration(days: 121)),
        now: now,
      ),
      isTrue,
    );
  });
}
