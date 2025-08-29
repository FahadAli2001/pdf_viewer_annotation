// text embeded + data save on anotation 

import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MarkerParams {
  final Uint8List bytes;
  final Offset point;
  final int page;
  final int number; // marker ka asli int number
  final String label; // 👈 reg 1, reg 2 etc.
  final double zoom;
  final String note; // 👈 extra note

  MarkerParams(
    this.bytes,
    this.point,
    this.page,
    this.number,
    this.label,
    this.zoom, {
    this.note = "",
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Marker Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PDFMarkerScreen(),
    );
  }
}

class PDFMarkerScreen extends StatefulWidget {
  const PDFMarkerScreen({super.key});
  @override
  State<PDFMarkerScreen> createState() => _PDFMarkerScreenState();
}

class _PDFMarkerScreenState extends State<PDFMarkerScreen> {
  List<MarkerParams> _markers = []; // sab markers yahan store honge

  final PdfViewerController _pdfController = PdfViewerController();
  Uint8List _pdfBytes = Uint8List(0);
  double _currentZoom = 1.0;
  int _markerCounter = 1;

  // Future<void> _loadPdfFromNetwork() async {
  //   const url =
  //       "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
  //   final response = await http.get(Uri.parse(url));
  //   if (response.statusCode == 200) {
  //     setState(() => _pdfBytes = response.bodyBytes);
  //   } else {
  //     throw Exception("PDF load failed");
  //   }
  // }

  Future<void> _loadLocalPdf() async {
    final bytes = await rootBundle.load('assets/PDF.pdf');
    setState(() {
      _pdfBytes = bytes.buffer.asUint8List();
    });
  }

  @override
  void initState() {
    super.initState();
    // _loadPdfFromNetwork();
    _loadLocalPdf();
  }

  static Uint8List processPdfWithMarker(MarkerParams params) {
    final document = PdfDocument(inputBytes: params.bytes);
    final page = document.pages[params.page];

    // Draw red circle
    const radius = 30.0;
    page.graphics.drawEllipse(
      Rect.fromCircle(center: params.point, radius: radius),
      pen: PdfPen(PdfColor(255, 0, 0), width: 2),
      brush: PdfSolidBrush(PdfColor(255, 0, 0)),
    );

    // Draw white bold text inside circle
    page.graphics.drawString(
      params.label, // 👈 ab reg 1, reg 2 likhega
      PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
      bounds: Rect.fromCenter(center: params.point, width: 50, height: 50),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );

    final newBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(newBytes);
  }

  

  Future<void> _addMarker(Offset pdfPoint, int pageNumber) async {
    if (_pdfBytes.isEmpty) return;

    // 👇 user se note input
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text("Add Note for Marker"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter your note..."),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () => Navigator.pop(context, controller.text),
            ),
          ],
        );
      },
    );

    if (note == null || note.isEmpty) return;

    try {
      final markerNumber = _markers.length + 1;
      final markerLabel = "reg $markerNumber";

      final params = MarkerParams(
        _pdfBytes,
        pdfPoint,
        pageNumber - 1,
        markerNumber, // 👈 int
        markerLabel, // 👈 string label
        _currentZoom,
        note: note, // baad me user note likh sake
      );

      final Uint8List newBytes = await compute(processPdfWithMarker, params);

      setState(() {
        _pdfBytes = newBytes;
        _markers.add(params);
      });
    } catch (e) {
      log('Error adding marker: $e');
    }
  }

  void _showMarkerData(MarkerParams marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Marker ${marker.number}"),
        content: Text(marker.note),
        actions: [
          TextButton(
            child: Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Marker with Zoom"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              for (var m in _markers) {
                log(
                  "Marker ${m.number} -> Page: ${m.page + 1}, X: ${m.point.dx}, Y: ${m.point.dy}",
                );
              }
            },
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        _pdfBytes,
        controller: _pdfController,
        onZoomLevelChanged: (PdfZoomDetails details) {
          setState(() => _currentZoom = details.newZoomLevel);
          log("deatils zoom ${details.newZoomLevel}");
        },
        // onTap: (PdfGestureDetails details) {
        //   _addMarker(details.pagePosition, details.pageNumber);
        // },
        onTap: (PdfGestureDetails details) {
          final tappedPoint = details.pagePosition;

          // 👇 check marker hit
          for (var m in _markers) {
            if ((m.page + 1) == details.pageNumber) {
              final dx = (tappedPoint.dx - m.point.dx).abs();
              final dy = (tappedPoint.dy - m.point.dy).abs();
              if (dx < 20 && dy < 20) {
                // circle radius check
                _showMarkerData(m);
                return;
              }
            }
          }

          // warna naya marker banega
          _addMarker(details.pagePosition, details.pageNumber);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            child: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _pdfController.zoomLevel += 0.5;
                _currentZoom = _pdfController.zoomLevel;
              });
              log(_currentZoom.toString());
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            child: const Icon(Icons.remove),
            onPressed: () {
              setState(() {
                _pdfController.zoomLevel -= 0.5;
                _currentZoom = _pdfController.zoomLevel;
              });
            },
          ),
        ],
      ),
    );
  }
}



// // // ------------ paint style---------------

// import 'dart:typed_data';
// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:pdfx/pdfx.dart';
// import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
// import 'package:vector_math/vector_math_64.dart' show Vector3;

// /// ---------- Models

// class MarkerPoint {
//   final int page; // 1-based page index
//   final double x; // page-space X (pixels of the rendered page image)
//   final double y; // page-space Y
//   MarkerPoint({required this.page, required this.x, required this.y});
// }

