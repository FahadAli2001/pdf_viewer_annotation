// ------ loading code 

import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MarkerParams {
  final Uint8List bytes;
  final Offset point;
  final int page;
  MarkerParams(this.bytes, this.point, this.page);
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
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  Uint8List _pdfBytes = Uint8List(0);

  Future<void> _loadPdfFromNetwork() async {
    const url =
        "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        _pdfBytes = response.bodyBytes;
      });
    } else {
      throw Exception("PDF load failed");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPdfFromNetwork();
  }

  // yeh function compute isolate me chalega
  static Uint8List processPdfWithMarker(MarkerParams params) {
    final document = PdfDocument(inputBytes: params.bytes);
    final page = document.pages[params.page];
    page.graphics.drawEllipse(
      Rect.fromCircle(center: params.point, radius: 10),
      pen: PdfPen(PdfColor(255, 0, 0), width: 2),
      brush: PdfSolidBrush(PdfColor(255, 0, 0)),
    );
    final newBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(newBytes);
  }

  Future<void> _addMarker(Offset pdfPoint, int pageNumber) async {
    if (_pdfBytes.isEmpty) return;

    try {
      final Uint8List newBytes = await compute(
        processPdfWithMarker,
        MarkerParams(_pdfBytes, pdfPoint, pageNumber - 1),
      );
      if (mounted) {
        setState(() {
          _pdfBytes = newBytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add marker: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Network PDF Marker")),
      body: _pdfBytes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SfPdfViewer.memory(
              _pdfBytes,
              key: _pdfViewerKey,
              onTap: (PdfGestureDetails details) {
                final pageNumber = details.pageNumber;
                final Offset pdfPoint = details.pagePosition;
                _addMarker(pdfPoint, pageNumber);
              },
            ),
    );
  }
}



// text embeded

// import 'dart:typed_data';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';

// class MarkerParams {
//   final Uint8List bytes;
//   final Offset point;
//   final int page;
//   final int number;
//   final double zoomLevel;

//   MarkerParams(this.bytes, this.point, this.page, this.number, this.zoomLevel);
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

//   Future<void> _loadPdfFromNetwork() async {
//     const url =
//         "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       setState(() => _pdfBytes = response.bodyBytes);
//     } else {
//       throw Exception("PDF load failed");
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadPdfFromNetwork();
//   }

//   static Uint8List processPdfWithMarker(MarkerParams params) {
//     final document = PdfDocument(inputBytes: params.bytes);
//     final page = document.pages[params.page];

//     // Draw red circle
//     page.graphics.drawEllipse(
//       Rect.fromCircle(center: params.point, radius: 10),
//       pen: PdfPen(PdfColor(255, 0, 0), width: 2),
//       brush: PdfSolidBrush(PdfColor(255, 0, 0)),
//     );

//     // Draw white text (larger and properly positioned)

//     page.graphics.drawString(
//       params.number.toString(),
//       PdfStandardFont(PdfFontFamily.helvetica, 14), // Increased font size
//       bounds: Rect.fromCenter(
//         center: params.point,
//         width: 20, // Increased width
//         height: 20, // Increased height
//       ),
//       brush: PdfSolidBrush(PdfColor(255, 255, 255)), // White text
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

//     try {
//       final Uint8List newBytes = await compute(
//         processPdfWithMarker,
//         MarkerParams(_pdfBytes, pdfPoint, pageNumber - 1, 9, _currentZoom),
//       );

//       setState(() => _pdfBytes = newBytes);
//     } catch (e) {
//       if (mounted) {
//         log('Error adding marker: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("PDF Marker with Zoom")),
//       body: SfPdfViewer.memory(
//         _pdfBytes,
//         controller: _pdfController,
//         onZoomLevelChanged: (PdfZoomDetails details) {
//           setState(() => _currentZoom = details.newZoomLevel);
//           log("deatils zoom ${details.newZoomLevel}");
//         },
//         onTap: (PdfGestureDetails details) {
//           _addMarker(details.pagePosition, details.pageNumber);
//         },
//       ),
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
//               log(_currentZoom.toString());
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


// // // message icon

// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:http/http.dart' as http;

// void main() => runApp(const MyApp());

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) => MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: const PDFMarkerScreen(),
//   );
// }

// class PDFMarkerScreen extends StatefulWidget {
//   const PDFMarkerScreen({super.key});
//   @override
//   State<PDFMarkerScreen> createState() => _PDFMarkerScreenState();
// }

// class _PDFMarkerScreenState extends State<PDFMarkerScreen> {
//   final PdfViewerController _pdfController = PdfViewerController();
//   Uint8List _pdfBytes = Uint8List(0);

//   Future<void> _loadPdfFromNetwork() async {
//     const url =
//         "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       setState(() => _pdfBytes = response.bodyBytes);
//     } else {
//       throw Exception('PDF load failed');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadPdfFromNetwork();
//   }

 

//   void _addStickyNote(Offset pdfPoint, int pageNumber) {
    
//     _pdfController.addAnnotation(
     
//       StickyNoteAnnotation(
//         pageNumber: pageNumber,
//         position: pdfPoint,
//         icon: PdfStickyNoteIcon.insert,
//         text: '',
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('PDF Marker via Sticky Note')),
//       body: _pdfBytes.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : SfPdfViewer.memory(
//               _pdfBytes,
//               controller: _pdfController,
//               onTap: (PdfGestureDetails details) {
//                 _addStickyNote(details.pagePosition, details.pageNumber);
                
       
//               },
//             ),
//     );
//   }
// }

