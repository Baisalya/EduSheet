# Fix 7 — Question typing viewport hardening

This patch removes the nested fixed-height scrolling trap in the question composer.

## Problem

A geometry/graph embed is about 200 logical pixels tall while the question editor was fixed to 220 px on compact layouts and 260 px on wider layouts. That left almost no visible typing space after a diagram and created two competing vertical scroll surfaces: the Quill editor and the page.

## Changes

- The Quill question editor now grows with its content and delegates vertical scrolling to the page (`scrollable: false`).
- The editor keeps its previous 220/260 logical-pixel minimum height, so an empty question still has a comfortable writing area.
- Geometry insertion preserves the caret before opening Geometry Builder.
- Geometry is normalized as a block on its own line.
- A real paragraph is always inserted after the geometry block and the caret is moved there, so typing can continue immediately.
- OCR insertion also preserves its original caret across the route transition.
- Added a widget regression test that prevents the nested-scroll architecture from returning.

## Intended UX

Type question → insert graph/geometry → return to question → caret is directly after the graph → continue typing. The whole question card/page scrolls naturally instead of a small editor viewport hiding the current line.
