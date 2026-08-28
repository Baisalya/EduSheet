import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/data/services/presentation_parser_service.dart';
import 'package:edusheet/features/document_reader/domain/models/presentation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PPTX parser keeps slide order, layout text and transition metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'edusheet-pptx-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}sample.pptx',
      );

      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'ppt/presentation.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <p:sldIdLst><p:sldId id="256" r:id="rId2"/><p:sldId id="257" r:id="rId1"/></p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'ppt/_rels/presentation.xml.rels',
            '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Target="slides/slide1.xml"/>
 <Relationship Id="rId2" Target="slides/slide2.xml"/>
</Relationships>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'ppt/slides/slide2.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree>
  <p:sp><p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="3000000" cy="800000"/></a:xfrm></p:spPr>
   <p:txBody><a:p><a:r><a:t>First by relationship</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
</p:sld>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'ppt/slides/slide1.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree>
  <p:sp><p:spPr><a:xfrm><a:off x="1219200" y="685800"/><a:ext cx="6096000" cy="1371600"/></a:xfrm></p:spPr>
   <p:txBody><a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="3200" b="1"><a:solidFill><a:srgbClr val="112233"/></a:solidFill></a:rPr><a:t>Hello class</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
 <p:transition spd="fast"><p:fade/></p:transition>
 <p:timing/>
</p:sld>''',
          ),
        );
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final presentation = await PresentationParserService().load(file);
      final slide = presentation.slides.first;
      final secondSlide = presentation.slides[1];
      final element = secondSlide.elements.single;

      expect(presentation.aspectRatio, closeTo(16 / 9, 0.01));
      expect(presentation.slides.length, 2);
      expect(slide.elements.single.text, 'First by relationship');
      expect(slide.number, 1);
      expect(secondSlide.number, 2);
      expect(secondSlide.transition.kind, PresentationTransitionKind.fade);
      expect(secondSlide.hasNativeAnimations, isTrue);
      expect(element.text, 'Hello class');
      expect(element.hasBounds, isTrue);
      expect(element.left, closeTo(0.1, 0.001));
      expect(element.fontSizePoints, 32);
      expect(element.bold, isTrue);
      expect(element.alignment, 'ctr');
    },
  );
}
