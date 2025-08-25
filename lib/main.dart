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
  Uint8List _clusteredPdf = Uint8List(0);
  bool _isLoading = true;

  /// Raw markers (always preserved)
  final List<Marker> _allMarkers = [];

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      const url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          _originalPdf = res.bodyBytes;
          _clusteredPdf = res.bodyBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      log("Error loading PDF: $e");
      setState(() => _isLoading = false);
    }
  }

  /// Smart clustering logic based on zoom level
  List<Cluster> _makeClusters(List<Marker> markers, double zoom) {
    // Zoom level thresholds for clustering
    if (zoom > 3.0) {
      // Maximum zoom - show all markers individually
      return markers.map((m) => Cluster(m.page, m.position, [m])).toList();
    } else if (zoom > 1.5) {
      // Medium zoom - cluster only very close markers
      final threshold = 20 / zoom;
      return _createClusters(markers, threshold);
    } else {
      // Small zoom - aggressive clustering
      final threshold = 40 / zoom;
      return _createClusters(markers, threshold);
    }
  }

  List<Cluster> _createClusters(List<Marker> markers, double threshold) {
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

      used.addAll(group);

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

  /// Generate PDF with dynamic clustering
  Uint8List _generateClusteredPdf(List<Marker> allMarkers, double zoom) {
    if (allMarkers.isEmpty) return _originalPdf;

    final doc = PdfDocument(inputBytes: _originalPdf);
    final clusters = _makeClusters(allMarkers, zoom);

    for (final cluster in clusters) {
      if (cluster.page > doc.pages.count) continue;
      
      final page = doc.pages[cluster.page - 1];
      
      if (cluster.markers.length == 1) {
        // Single marker - Red circle with number
        _drawSingleMarker(page, cluster.markers.first, allMarkers.indexOf(cluster.markers.first) + 1);
      } else {
        // Cluster - Blue circle with count
        _drawCluster(page, cluster.center, cluster.markers.length);
      }
    }

    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  void _drawSingleMarker(PdfPage page, Marker marker, int index) {
    // Red background circle
    page.graphics.drawEllipse(
      Rect.fromCircle(center: marker.position, radius: 12),
      brush: PdfSolidBrush(PdfColor(220, 0, 0)),
    );
    
    // White border
    page.graphics.drawEllipse(
      Rect.fromCircle(center: marker.position, radius: 12),
      pen: PdfPen(PdfColor(255, 255, 255), width: 2),
    );
    
    // White number
    page.graphics.drawString(
      index.toString(),
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      bounds: Rect.fromCenter(center: marker.position, width: 20, height: 20),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  void _drawCluster(PdfPage page, Offset center, int count) {
    // Blue background circle
    page.graphics.drawEllipse(
      Rect.fromCircle(center: center, radius: 16),
      brush: PdfSolidBrush(PdfColor(0, 0, 220)),
    );
    
    // White border
    page.graphics.drawEllipse(
      Rect.fromCircle(center: center, radius: 16),
      pen: PdfPen(PdfColor(255, 255, 255), width: 2),
    );
    
    // White count
    page.graphics.drawString(
      count.toString(),
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: Rect.fromCenter(center: center, width: 24, height: 24),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  void _updateClustering() {
    final newPdf = _generateClusteredPdf(_allMarkers, _zoom);
    setState(() => _clusteredPdf = newPdf);
  }

  void _addMarker(Offset pdfPos, int pageNum) {
    setState(() {
      _allMarkers.add(Marker(pageNum, pdfPos));
      _updateClustering();
    });
  }

  /// Export final PDF with all individual markers (no clustering)
  Uint8List _exportFinalPdf() {
    final doc = PdfDocument(inputBytes: _originalPdf);
    
    for (var i = 0; i < _allMarkers.length; i++) {
      final marker = _allMarkers[i];
      if (marker.page > doc.pages.count) continue;
      
      final page = doc.pages[marker.page - 1];
      _drawSingleMarker(page, marker, i + 1);
    }
    
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  void _clearAllMarkers() {
    setState(() {
      _allMarkers.clear();
      _clusteredPdf = _originalPdf;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Marker Clustering"),
        backgroundColor: Colors.blue[700],
        actions: [
          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Row(
              children: [
                Text(
                  '${_allMarkers.length} markers',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text(
                  '${_zoom.toStringAsFixed(1)}x',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
          
          // Action buttons
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _allMarkers.isEmpty ? null : () {
              final finalBytes = _exportFinalPdf();
              log("PDF saved with ${_allMarkers.length} markers");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("PDF exported with ${_allMarkers.length} markers"),
                  backgroundColor: Colors.green,
                )
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _updateClustering,
            tooltip: "Refresh Clustering",
          ),
          IconButton(
            icon: Icon(Icons.clear, color: Colors.white),
            onPressed: _allMarkers.isEmpty ? null : _clearAllMarkers,
            tooltip: "Clear All Markers",
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _originalPdf.isEmpty
              ? Center(child: Text("Failed to load PDF", style: TextStyle(fontSize: 18)))
              : SfPdfViewer.memory(
                  _clusteredPdf,
                  controller: _pdfController,
                  onZoomLevelChanged: (details) {
                    setState(() {
                      _zoom = details.newZoomLevel;
                     _updateClustering();  
                    });
                  },
                  onTap: (details) {
                    _addMarker(details.pagePosition, details.pageNumber);
                    setState(() {
                       _updateClustering();  
                    });
                  },
                  pageLayoutMode: PdfPageLayoutMode.single,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                ),
      
      // Floating action button for quick actions
            floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            child: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _pdfController.zoomLevel += 0.5;
          
              });
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            child: const Icon(Icons.remove),
            onPressed: () {
              setState(() {
                _pdfController.zoomLevel -= 0.5;
            
              });
            },
          ),
        ],
      ),
     
    );
  }
}

//  zoom 10 pr muiltples markers with numbers
// import 'dart:typed_data';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:flutter/foundation.dart';

// class MarkerParams {
//   final Uint8List bytes;
//   final Offset point;
//   final int page;
//   final int number;

//   MarkerParams(this.bytes, this.point, this.page, this.number);
// }

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'PDF Marker Demo',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const PDFMarkerScreen(),
//     );
//   }
// }

// class PDFMarkerScreen extends StatefulWidget {
//   const PDFMarkerScreen({super.key});
//   @override
//   State<PDFMarkerScreen> createState() => _PDFMarkerScreenState();
// }

// class _PDFMarkerScreenState extends State<PDFMarkerScreen> {
//   final PdfViewerController _pdfController = PdfViewerController();
//   Uint8List _pdfBytes = Uint8List(0);
//   double _currentZoom = 1.0;
//   int _markerCounter = 1;

//   @override
//   void initState() {
//     super.initState();
//     _loadLocalPdf();
//   }

//   Future<void> _loadLocalPdf() async {
//     final bytes = await rootBundle.load('assets/PDF.pdf');
//     setState(() {
//       _pdfBytes = bytes.buffer.asUint8List();
//     });
//   }

//   static Uint8List processPdfWithMarker(MarkerParams params) {
//     final document = PdfDocument(inputBytes: params.bytes);
//     final page = document.pages[params.page];

//     // Draw red circle
//     page.graphics.drawEllipse(
//       Rect.fromCircle(center: params.point, radius: 12),
//       pen: PdfPen(PdfColor(255, 0, 0), width: 2),
//       brush: PdfSolidBrush(PdfColor(255, 0, 0)),
//     );

//     // Draw white number
//     page.graphics.drawString(
//       params.number.toString(),
//       PdfStandardFont(PdfFontFamily.helvetica, 18),
//       bounds: Rect.fromCenter(center: params.point, width: 24, height: 24),
//       brush: PdfSolidBrush(PdfColor(255, 255, 255)),
//       format: PdfStringFormat(
//         alignment: PdfTextAlignment.center,
//         lineAlignment: PdfVerticalAlignment.middle,
//       ),
//     );

//     final newBytes = document.saveSync();
//     document.dispose();
//     return Uint8List.fromList(newBytes);
//   }

//   Future<void> _addMarker(Offset pdfPoint, int pageNumber) async {
//     if (_pdfBytes.isEmpty) return;

//     final newBytes = await compute(
//       processPdfWithMarker,
//       MarkerParams(_pdfBytes, pdfPoint, pageNumber - 1, _markerCounter),
//     );

//     setState(() {
//       _pdfBytes = newBytes;
//       _markerCounter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("PDF Marker Demo")),
//       body: _pdfBytes.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : SfPdfViewer.memory(
//             maxZoomLevel: 10,
//               _pdfBytes,
//               controller: _pdfController,
//               onZoomLevelChanged: (details) {
//                 setState(() => _currentZoom = details.newZoomLevel);
//               },
//               onTap: (details) {
//                 _addMarker(details.pagePosition, details.pageNumber);
//               },
//             ),
//       floatingActionButton: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           FloatingActionButton(
//             mini: true,
//             child: const Icon(Icons.add),
//             onPressed: () {
//               setState(() {
//                 _pdfController.zoomLevel += 0.5;
//                 _currentZoom = _pdfController.zoomLevel;
//               });
//             },
//           ),
//           const SizedBox(height: 8),
//           FloatingActionButton(
//             mini: true,
//             child: const Icon(Icons.remove),
//             onPressed: () {
//               setState(() {
//                 _pdfController.zoomLevel -= 0.5;
//                 _currentZoom = _pdfController.zoomLevel;
//               });
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

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
