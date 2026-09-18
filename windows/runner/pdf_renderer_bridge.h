#ifndef RUNNER_PDF_RENDERER_BRIDGE_H_
#define RUNNER_PDF_RENDERER_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Native Windows.Data.Pdf renderer used by PDF -> Word Preserve Appearance.
// It mirrors Android's edusheet/pdf_renderer channel and returns one PNG path
// per PDF page so the Dart converter can keep a single cross-platform flow.
class PdfRendererBridge {
 public:
  explicit PdfRendererBridge(flutter::BinaryMessenger* messenger);
  ~PdfRendererBridge();

  PdfRendererBridge(const PdfRendererBridge&) = delete;
  PdfRendererBridge& operator=(const PdfRendererBridge&) = delete;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_PDF_RENDERER_BRIDGE_H_
