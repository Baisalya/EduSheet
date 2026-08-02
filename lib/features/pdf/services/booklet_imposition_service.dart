import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';

class BookletPage {
  final int? logicalPage;

  const BookletPage(this.logicalPage);

  bool get isBlank => logicalPage == null;

  @override
  String toString() => logicalPage?.toString() ?? 'blank';
}

class BookletSpread {
  final int signatureIndex;
  final int sheetIndex;
  final BookletPage frontLeft;
  final BookletPage frontRight;
  final BookletPage backLeft;
  final BookletPage backRight;

  const BookletSpread({
    required this.signatureIndex,
    required this.sheetIndex,
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
  });

  List<BookletPage> get printSequence => [
    frontLeft,
    frontRight,
    backLeft,
    backRight,
  ];
}

class BookletImpositionService {
  const BookletImpositionService();

  List<BookletSpread> impose(
    int logicalPageCount, {
    BookletSettings settings = const BookletSettings(enabled: true),
  }) {
    if (logicalPageCount < 1) {
      throw ArgumentError.value(
        logicalPageCount,
        'logicalPageCount',
        'Must be at least one.',
      );
    }
    final validationErrors = settings.validate();
    if (validationErrors.isNotEmpty) {
      throw ArgumentError(validationErrors.join(' '));
    }

    final totalPages = _roundUpToMultipleOfFour(logicalPageCount);
    if (!settings.padWithBlankPages && totalPages != logicalPageCount) {
      throw StateError(
        'Booklet imposition needs a page count divisible by four.',
      );
    }
    final signatureSize = settings.signatureSize == 0
        ? totalPages
        : settings.signatureSize;
    final spreads = <BookletSpread>[];

    var signatureIndex = 0;
    for (var start = 1; start <= totalPages; start += signatureSize) {
      final end = (start + signatureSize - 1).clamp(1, totalPages).toInt();
      var low = start;
      var high = end;
      var sheetIndex = 0;
      while (low < high) {
        spreads.add(
          BookletSpread(
            signatureIndex: signatureIndex,
            sheetIndex: sheetIndex,
            frontLeft: _page(high, logicalPageCount),
            frontRight: _page(low, logicalPageCount),
            backLeft: _page(low + 1, logicalPageCount),
            backRight: _page(high - 1, logicalPageCount),
          ),
        );
        low += 2;
        high -= 2;
        sheetIndex++;
      }
      signatureIndex++;
    }
    return spreads;
  }

  List<BookletPage> previewSequence(
    int logicalPageCount, {
    BookletSettings settings = const BookletSettings(enabled: true),
  }) {
    return impose(
      logicalPageCount,
      settings: settings,
    ).expand((spread) => spread.printSequence).toList(growable: false);
  }

  int _roundUpToMultipleOfFour(int value) => ((value + 3) ~/ 4) * 4;

  BookletPage _page(int page, int logicalPageCount) {
    return BookletPage(page <= logicalPageCount ? page : null);
  }
}