// class Cluster {
//   final Offset centerScreen; // screen-space position (after transform)
//   final List<MarkerPoint> members;
//   Cluster({required this.centerScreen, required this.members});
// }

// /// ---------- App

// void main() => runApp(
//   const MaterialApp(debugShowCheckedModeBanner: false, home: PdfClusterDemo()),
// );

// class PdfClusterDemo extends StatefulWidget {
//   const PdfClusterDemo({super.key});
//   @override
//   State<PdfClusterDemo> createState() => _PdfClusterDemoState();
// }

// class _PdfClusterDemoState extends State<PdfClusterDemo> {
//   late Future<_DocBundle> _bundleFut;

//   // store markers across pages; here demo uses only page 1
//   final List<MarkerPoint> _markers = [];

//   // PDF bytes to export annotations later
//   Uint8List _pdfBytes = Uint8List(0);

//   @override
//   void initState() {
//     super.initState();
//     _bundleFut = _load();
//   }

//   Future<_DocBundle> _load() async {
//     // Load from assets (use your own source if needed)
//     final bytes = await rootBundle.load('assets/PDF.pdf');
//     _pdfBytes = bytes.buffer.asUint8List();

//     // Open with pdfx for raster rendering info
//     final doc = await PdfDocument.openData(_pdfBytes);

//     // We'll just show page 1 in this minimal demo
//     final page = await doc.getPage(1);

//     // render page as image just to get its dimensions
//     final pageImage = await page.render(
//       width: page.width,
//       height: page.height,
//       format: PdfPageImageFormat.png,
//     );

//     await page.close();

//     return _DocBundle(
//       pdfBytes: _pdfBytes,

//       firstPageSize: Size(
//         pageImage!.width!.toDouble(),
//         pageImage.height!.toDouble(),
//       ),
//       doc: doc,
//     );
//   }

//   Future<void> _exportWithAnnotations() async {
//     if (_pdfBytes.isEmpty) return;
//     final pdf = sf.PdfDocument(inputBytes: _pdfBytes);

//     for (final m in _markers) {
//       if (m.page < 1 || m.page > pdf.pages.count) continue;
//       final page = pdf.pages[m.page - 1];

//       // We saved marker coords in "rendered image pixels".
//       // Syncfusion page's size is in PDF units (points; 72 dpi).
//       // For simplicity we assume 1 image pixel == 1 PDF unit because pdfx default page size comes from 72 dpi.
//       // If you render at another scale, multiply by (pdfWidth/renderedWidth, pdfHeight/renderedHeight).
//       final r = 10.0;
//       page.graphics.drawEllipse(
//         Rect.fromCircle(center: Offset(m.x, m.y), radius: r),
//         brush: sf.PdfSolidBrush(sf.PdfColor(220, 0, 0)),
//         pen: sf.PdfPen(sf.PdfColor(255, 255, 255), width: 2),
//       );
//     }

//     final out = pdf.saveSync();
//     pdf.dispose();

