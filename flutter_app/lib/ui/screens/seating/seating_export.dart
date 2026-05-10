import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Seating-grid export helpers.
///
/// PNG path: rasterise the on-screen [RepaintBoundary] (caller passes its
///   GlobalKey) and trigger a `printing` share-to-disk dialog.
/// PDF path: build an A4 landscape PDF independent of the live widget tree
///   so the export looks the same regardless of viewport size, then route
///   it through the OS print dialog (browser print on web).
class SeatingExporter {
  /// Captures the [boundary] and returns a high-DPI PNG.
  static Future<Uint8List> capturePng(
    GlobalKey boundary, {
    double pixelRatio = 3.0,
  }) async {
    final ctx = boundary.currentContext;
    if (ctx == null) {
      throw StateError('Seating boundary is not yet mounted');
    }
    final renderObj = ctx.findRenderObject();
    if (renderObj is! RenderRepaintBoundary) {
      throw StateError('Boundary key is not on a RepaintBoundary');
    }
    final image = await renderObj.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Image encoding returned null');
    }
    return byteData.buffer.asUint8List();
  }

  /// Save / share the PNG via the OS dialog (Web → browser download,
  /// macOS/Windows/Linux → save dialog, iOS/Android → share sheet).
  static Future<void> sharePng(
    Uint8List pngBytes, {
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: pngBytes, filename: filename);
  }

  /// Build an A4 landscape PDF for the given seating layout. We do NOT use
  /// the live widget tree so the PDF is consistent across screen sizes.
  static Future<Uint8List> buildPdf({
    required String className,
    required DateTime date,
    required int rows,
    required int cols,
    required List<List<int?>> seats,
    required Map<int, String> studentNames,
    required Map<int, String> studentGenders, // 'male' | 'female'
  }) async {
    final fontData = await PdfGoogleFonts.notoSansSCRegular();
    final boldFontData = await PdfGoogleFonts.notoSansSCBold();
    final theme = pw.ThemeData.withFont(base: fontData, bold: boldFontData);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Title row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    '$className · 座位表',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              // Podium banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '讲  台',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 8,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 18),
              // Seating grid
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: cols,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: List.generate(rows * cols, (i) {
                    final r = i ~/ cols;
                    final c = i % cols;
                    final id = (r < seats.length && c < seats[r].length)
                        ? seats[r][c]
                        : null;
                    final name = id == null ? '空' : (studentNames[id] ?? '?');
                    final gender = id == null ? null : studentGenders[id];
                    final tint = gender == 'male'
                        ? PdfColors.blue50
                        : gender == 'female'
                            ? PdfColors.pink50
                            : PdfColors.grey200;
                    final border = gender == 'male'
                        ? PdfColors.blue200
                        : gender == 'female'
                            ? PdfColors.pink200
                            : PdfColors.grey400;
                    return pw.Container(
                      decoration: pw.BoxDecoration(
                        color: tint,
                        border: pw.Border.all(color: border, width: 0.6),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            '${r + 1}-${c + 1}',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            name,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: id == null
                                  ? PdfColors.grey500
                                  : PdfColors.grey900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  '导出于 教师助手',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// Trigger the OS print dialog (or browser print on web).
  static Future<void> printPdf(Uint8List bytes,
      {required String name}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
    );
  }
}
