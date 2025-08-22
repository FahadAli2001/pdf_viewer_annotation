import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Marker model
class Marker {
  final int page;
  final Offset position;
  Marker(this.page, this.position);
}

/// Cluster model
class Cluster {
  final int page;
  final Offset center;
  final List<Marker> markers;
  Cluster(this.page, this.center, this.markers);
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PDFClusterDemo(),
    );
  }
}

class PDFClusterDemo extends StatefulWidget {
  const PDFClusterDemo({super.key});

  @override
  State<PDFClusterDemo> createState() => _PDFClusterDemoState();
}

class _PDFClusterDemoState extends State<PDFClusterDemo> {
  final PdfViewerController _pdfController = PdfViewerController();
  double _zoom = 1.0;
  Uint8List _originalPdf = Uint8List(0);
  Uint8List _renderedPdf = Uint8List(0);

  /// Raw markers (always preserved)
  final List<Marker> _allMarkers = [];

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    const url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      setState(() {
        _originalPdf = res.bodyBytes;
        _renderedPdf = res.bodyBytes;
      });
    }
  }

  /// Clustering logic (dynamic based on zoom)
  List<Cluster> _makeClusters(List<Marker> markers, double zoom) {
    // High zoom par individual markers dikhao
    if (zoom > 2.5) {
      return markers.map((m) => Cluster(m.page, m.position, [m])).toList();
    }

    // Normal zoom par clustering karo
    final threshold = 50 / zoom;
    final List<Cluster> clusters = [];
    final used = <Marker>{};

    for (final m in markers) {
      if (used.contains(m)) continue;

      final group = <Marker>[m];
      for (final other in markers) {
        if (other == m || used.contains(other)) continue;
        if ((other.position - m.position).distance <= threshold && other.page == m.page) {
          group.add(other);
        }
      }

      for (final g in group) {
        used.add(g);
      }

      if (group.length == 1) {
        clusters.add(Cluster(m.page, m.position, group));
      } else {
        final dx = group.map((e) => e.position.dx).reduce((a, b) => a + b) / group.length;
        final dy = group.map((e) => e.position.dy).reduce((a, b) => a + b) / group.length;
        clusters.add(Cluster(m.page, Offset(dx, dy), group));
      }
    }
    return clusters;
  }

  /// Generate PDF with custom shapes for markers and clusters
  Uint8List _generatePdfWithCustomShapes(Uint8List baseBytes, List<Marker> allMarkers, double zoom) {
    final doc = PdfDocument(inputBytes: baseBytes);
    final clusters = _makeClusters(allMarkers, zoom);

    for (final cluster in clusters) {
      final page = doc.pages[cluster.page - 1];
      
      if (cluster.markers.length == 1) {
        // Single marker → Red circle with white number
        final marker = cluster.markers.first;
        final markerIndex = allMarkers.indexOf(marker) + 1;
        
        // Red circle
        page.graphics.drawEllipse(
          Rect.fromCircle(center: marker.position, radius: 12),
          pen: PdfPen(PdfColor(255, 0, 0), width: 2),
          brush: PdfSolidBrush(PdfColor(255, 0, 0)),
        );
        
        // White number text
        page.graphics.drawString(
          markerIndex.toString(),
          PdfStandardFont(PdfFontFamily.helvetica, 10),
          bounds: Rect.fromCenter(
            center: marker.position, 
            width: 20, 
            height: 20
          ),
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );

      } else {
        // Cluster → Blue circle with white count
        // Blue circle
        page.graphics.drawEllipse(
          Rect.fromCircle(center: cluster.center, radius: 16),
          pen: PdfPen(PdfColor(0, 0, 255), width: 2),
          brush: PdfSolidBrush(PdfColor(0, 0, 255)),
        );
        
        // White count text
        page.graphics.drawString(
          cluster.markers.length.toString(),
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: Rect.fromCenter(
            center: cluster.center, 
            width: 24, 
            height: 24
          ),
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }
    }

    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  void _refreshPdf() {
    final newBytes = _generatePdfWithCustomShapes(_originalPdf, _allMarkers, _zoom);
    setState(() {
      _renderedPdf = newBytes;
    });
  }

  void _addMarker(Offset pdfPos, int pageNum) {
    setState(() {
      _allMarkers.add(Marker(pageNum, pdfPos));
      _refreshPdf();
    });
  }

  /// Final save with all markers individually (no clustering)
  Uint8List _exportFinalPdf() {
    final doc = PdfDocument(inputBytes: _originalPdf);
    
    for (var i = 0; i < _allMarkers.length; i++) {
      final marker = _allMarkers[i];
      final page = doc.pages[marker.page - 1];
      
      // Red circle
      page.graphics.drawEllipse(
        Rect.fromCircle(center: marker.position, radius: 10),
        pen: PdfPen(PdfColor(200, 0, 0), width: 2),
        brush: PdfSolidBrush(PdfColor(200, 0, 0)),
      );
      
      // White number
      page.graphics.drawString(
        (i + 1).toString(),
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        bounds: Rect.fromCenter(
          center: marker.position, 
          width: 18, 
          height: 18
        ),
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
    }
    
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Markers with Custom Shapes"),
        actions: [
          // Zoom level display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Text(
              'Zoom: ${_zoom.toStringAsFixed(1)}x',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final finalBytes = _exportFinalPdf();
              log("✅ Final PDF saved with ${_allMarkers.length} markers");
              // Yahan aap PDF save/share kar sakte hain
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("PDF saved with ${_allMarkers.length} markers"))
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPdf,
            tooltip: "Refresh Clusters",
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _allMarkers.clear();
                _renderedPdf = _originalPdf;
              });
            },
            tooltip: "Clear All Markers",
          ),
        ],
      ),
      body: _originalPdf.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info panel
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Markers: ${_allMarkers.length}"),
                      Text("Zoom: ${_zoom.toStringAsFixed(1)}x"),
                      Text("Page: ${_pdfController.pageNumber}"),
                    ],
                  ),
                ),
                // PDF Viewer
                Expanded(
                  child: SfPdfViewer.memory(
                    _renderedPdf,
                    controller: _pdfController,
                    onZoomLevelChanged: (details) {
                      setState(() {
                        _zoom = details.newZoomLevel;
                        _refreshPdf(); // Auto-refresh on zoom
                      });
                    },
                    onPageChanged: (details) {
                      setState(() {
                        // Page change par bhi refresh kar sakte hain
                      });
                    },
                    onTap: (details) {
                      _addMarker(details.pagePosition, details.pageNumber);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
// ----------

// import 'dart:developer';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// /// Marker model
// class Marker {
//   final int page;
//   final Offset position;
//   Marker(this.page, this.position);
// }

// /// Cluster model
// class Cluster {
//   final int page;
//   final Offset center;
//   final List<Marker> markers;
//   Cluster(this.page, this.center, this.markers);
// }

// void main() => runApp(const MyApp());

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: PDFClusterDemo(),
//     );
//   }
// }

// class PDFClusterDemo extends StatefulWidget {
//   const PDFClusterDemo({super.key});

//   @override
//   State<PDFClusterDemo> createState() => _PDFClusterDemoState();
// }

// class _PDFClusterDemoState extends State<PDFClusterDemo> {
//   final PdfViewerController _pdfController = PdfViewerController();
//   double _zoom = 1.0;
//   Uint8List _originalPdf = Uint8List(0);
//   Uint8List _renderedPdf = Uint8List(0);

//   /// Raw markers (always preserved)
//   final List<Marker> _allMarkers = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadPdf();
//   }

//   Future<void> _loadPdf() async {
//     const url =
//         "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
//     final res = await http.get(Uri.parse(url));
//     if (res.statusCode == 200) {
//       setState(() {
//         _originalPdf = res.bodyBytes;
//         _renderedPdf = res.bodyBytes;
//       });
//     }
//   }

//   /// Clustering logic
//   List<Cluster> _makeClusters(List<Marker> markers, double zoom) {
//     const baseThreshold = 30.0; // px distance
//     final threshold = baseThreshold / zoom;

//     final List<Cluster> clusters = [];
//     final used = <Marker>{};

//     for (final m in markers) {
//       if (used.contains(m)) continue;

//       final group = <Marker>[m];
//       for (final other in markers) {
//         if (other == m || used.contains(other)) continue;
//         if ((other.position - m.position).distance <= threshold &&
//             other.page == m.page) {
//           group.add(other);
//         }
//       }
//       for (final g in group) {
//         used.add(g);
//       }

//       // Average center
//       final dx =
//           group.map((e) => e.position.dx).reduce((a, b) => a + b) /
//           group.length;
//       final dy =
//           group.map((e) => e.position.dy).reduce((a, b) => a + b) /
//           group.length;
//       clusters.add(Cluster(m.page, Offset(dx, dy), group));
//     }
//     return clusters;
//   }

//   /// Generate clustered PDF (always embedded, no overlay)
//   Uint8List _generatePdfWithClusters(
//     Uint8List baseBytes,
//     List<Marker> all,
//     double zoom,
//   ) {
//     final doc = PdfDocument(inputBytes: baseBytes);

//     final clusters = _makeClusters(all, zoom);

//     for (final c in clusters) {
//       final page = doc.pages[c.page - 1];
//       if (c.markers.length == 1) {
//         // Single marker → draw circle with number
//         final m = c.markers.first;
//         page.graphics.drawEllipse(
//           Rect.fromCircle(center: m.position, radius: 10),
//           pen: PdfPen(PdfColor(255, 0, 0), width: 2),
//           brush: PdfSolidBrush(PdfColor(255, 0, 0)),
//         );
//         page.graphics.drawString(
//           (_allMarkers.indexOf(m) + 1).toString(),
//           PdfStandardFont(PdfFontFamily.helvetica, 12),
//           bounds: Rect.fromCenter(center: m.position, width: 20, height: 20),
//           brush: PdfSolidBrush(PdfColor(255, 255, 255)),
//           format: PdfStringFormat(
//             alignment: PdfTextAlignment.center,
//             lineAlignment: PdfVerticalAlignment.middle,
//           ),
//         );
//       } else {
//         // Cluster → blue circle with count
//         page.graphics.drawEllipse(
//           Rect.fromCircle(center: c.center, radius: 14),
//           pen: PdfPen(PdfColor(0, 0, 255), width: 2),
//           brush: PdfSolidBrush(PdfColor(0, 0, 255)),
//         );
//         page.graphics.drawString(
//           c.markers.length.toString(),
//           PdfStandardFont(PdfFontFamily.helvetica, 12),
//           bounds: Rect.fromCenter(center: c.center, width: 24, height: 24),
//           brush: PdfSolidBrush(PdfColor(255, 255, 255)),
//           format: PdfStringFormat(
//             alignment: PdfTextAlignment.center,
//             lineAlignment: PdfVerticalAlignment.middle,
//           ),
//         );
//       }
//     }

//     final bytes = doc.saveSync();
//     doc.dispose();
//     return Uint8List.fromList(bytes);
//   }

//   void _refreshPdf() {
//     final newBytes = _generatePdfWithClusters(_originalPdf, _allMarkers, _zoom);
//     setState(() {
//       _renderedPdf = newBytes;
//     });
//   }

//   void _addMarker(Offset pdfPos, int pageNum) {
//     _allMarkers.add(Marker(pageNum, pdfPos));
//     _refreshPdf();
//   }

//   /// Final save with all markers individually
//   Uint8List _exportFinalPdf() {
//     final doc = PdfDocument(inputBytes: _originalPdf);
//     for (var i = 0; i < _allMarkers.length; i++) {
//       final m = _allMarkers[i];
//       final page = doc.pages[m.page - 1];
//       page.graphics.drawEllipse(
//         Rect.fromCircle(center: m.position, radius: 10),
//         pen: PdfPen(PdfColor(200, 0, 0), width: 2),
//         brush: PdfSolidBrush(PdfColor(200, 0, 0)),
//       );
//       page.graphics.drawString(
//         (i + 1).toString(),
//         PdfStandardFont(PdfFontFamily.helvetica, 12),
//         bounds: Rect.fromCenter(center: m.position, width: 20, height: 20),
//         brush: PdfSolidBrush(PdfColor(255, 255, 255)),
//         format: PdfStringFormat(
//           alignment: PdfTextAlignment.center,
//           lineAlignment: PdfVerticalAlignment.middle,
//         ),
//       );
//     }
//     final bytes = doc.saveSync();
//     doc.dispose();
//     return Uint8List.fromList(bytes);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Clustered PDF Markers"),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.save),
//             onPressed: () {
//               final finalBytes = _exportFinalPdf();
//               log("✅ Final PDF saved with ${_allMarkers.length} markers");
//             },
//           ),
//         ],
//       ),
//       body: _renderedPdf.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : SfPdfViewer.memory(
//               _renderedPdf,
//               controller: _pdfController,
//               onZoomLevelChanged: (details) {
//                 setState(() => _zoom = details.newZoomLevel);
//               },
//               onTap: (details) {
//                 _addMarker(details.pagePosition, details.pageNumber);
//               },
//             ),
//     );
//   }
// }

// // ------- pdf tron -----
// import 'dart:developer';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:pdftron_flutter/pdftron_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // initialize Pdftron
//   await PdftronFlutter.initialize('');

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(home: PdfViewerScreen());
//   }
// }

// class PdfViewerScreen extends StatefulWidget {
//   const PdfViewerScreen({super.key});

//   @override
//   State<PdfViewerScreen> createState() => _PdfViewerScreenState();
// }

// class _PdfViewerScreenState extends State<PdfViewerScreen> {
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadPdf();
//   }

//   Future<void> _loadPdf() async {
//     try {
//       // 🔽 Step 1: Download file
//       final url =
//           "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
//       final response = await http.get(Uri.parse(url));

//       if (response.statusCode == 200) {
//         // 🔽 Step 2: Save to temp dir
//         final dir = await getTemporaryDirectory();
//         final file = File("${dir.path}/sample.pdf");
//         await file.writeAsBytes(response.bodyBytes);

//         // 🔽 Step 3: Open with Pdftron
//         // await PdftronFlutter.openDocument(file.path);
//         await PdftronFlutter.openDocument(
//           file.path,
//           config: Config()
//             ..disabledElements = [
//               "toolsButton",
//               "searchButton",
//               "shareButton",
//               "viewControlsButton",
//               "thumbnailsButton",
//               "listsButton",
//               "editPagesButton",
//               "moreItemsButton",
//             ]
//             ..disabledTools = [
//               "annotationCreateTextHighlight",
//               "stickyTool",
//               "eraserTool",
//             ]
//             ..hideTopToolbars = true
//             ..hideBottomToolbar = true
//             ..multiTabEnabled = false,
//         );
//       } else {
//         log("Download failed: ${response.statusCode}");
//       }
//     } catch (e) {
//       log("Error loading PDF: $e");
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//     Future<void> _addCircleAtTap(Offset localPosition) async {
//     // ⚠️ Yeh coordinate screen ka hai, PDF page coordinate nahi
//     // Demo ke liye fixed rect use kar rahe hain
//     String circleAnnot = """
//     <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
//       <annots>
//         <circle page="1" rect="100,100,200,200" interior-color="#FF0000" color="#FF0000"/>
//       </annots>
//     </xfdf>
//     """;

//     await PdftronFlutter.importAnnotationCommand(circleAnnot);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GestureDetector(
//         onTapDown: (details) async {
//           await _addCircleAtTap(details.localPosition);
//         },
//         child: const SizedBox.expand(), // transparent overlay
//       ),
//     );
//   }
// }