//     // TODO: write `out` to a file via path_provider. For demo we just show a SnackBar.
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('PDF exported with annotations (bytes ready).'),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<_DocBundle>(
//       future: _bundleFut,
//       builder: (context, snap) {
//         final b = snap.data!;
//         if (!snap.hasData) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         return Scaffold(
//           appBar: AppBar(
//             title: const Text('PDF Clustering Overlay'),
//             actions: [
//               TextButton.icon(
//                 onPressed: _markers.isEmpty ? null : _exportWithAnnotations,
//                 icon: const Icon(Icons.save, color: Colors.white),
//                 label: const Text(
//                   'Export',
//                   style: TextStyle(color: Colors.blue),
//                 ),
//               ),
//             ],
//           ),
//           body: PdfClusterPage(
//             pdfDoc: b.doc,
//             pageNumber: 1,
//             pageSize: b.firstPageSize,
//             markers: _markers,
//             onAddMarker: (m) => setState(() => _markers.add(m)),
//           ),
//           floatingActionButton: FloatingActionButton.extended(
//             onPressed: () => setState(() => _markers.clear()),
//             label: const Text('Clear markers'),
//             icon: const Icon(Icons.clear),
//           ),
//         );
//       },
//     );
//   }
// }

// class _DocBundle {
//   final Uint8List pdfBytes;
//   final PdfDocument doc;
//   final Size firstPageSize;

//   _DocBundle({
//     required this.pdfBytes,
//     required this.doc,
//     required this.firstPageSize,
//   });
// }

// /// ---------- The core widget (one page)

// class PdfClusterPage extends StatefulWidget {
//   final PdfDocument pdfDoc;
//   final int pageNumber;
//   final Size pageSize; // pixels of rastered page at 72 dpi
//   final List<MarkerPoint> markers;
//   final ValueChanged<MarkerPoint> onAddMarker;

//   const PdfClusterPage({
//     super.key,
//     required this.pdfDoc,
//     required this.pageNumber,
//     required this.pageSize,
//     required this.markers,
//     required this.onAddMarker,
//   });

//   @override
//   State<PdfClusterPage> createState() => _PdfClusterPageState();
// }

// class _PdfClusterPageState extends State<PdfClusterPage> {
//   final _controller = TransformationController();
//   final _repaintKey = GlobalKey();

//   double get _scale => _controller.value.getMaxScaleOnAxis();

//   /// Convert a global/local position (on the viewer) to page-space coordinates
//   Offset _toPageSpace(Offset local) {
//     final inv = Matrix4.inverted(_controller.value);
//     final vec3 = inv.transform3(Vector3(local.dx, local.dy, 0));
//     return Offset(vec3.x, vec3.y);
//   }

//   /// Convert a page-space position to current screen-space (after transform)
//   Offset _toScreenSpace(Offset pagePos) {
//     final v = _controller.value.transform3(Vector3(pagePos.dx, pagePos.dy, 0));
//     return Offset(v.x, v.y);
//   }

//   List<Cluster> _computeClusters(Size screenSize) {
//     // project each marker to screen space
//     final pts = <Offset>[];
//     final list = <MarkerPoint>[];

//     for (final m in widget.markers.where(
//       (mm) => mm.page == widget.pageNumber,
//     )) {
//       final ss = _toScreenSpace(Offset(m.x, m.y));
//       pts.add(ss);
//       list.add(m);
//     }

//     final clusters = <Cluster>[];
//     const baseThreshold = 60.0; // px (screen) — tweak as you like
//     final threshold = baseThreshold; // already in screen space, no scale needed

//     final used = List<bool>.filled(pts.length, false);
//     for (int i = 0; i < pts.length; i++) {
//       if (used[i]) continue;
//       final groupIdx = <int>[i];
//       for (int j = i + 1; j < pts.length; j++) {
//         if (used[j]) continue;
//         if ((pts[i] - pts[j]).distance <= threshold) {
//           groupIdx.add(j);
//         }
//       }
//       for (final gi in groupIdx) {
//         used[gi] = true;
//       }
//       // center = avg screen position
//       final cx =
//           groupIdx.map((k) => pts[k].dx).reduce((a, b) => a + b) /
//           groupIdx.length;
//       final cy =
//           groupIdx.map((k) => pts[k].dy).reduce((a, b) => a + b) /
//           groupIdx.length;
//       clusters.add(
//         Cluster(
//           centerScreen: Offset(cx, cy),
//           members: groupIdx.map((k) => list[k]).toList(),
//         ),
//       );
//     }

//     return clusters;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pageSize = widget.pageSize;

//     return LayoutBuilder(
//       builder: (context, constraints) {
//         // Center the page in the available space
//         final pageWidget = FutureBuilder<PdfPageImage>(
//           future: widget.pdfDoc.getPage(widget.pageNumber).then((page) async {
//             final img = await page.render(
//               width: widget.pageSize.width,
//               height: widget.pageSize.height,
//             );
//             await page.close();

//             if (img == null) {
//               throw Exception("Failed to render PDF page");
//             }

//             return img; // now it's PdfPageImage (non-null)
//           }),

//           builder: (context, snapshot) {
//             if (!snapshot.hasData) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             return SizedBox(
//               width: pageSize.width,
//               height: pageSize.height,
//               child: Image.memory(snapshot.data!.bytes, fit: BoxFit.contain),
//             );
//           },
//         );
//         final clusters = _computeClusters(constraints.biggest);
//         return GestureDetector(
//           onTapUp: (d) {
//             // local (within the stack)
//             final local = (context.findRenderObject() as RenderBox)
//                 .globalToLocal(d.globalPosition);
//             // page-space point
//             final p = _toPageSpace(local);

//             // ignore taps outside page rect
//             if (p.dx < 0 ||
//                 p.dy < 0 ||
//                 p.dx > pageSize.width ||
//                 p.dy > pageSize.height)
//               return;

//             widget.onAddMarker(
//               MarkerPoint(page: widget.pageNumber, x: p.dx, y: p.dy),
//             );
//             setState(() {}); // rep aint overlay
//           },
//           child: InteractiveViewer(
//             minScale: 0.5,
//             maxScale: 6.0,
//             transformationController: _controller,
//             child: Stack(
//               key: _repaintKey,
//               children: [
//                 // Center page
//                 SizedBox(
//                   width: math.max(pageSize.width, constraints.maxWidth),
//                   height: math.max(pageSize.height, constraints.maxHeight),
//                   child: FittedBox(
//                     alignment: Alignment.center,
//                     child: pageWidget,
//                   ),
//                 ),
//                 // Dynamic overlay using CustomPaint
//                 Positioned.fill(
//                   child: Positioned.fill(
//                     child: CustomPaint(
//                       painter: _OverlayPainter(clusters: clusters),
//                     ),
//                   ),
//                   // CustomPaint(
//                   //   painter: _OverlayPainter(
//                   //     markers: widget.markers
//                   //         .where((m) => m.page == widget.pageNumber)
//                   //         .toList(),
//                   //     transform:
//                   //         _controller.value, // pass InteractiveViewer matrix
//                   //   ),
//                   // ),
//                 ),

                
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// /// ---------- Overlay painter: draws clusters/markers on top in screen space
// class _OverlayPainter extends CustomPainter {
//   final List<Cluster> clusters;

//   _OverlayPainter({required this.clusters});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final fill = Paint()..color = Colors.blue;
//     final stroke = Paint()
//       ..color = Colors.blue
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = .2;

//     final textStyle = const TextStyle(color: Colors.white, fontSize: 12);

//     for (final c in clusters) {
//       if (c.members.length == 1) {
//         // Single marker → small dot
//         canvas.drawCircle(c.centerScreen, 6, fill);
//         canvas.drawCircle(c.centerScreen, 6, stroke);
//       } else {
//         // Cluster → bigger circle + count text
//         const r = 12.0;
//         canvas.drawCircle(c.centerScreen, r, fill);
//         canvas.drawCircle(c.centerScreen, r, stroke);

//         final tp = TextPainter(
//           text: TextSpan(text: "${c.members.length}", style: textStyle),
//           textAlign: TextAlign.center,
//           textDirection: TextDirection.ltr,
//         );
//         tp.layout();
//         tp.paint(canvas, c.centerScreen - Offset(tp.width / 2, tp.height / 2));
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
// }




// // // ---------- almost done

// // // import 'dart:convert';
// // // import 'dart:developer';
// // // import 'dart:typed_data';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'package:syncfusion_flutter_pdf/pdf.dart';
// // // import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// // // /// Marker model
// // // class Marker {
// // //   final int page;
// // //   final Offset position;
// // //   Marker(this.page, this.position);
// // // }

// // // /// Cluster model
// // // class Cluster {
// // //   final int page;
// // //   final Offset center;
// // //   final List<Marker> markers;
// // //   Cluster(this.page, this.center, this.markers);
// // // }

// // // void main() => runApp(const MyApp());

// // // class MyApp extends StatelessWidget {
// // //   const MyApp({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return const MaterialApp(
// // //       debugShowCheckedModeBanner: false,
// // //       home: PDFClusterDemo(),
// // //     );
// // //   }
// // // }

// // // class PDFClusterDemo extends StatefulWidget {
// // //   const PDFClusterDemo({super.key});

// // //   @override
// // //   State<PDFClusterDemo> createState() => _PDFClusterDemoState();
// // // }

// // // class _PDFClusterDemoState extends State<PDFClusterDemo> {
// // //   final PdfViewerController _pdfController = PdfViewerController();
// // //   double _zoom = 1.0;
// // //   Uint8List _originalPdf = Uint8List(0);
// // //   Uint8List _clusteredPdf = Uint8List(0);
// // //   bool _isLoading = true;

// // //   /// Raw markers (always preserved)
// // //   final List<Marker> _allMarkers = [];

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _loadPdf();
// // //   }

// // //   void _zoomIn() {
// // //     final newZoom = (_pdfController.zoomLevel + 0.5).clamp(0.5, 5.0);
// // //     _pdfController.zoomLevel = newZoom;
// // //     setState(() {
// // //       _zoom = newZoom;
// // //     });
// // //     _updateClustering(); // Zoom change par clustering update karo
// // //   }

// // //   void _zoomOut() {
// // //     final newZoom = (_pdfController.zoomLevel - 0.5).clamp(0.5, 5.0);
// // //     _pdfController.zoomLevel = newZoom;
// // //     setState(() {
// // //       _zoom = newZoom;
// // //     });
// // //     _updateClustering(); // Zoom change par clustering update karo
// // //   }


// // //   Future<void> _loadPdf() async {
// // //     try {
// // //       // const url =
// // //       //     "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
// // //       // final res = await http.get(Uri.parse(url));
// // //        final bytes = await rootBundle.load('assets/PDF.pdf');
// // //       // if (res.statusCode == 200) {
// // //         setState(() {
// // //           _originalPdf = bytes.buffer.asUint8List();
// // //           _clusteredPdf = bytes.buffer.asUint8List();
// // //           _isLoading = false;
// // //         });
// // //       // }
// // //     } catch (e) {
// // //       log("Error loading PDF: $e");
// // //       setState(() => _isLoading = false);
// // //     }
// // //   }

// // //   /// Smart clustering logic based on zoom level
// // //   List<Cluster> _makeClusters(List<Marker> markers, double zoom) {
// // //     // Zoom level thresholds for clustering
// // //     if (_zoom > 3.0) {
// // //       // Maximum zoom - show all markers individually
// // //       return markers.map((m) => Cluster(m.page, m.position, [m])).toList();
// // //     } else if (_zoom > 1.5) {
// // //       // Medium zoom - cluster only very close markers
// // //       final threshold = 20 / _zoom;
// // //       return _createClusters(markers, threshold);
// // //     } else {
// // //       // Small zoom - aggressive clustering
// // //       final threshold = 40 / _zoom;
// // //       return _createClusters(markers, threshold);
// // //     }
// // //   }

// // //   List<Cluster> _createClusters(List<Marker> markers, double threshold) {
// // //     final List<Cluster> clusters = [];
// // //     final used = <Marker>{};

// // //     for (final m in markers) {
// // //       if (used.contains(m)) continue;

// // //       final group = <Marker>[m];
// // //       for (final other in markers) {
// // //         if (other == m || used.contains(other)) continue;
// // //         if ((other.position - m.position).distance <= threshold &&
// // //             other.page == m.page) {
// // //           group.add(other);
// // //         }
// // //       }

// // //       used.addAll(group);

// // //       if (group.length == 1) {
// // //         clusters.add(Cluster(m.page, m.position, group));
// // //       } else {
// // //         final dx =
// // //             group.map((e) => e.position.dx).reduce((a, b) => a + b) /
// // //             group.length;
// // //         final dy =
// // //             group.map((e) => e.position.dy).reduce((a, b) => a + b) /
// // //             group.length;
// // //         clusters.add(Cluster(m.page, Offset(dx, dy), group));
// // //       }
// // //     }
// // //     return clusters;
// // //   }

// // //   Uint8List _generateClusteredPdf(List<Marker> allMarkers, double zoom) {
// // //     if (allMarkers.isEmpty) return _originalPdf;

// // //     final doc = PdfDocument(inputBytes: _originalPdf);
// // //     final clusters = _makeClusters(allMarkers, zoom);

// // //     for (final cluster in clusters) {
// // //       // make sure cluster.page is valid (1-based index)
// // //       if (cluster.page < 1 || cluster.page > doc.pages.count) {
// // //         debugPrint("⚠️ Skipping invalid page: ${cluster.page}");
// // //         continue;
// // //       }

// // //       final page = doc.pages[cluster.page - 1]; // safe now ✅

// // //       if (cluster.markers.length == 1) {
// // //         // Single marker - Red circle with number
// // //         final marker = cluster.markers.first;
// // //         final markerIndex = allMarkers.indexOf(marker) + 1;

// // //         _drawSingleMarker(page, marker, markerIndex);
// // //       } else {
// // //         // Cluster - Blue circle with count
// // //         _drawCluster(page, cluster.center, cluster.markers.length);
// // //       }
// // //     }

// // //     final bytes = doc.saveSync();
// // //     doc.dispose();
// // //     return Uint8List.fromList(bytes);
// // //   }

// // //   void _drawSingleMarker(PdfPage page, Marker marker, int index) {
// // //     // Red background circle
// // //     page.graphics.drawEllipse(
// // //       Rect.fromCircle(center: marker.position, radius: 12),
// // //       brush: PdfSolidBrush(PdfColor(220, 0, 0)),
// // //     );

// // //     // White border
// // //     page.graphics.drawEllipse(
// // //       Rect.fromCircle(center: marker.position, radius: 12),
// // //       pen: PdfPen(PdfColor(255, 255, 255), width: 2),
// // //     );

// // //     // White number
// // //     page.graphics.drawString(
// // //       index.toString(),
// // //       PdfStandardFont(PdfFontFamily.helvetica, 10),
// // //       bounds: Rect.fromCenter(center: marker.position, width: 20, height: 20),
// // //       brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //       format: PdfStringFormat(
// // //         alignment: PdfTextAlignment.center,
// // //         lineAlignment: PdfVerticalAlignment.middle,
// // //       ),
// // //     );
// // //   }

// // //   void _drawCluster(PdfPage page, Offset center, int count) {
// // //     // Blue background circle
// // //     page.graphics.drawEllipse(
// // //       Rect.fromCircle(center: center, radius: 16),
// // //       brush: PdfSolidBrush(PdfColor(0, 0, 220)),
// // //     );

// // //     // White border
// // //     page.graphics.drawEllipse(
// // //       Rect.fromCircle(center: center, radius: 16),
// // //       pen: PdfPen(PdfColor(255, 255, 255), width: 2),
// // //     );

// // //     // White count
// // //     page.graphics.drawString(
// // //       count.toString(),
// // //       PdfStandardFont(PdfFontFamily.helvetica, 12),
// // //       bounds: Rect.fromCenter(center: center, width: 24, height: 24),
// // //       brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //       format: PdfStringFormat(
// // //         alignment: PdfTextAlignment.center,
// // //         lineAlignment: PdfVerticalAlignment.middle,
// // //       ),
// // //     );
// // //   }

// // //   void _updateClustering() {
// // //     final newPdf = _generateClusteredPdf(_allMarkers, _zoom);
// // //     setState(() => _clusteredPdf = newPdf);
// // //   }

// // //   Future<void> _addMarker(Offset pdfPos, int pageNum) async {
// // //     setState(() {
// // //       _allMarkers.add(Marker(pageNum, pdfPos));
// // //       _updateClustering();
// // //     });
// // //   }

// // //   void _clearAllMarkers() {
// // //     setState(() {
// // //       _allMarkers.clear();
// // //       _clusteredPdf = _originalPdf;
// // //     });
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("PDF Marker Clustering"),
// // //         backgroundColor: Colors.blue[700],
// // //         actions: [
// // //           // Statistics
// // //           Padding(
// // //             padding: const EdgeInsets.symmetric(vertical: 14.0),
// // //             child: Row(
// // //               children: [
// // //                 Text(
// // //                   '${_allMarkers.length} markers',
// // //                   style: TextStyle(
// // //                     fontWeight: FontWeight.bold,
// // //                     color: Colors.white,
// // //                   ),
// // //                 ),
// // //                 SizedBox(width: 16),
// // //                 Text(
// // //                   '${_zoom.toStringAsFixed(1)}x',
// // //                   style: TextStyle(
// // //                     fontWeight: FontWeight.bold,
// // //                     color: Colors.white,
// // //                   ),
// // //                 ),
// // //                 SizedBox(width: 8),
// // //               ],
// // //             ),
// // //           ),

// // //           IconButton(
// // //             icon: Icon(Icons.refresh, color: Colors.white),
// // //             onPressed: _updateClustering,
// // //             tooltip: "Refresh Clustering",
// // //           ),
// // //           IconButton(
// // //             icon: Icon(Icons.clear, color: Colors.white),
// // //             onPressed: _allMarkers.isEmpty ? null : _clearAllMarkers,
// // //             tooltip: "Clear All Markers",
// // //           ),
// // //         ],
// // //       ),
// // //       body: _isLoading
// // //           ? Center(child: CircularProgressIndicator())
           
// // //           : SfPdfViewer.memory(
// // //               _clusteredPdf,
// // //               controller: _pdfController,
// // //                maxZoomLevel: 5.0, 
              
// // //               onZoomLevelChanged: (details) {
// // //                 setState(() {
// // //                   _zoom = details.newZoomLevel;
// // //                   // _updateClustering();
// // //                 });
// // //               },
// // //               onTap: (details) async {
// // //                 await _addMarker(details.pagePosition, details.pageNumber);
// // //                 setState(() {
// // //                    _updateClustering();
// // //                 });
// // //               },
// // //               pageLayoutMode: PdfPageLayoutMode.single,
// // //               interactionMode: PdfInteractionMode.pan,
// // //               canShowScrollHead: true,
// // //               canShowScrollStatus: true,
// // //             ),

// // //       // Floating action button for quick actions
// // //       floatingActionButton: Column(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           FloatingActionButton(
// // //             mini: true,
// // //             child: const Icon(Icons.add),
// // //             onPressed: () {
// // //               _zoomIn();
// // //             },
// // //           ),
// // //           const SizedBox(height: 8),
// // //           FloatingActionButton(
// // //             mini: true,
// // //             child: const Icon(Icons.remove),
// // //             onPressed: () {
// // //               _zoomOut();
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }


