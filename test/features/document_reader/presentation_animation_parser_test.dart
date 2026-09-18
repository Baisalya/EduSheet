import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/data/services/presentation_parser_service.dart';
import 'package:edusheet/features/document_reader/domain/models/presentation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses object ids and common PowerPoint animation timing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edusheet-pptx-animation-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}animations.pptx',
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'ppt/presentation.xml',
          '''<?xml version="1.0"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/_rels/presentation.xml.rels',
          '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slides/slide1.xml',
          '''<?xml version="1.0"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
   <p:spPr><a:xfrm><a:off x="100000" y="100000"/><a:ext cx="3000000" cy="600000"/></a:xfrm></p:spPr>
   <p:txBody><a:p><a:r><a:t>Animated title</a:t></a:r></a:p></p:txBody>
  </p:sp>
  <p:sp>
   <p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
   <p:spPr><a:xfrm><a:off x="100000" y="900000"/><a:ext cx="3000000" cy="600000"/></a:xfrm></p:spPr>
   <p:txBody><a:p><a:r><a:t>Animated body</a:t></a:r></a:p></p:txBody>
  </p:sp>
 </p:spTree></p:cSld>
 <p:timing><p:tnLst><p:par><p:cTn id="1"><p:childTnLst>
  <p:par><p:cTn id="2" nodeType="clickEffect" presetClass="entr"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>
   <p:set><p:cBhvr><p:cTn id="20" dur="1"/><p:tgtEl><p:spTgt spid="2"/></p:tgtEl></p:cBhvr><p:to><p:strVal val="visible"/></p:to></p:set>
   <p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="3" dur="500"/><p:tgtEl><p:spTgt spid="2"/></p:tgtEl></p:cBhvr></p:animEffect>
  </p:childTnLst></p:cTn></p:par>
  <p:par><p:cTn id="4" nodeType="withEffect" presetClass="emph"><p:stCondLst><p:cond delay="100"/></p:stCondLst><p:childTnLst>
   <p:animScale><p:cBhvr><p:cTn id="5" dur="300"/><p:tgtEl><p:spTgt spid="3"/></p:tgtEl></p:cBhvr><p:by x="125000" y="125000"/></p:animScale>
  </p:childTnLst></p:cTn></p:par>
  <p:par><p:cTn id="6" nodeType="afterEffect" presetClass="exit"><p:stCondLst><p:cond delay="50"/></p:stCondLst><p:childTnLst>
   <p:animEffect transition="out" filter="wipe(left)"><p:cBhvr><p:cTn id="7" dur="200"/><p:tgtEl><p:spTgt spid="2"/></p:tgtEl></p:cBhvr></p:animEffect>
  </p:childTnLst></p:cTn></p:par>
 </p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>
</p:sld>''',
        ),
      );

    await file.writeAsBytes(ZipEncoder().encode(archive));
    final presentation = await PresentationParserService().load(file);
    final slide = presentation.slides.single;

    expect(slide.hasNativeAnimations, isTrue);
    expect(slide.elements.map((element) => element.objectId), containsAll(['2', '3']));
    expect(slide.animations, hasLength(3));

    final fade = slide.animations[0];
    expect(fade.targetObjectId, '2');
    expect(fade.kind, PresentationAnimationKind.fadeIn);
    expect(fade.trigger, PresentationAnimationTrigger.onClick);
    expect(fade.duration.inMilliseconds, 500);

    final emphasis = slide.animations[1];
    expect(emphasis.targetObjectId, '3');
    expect(emphasis.kind, PresentationAnimationKind.growShrink);
    expect(emphasis.trigger, PresentationAnimationTrigger.withPrevious);
    expect(emphasis.delay.inMilliseconds, 100);
    expect(emphasis.magnitude, closeTo(1.25, 0.001));

    final exit = slide.animations[2];
    expect(exit.targetObjectId, '2');
    expect(exit.kind, PresentationAnimationKind.wipeOut);
    expect(exit.trigger, PresentationAnimationTrigger.afterPrevious);
    expect(exit.delay.inMilliseconds, 50);
    expect(exit.direction, 'l');
  });
}
