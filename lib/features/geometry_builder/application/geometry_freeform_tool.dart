enum GeometryFreeformTool {
  select,
  point,
  line,
  arrow,
  circle,
  angle,
  coordinateAxes,
  numberLine,
}

extension GeometryFreeformToolLabel on GeometryFreeformTool {
  String get label => switch (this) {
    GeometryFreeformTool.select => 'Select',
    GeometryFreeformTool.point => 'Point',
    GeometryFreeformTool.line => 'Line',
    GeometryFreeformTool.arrow => 'Arrow',
    GeometryFreeformTool.circle => 'Circle',
    GeometryFreeformTool.angle => 'Angle',
    GeometryFreeformTool.coordinateAxes => 'Axes',
    GeometryFreeformTool.numberLine => 'Number line',
  };

  String get hint => switch (this) {
    GeometryFreeformTool.select =>
      'Tap an object to select it. Drag points and labels to reposition them.',
    GeometryFreeformTool.point =>
      'Tap anywhere to add a labeled point. Keep tapping to add A, B, C…',
    GeometryFreeformTool.line => 'Drag from one endpoint to the other.',
    GeometryFreeformTool.arrow => 'Drag from the tail to the arrow head.',
    GeometryFreeformTool.circle =>
      'Drag from the centre outward to set the radius.',
    GeometryFreeformTool.angle =>
      'Tap the vertex, then tap one ray point and the second ray point.',
    GeometryFreeformTool.coordinateAxes =>
      'Drag from the origin outward to size x/y coordinate axes.',
    GeometryFreeformTool.numberLine =>
      'Drag from one end of the number line to the other.',
  };
}