// // // -----------------------------------------

// // //  zoom 10 pr muiltples markers with numbers
// // // import 'dart:typed_data';
// // // import 'dart:developer';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// // // import 'package:syncfusion_flutter_pdf/pdf.dart';
// // // import 'package:flutter/foundation.dart';

// // // class MarkerParams {
// // //   final Uint8List bytes;
// // //   final Offset point;
// // //   final int page;
// // //   final int number;

// // //   MarkerParams(this.bytes, this.point, this.page, this.number);
// // // }

// // // void main() {
// // //   runApp(const MyApp());
// // // }

// // // class MyApp extends StatelessWidget {
// // //   const MyApp({super.key});
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return MaterialApp(
// // //       debugShowCheckedModeBanner: false,
// // //       title: 'PDF Marker Demo',
// // //       theme: ThemeData(primarySwatch: Colors.blue),
// // //       home: const PDFMarkerScreen(),
// // //     );
// // //   }
// // // }

// // // class PDFMarkerScreen extends StatefulWidget {
// // //   const PDFMarkerScreen({super.key});
// // //   @override
// // //   State<PDFMarkerScreen> createState() => _PDFMarkerScreenState();
// // // }

// // // class _PDFMarkerScreenState extends State<PDFMarkerScreen> {
// // //   final PdfViewerController _pdfController = PdfViewerController();
// // //   Uint8List _pdfBytes = Uint8List(0);
// // //   double _currentZoom = 1.0;
// // //   int _markerCounter = 1;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _loadLocalPdf();
// // //   }

// // //   Future<void> _loadLocalPdf() async {
// // //     final bytes = await rootBundle.load('assets/PDF.pdf');
// // //     setState(() {
// // //       _pdfBytes = bytes.buffer.asUint8List();
// // //     });
// // //   }

// // //   static Uint8List processPdfWithMarker(MarkerParams params) {
// // //     final document = PdfDocument(inputBytes: params.bytes);
// // //     final page = document.pages[params.page];

// // //     // Draw red circle
// // //     page.graphics.drawEllipse(
// // //       Rect.fromCircle(center: params.point, radius: 12),
// // //       pen: PdfPen(PdfColor(255, 0, 0), width: 2),
// // //       brush: PdfSolidBrush(PdfColor(255, 0, 0)),
// // //     );

// // //     // Draw white number
// // //     page.graphics.drawString(
// // //       params.number.toString(),
// // //       PdfStandardFont(PdfFontFamily.helvetica, 18),
// // //       bounds: Rect.fromCenter(center: params.point, width: 24, height: 24),
// // //       brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //       format: PdfStringFormat(
// // //         alignment: PdfTextAlignment.center,
// // //         lineAlignment: PdfVerticalAlignment.middle,
// // //       ),
// // //     );

// // //     final newBytes = document.saveSync();
// // //     document.dispose();
// // //     return Uint8List.fromList(newBytes);
// // //   }

// // //   Future<void> _addMarker(Offset pdfPoint, int pageNumber) async {
// // //     if (_pdfBytes.isEmpty) return;

// // //     final newBytes = await compute(
// // //       processPdfWithMarker,
// // //       MarkerParams(_pdfBytes, pdfPoint, pageNumber - 1, _markerCounter),
// // //     );

// // //     setState(() {
// // //       _pdfBytes = newBytes;
// // //       _markerCounter++;
// // //     });
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(title: const Text("PDF Marker Demo")),
// // //       body: _pdfBytes.isEmpty
// // //           ? const Center(child: CircularProgressIndicator())
// // //           : SfPdfViewer.memory(
// // //             maxZoomLevel: 10,
// // //               _pdfBytes,
// // //               controller: _pdfController,
// // //               onZoomLevelChanged: (details) {
// // //                 setState(() => _currentZoom = details.newZoomLevel);
// // //               },
// // //               onTap: (details) {
// // //                 _addMarker(details.pagePosition, details.pageNumber);
// // //               },
// // //             ),
// // //       floatingActionButton: Column(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           FloatingActionButton(
// // //             mini: true,
// // //             child: const Icon(Icons.add),
// // //             onPressed: () {
// // //               setState(() {
// // //                 _pdfController.zoomLevel += 0.5;
// // //                 _currentZoom = _pdfController.zoomLevel;
// // //               });
// // //             },
// // //           ),
// // //           const SizedBox(height: 8),
// // //           FloatingActionButton(
// // //             mini: true,
// // //             child: const Icon(Icons.remove),
// // //             onPressed: () {
// // //               setState(() {
// // //                 _pdfController.zoomLevel -= 0.5;
// // //                 _currentZoom = _pdfController.zoomLevel;
// // //               });
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // ----------

// // // import 'dart:developer';
// // // import 'dart:typed_data';
// // // import 'package:flutter/material.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'package:syncfusion_flutter_pdf/pdf.dart';
// // // import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// // // /// Marker model
// // // class Marker {
// // //   final int page;
// // //   final Offset position;
// // //   Marker(this.page, this.position);
// // // }

// // // /// Cluster model
// // // class Cluster {
// // //   final int page;
// // //   final Offset center;
// // //   final List<Marker> markers;
// // //   Cluster(this.page, this.center, this.markers);
// // // }

// // // void main() => runApp(const MyApp());

// // // class MyApp extends StatelessWidget {
// // //   const MyApp({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return const MaterialApp(
// // //       debugShowCheckedModeBanner: false,
// // //       home: PDFClusterDemo(),
// // //     );
// // //   }
// // // }

// // // class PDFClusterDemo extends StatefulWidget {
// // //   const PDFClusterDemo({super.key});

// // //   @override
// // //   State<PDFClusterDemo> createState() => _PDFClusterDemoState();
// // // }

// // // class _PDFClusterDemoState extends State<PDFClusterDemo> {
// // //   final PdfViewerController _pdfController = PdfViewerController();
// // //   double _zoom = 1.0;
// // //   Uint8List _originalPdf = Uint8List(0);
// // //   Uint8List _renderedPdf = Uint8List(0);

// // //   /// Raw markers (always preserved)
// // //   final List<Marker> _allMarkers = [];

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _loadPdf();
// // //   }

// // //   Future<void> _loadPdf() async {
// // //     const url =
// // //         "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
// // //     final res = await http.get(Uri.parse(url));
// // //     if (res.statusCode == 200) {
// // //       setState(() {
// // //         _originalPdf = res.bodyBytes;
// // //         _renderedPdf = res.bodyBytes;
// // //       });
// // //     }
// // //   }

// // //   /// Clustering logic
// // //   List<Cluster> _makeClusters(List<Marker> markers, double zoom) {
// // //     const baseThreshold = 30.0; // px distance
// // //     final threshold = baseThreshold / zoom;

// // //     final List<Cluster> clusters = [];
// // //     final used = <Marker>{};

// // //     for (final m in markers) {
// // //       if (used.contains(m)) continue;

// // //       final group = <Marker>[m];
// // //       for (final other in markers) {
// // //         if (other == m || used.contains(other)) continue;
// // //         if ((other.position - m.position).distance <= threshold &&
// // //             other.page == m.page) {
// // //           group.add(other);
// // //         }
// // //       }
// // //       for (final g in group) {
// // //         used.add(g);
// // //       }

// // //       // Average center
// // //       final dx =
// // //           group.map((e) => e.position.dx).reduce((a, b) => a + b) /
// // //           group.length;
// // //       final dy =
// // //           group.map((e) => e.position.dy).reduce((a, b) => a + b) /
// // //           group.length;
// // //       clusters.add(Cluster(m.page, Offset(dx, dy), group));
// // //     }
// // //     return clusters;
// // //   }

// // //   /// Generate clustered PDF (always embedded, no overlay)
// // //   Uint8List _generatePdfWithClusters(
// // //     Uint8List baseBytes,
// // //     List<Marker> all,
// // //     double zoom,
// // //   ) {
// // //     final doc = PdfDocument(inputBytes: baseBytes);

// // //     final clusters = _makeClusters(all, zoom);

// // //     for (final c in clusters) {
// // //       final page = doc.pages[c.page - 1];
// // //       if (c.markers.length == 1) {
// // //         // Single marker → draw circle with number
// // //         final m = c.markers.first;
// // //         page.graphics.drawEllipse(
// // //           Rect.fromCircle(center: m.position, radius: 10),
// // //           pen: PdfPen(PdfColor(255, 0, 0), width: 2),
// // //           brush: PdfSolidBrush(PdfColor(255, 0, 0)),
// // //         );
// // //         page.graphics.drawString(
// // //           (_allMarkers.indexOf(m) + 1).toString(),
// // //           PdfStandardFont(PdfFontFamily.helvetica, 12),
// // //           bounds: Rect.fromCenter(center: m.position, width: 20, height: 20),
// // //           brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //           format: PdfStringFormat(
// // //             alignment: PdfTextAlignment.center,
// // //             lineAlignment: PdfVerticalAlignment.middle,
// // //           ),
// // //         );
// // //       } else {
// // //         // Cluster → blue circle with count
// // //         page.graphics.drawEllipse(
// // //           Rect.fromCircle(center: c.center, radius: 14),
// // //           pen: PdfPen(PdfColor(0, 0, 255), width: 2),
// // //           brush: PdfSolidBrush(PdfColor(0, 0, 255)),
// // //         );
// // //         page.graphics.drawString(
// // //           c.markers.length.toString(),
// // //           PdfStandardFont(PdfFontFamily.helvetica, 12),
// // //           bounds: Rect.fromCenter(center: c.center, width: 24, height: 24),
// // //           brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //           format: PdfStringFormat(
// // //             alignment: PdfTextAlignment.center,
// // //             lineAlignment: PdfVerticalAlignment.middle,
// // //           ),
// // //         );
// // //       }
// // //     }

// // //     final bytes = doc.saveSync();
// // //     doc.dispose();
// // //     return Uint8List.fromList(bytes);
// // //   }

// // //   void _refreshPdf() {
// // //     final newBytes = _generatePdfWithClusters(_originalPdf, _allMarkers, _zoom);
// // //     setState(() {
// // //       _renderedPdf = newBytes;
// // //     });
// // //   }

// // //   void _addMarker(Offset pdfPos, int pageNum) {
// // //     _allMarkers.add(Marker(pageNum, pdfPos));
// // //     _refreshPdf();
// // //   }

// // //   /// Final save with all markers individually
// // //   Uint8List _exportFinalPdf() {
// // //     final doc = PdfDocument(inputBytes: _originalPdf);
// // //     for (var i = 0; i < _allMarkers.length; i++) {
// // //       final m = _allMarkers[i];
// // //       final page = doc.pages[m.page - 1];
// // //       page.graphics.drawEllipse(
// // //         Rect.fromCircle(center: m.position, radius: 10),
// // //         pen: PdfPen(PdfColor(200, 0, 0), width: 2),
// // //         brush: PdfSolidBrush(PdfColor(200, 0, 0)),
// // //       );
// // //       page.graphics.drawString(
// // //         (i + 1).toString(),
// // //         PdfStandardFont(PdfFontFamily.helvetica, 12),
// // //         bounds: Rect.fromCenter(center: m.position, width: 20, height: 20),
// // //         brush: PdfSolidBrush(PdfColor(255, 255, 255)),
// // //         format: PdfStringFormat(
// // //           alignment: PdfTextAlignment.center,
// // //           lineAlignment: PdfVerticalAlignment.middle,
// // //         ),
// // //       );
// // //     }
// // //     final bytes = doc.saveSync();
// // //     doc.dispose();
// // //     return Uint8List.fromList(bytes);
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("Clustered PDF Markers"),
// // //         actions: [
// // //           IconButton(
// // //             icon: const Icon(Icons.save),
// // //             onPressed: () {
// // //               final finalBytes = _exportFinalPdf();
// // //               log("✅ Final PDF saved with ${_allMarkers.length} markers");
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //       body: _renderedPdf.isEmpty
// // //           ? const Center(child: CircularProgressIndicator())
// // //           : SfPdfViewer.memory(
// // //               _renderedPdf,
// // //               controller: _pdfController,
// // //               onZoomLevelChanged: (details) {
// // //                 setState(() => _zoom = details.newZoomLevel);
// // //               },
// // //               onTap: (details) {
// // //                 _addMarker(details.pagePosition, details.pageNumber);
// // //               },
// // //             ),
// // //     );
// // //   }
// // // }

// // // // ------- pdf tron -----
// // // import 'dart:developer';
// // // import 'dart:io';
// // // import 'package:flutter/material.dart';
// // // import 'package:pdftron_flutter/pdftron_flutter.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'package:path_provider/path_provider.dart';

// // // Future<void> main() async {
// // //   WidgetsFlutterBinding.ensureInitialized();

// // //   // initialize Pdftron
// // //   await PdftronFlutter.initialize('');

// // //   runApp(const MyApp());
// // // }

// // // class MyApp extends StatelessWidget {
// // //   const MyApp({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return const MaterialApp(home: PdfViewerScreen());
// // //   }
// // // }

// // // class PdfViewerScreen extends StatefulWidget {
// // //   const PdfViewerScreen({super.key});

// // //   @override
// // //   State<PdfViewerScreen> createState() => _PdfViewerScreenState();
// // // }

// // // class _PdfViewerScreenState extends State<PdfViewerScreen> {
// // //   bool _loading = true;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _loadPdf();
// // //   }

// // //   Future<void> _loadPdf() async {
// // //     try {
// // //       // 🔽 Step 1: Download file
// // //       final url =
// // //           "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
// // //       final response = await http.get(Uri.parse(url));

// // //       if (response.statusCode == 200) {
// // //         // 🔽 Step 2: Save to temp dir
// // //         final dir = await getTemporaryDirectory();
// // //         final file = File("${dir.path}/sample.pdf");
// // //         await file.writeAsBytes(response.bodyBytes);

// // //         // 🔽 Step 3: Open with Pdftron
// // //         // await PdftronFlutter.openDocument(file.path);
// // //         await PdftronFlutter.openDocument(
// // //           file.path,
// // //           config: Config()
// // //             ..disabledElements = [
// // //               "toolsButton",
// // //               "searchButton",
// // //               "shareButton",
// // //               "viewControlsButton",
// // //               "thumbnailsButton",
// // //               "listsButton",
// // //               "editPagesButton",
// // //               "moreItemsButton",
// // //             ]
// // //             ..disabledTools = [
// // //               "annotationCreateTextHighlight",
// // //               "stickyTool",
// // //               "eraserTool",
// // //             ]
// // //             ..hideTopToolbars = true
// // //             ..hideBottomToolbar = true
// // //             ..multiTabEnabled = false,
// // //         );
// // //       } else {
// // //         log("Download failed: ${response.statusCode}");
// // //       }
// // //     } catch (e) {
// // //       log("Error loading PDF: $e");
// // //     } finally {
// // //       setState(() => _loading = false);
// // //     }
// // //   }

// // //     Future<void> _addCircleAtTap(Offset localPosition) async {
// // //     // ⚠️ Yeh coordinate screen ka hai, PDF page coordinate nahi
// // //     // Demo ke liye fixed rect use kar rahe hain
// // //     String circleAnnot = """
// // //     <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
// // //       <annots>
// // //         <circle page="1" rect="100,100,200,200" interior-color="#FF0000" color="#FF0000"/>
// // //       </annots>
// // //     </xfdf>
// // //     """;

// // //     await PdftronFlutter.importAnnotationCommand(circleAnnot);
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       body: GestureDetector(
// // //         onTapDown: (details) async {
// // //           await _addCircleAtTap(details.localPosition);
// // //         },
// // //         child: const SizedBox.expand(), // transparent overlay
// // //       ),
// // //     );
// // //   }
// // // }
