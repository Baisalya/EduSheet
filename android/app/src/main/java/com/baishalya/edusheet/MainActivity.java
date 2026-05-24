package com.baishalya.edusheet;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String DOCUMENT_CHANNEL = "edusheet/document_intents";
    private static final String PDF_RENDERER_CHANNEL = "edusheet/pdf_renderer";
    private MethodChannel documentChannel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        documentChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DOCUMENT_CHANNEL);
        documentChannel
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "getInitialDocument":
                            try {
                                result.success(resolveIncomingDocument(getIntent()));
                            } catch (Exception exception) {
                                result.error("OPEN_FAILED", exception.getMessage(), null);
                            }
                            return;
                        case "copyContentUriToCache":
                            String uriString = call.argument("uri");
                            if (uriString == null || uriString.isEmpty()) {
                                result.error("INVALID_URI", "Document URI is empty.", null);
                                return;
                            }

                            try {
                                result.success(copyContentUriToCache(uriString));
                            } catch (Exception exception) {
                                result.error("COPY_FAILED", exception.getMessage(), null);
                            }
                            return;
                        default:
                            result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PDF_RENDERER_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (!"renderPagesToImages".equals(call.method)) {
                        result.notImplemented();
                        return;
                    }

                    String pdfPath = call.argument("pdfPath");
                    Integer scale = call.argument("scale");
                    if (pdfPath == null || pdfPath.isEmpty()) {
                        result.error("INVALID_PATH", "PDF path is empty.", null);
                        return;
                    }

                    try {
                        result.success(renderPdfPagesToImages(pdfPath, scale == null ? 2 : scale));
                    } catch (Exception exception) {
                        result.error("RENDER_FAILED", exception.getMessage(), null);
                    }
                });
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        sendIncomingDocument(intent);
    }

    private void sendIncomingDocument(Intent intent) {
        if (documentChannel == null) return;

        try {
            Map<String, Object> document = resolveIncomingDocument(intent);
            if (document != null) {
                documentChannel.invokeMethod("openDocument", document);
            }
        } catch (Exception exception) {
            Map<String, Object> error = new HashMap<>();
            error.put("message", exception.getMessage() == null
                    ? "Unable to open the selected document."
                    : exception.getMessage());
            documentChannel.invokeMethod("openDocumentError", error);
        }
    }

    private Map<String, Object> resolveIncomingDocument(Intent intent) throws IOException {
        if (intent == null) return null;

        final int historyFlag = Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY;
        if ((intent.getFlags() & historyFlag) == historyFlag) {
            return null;
        }

        Uri uri = incomingDocumentUri(intent);
        if (uri == null) return null;

        String path;
        if ("file".equalsIgnoreCase(uri.getScheme())) {
            path = uri.getPath();
        } else if ("content".equalsIgnoreCase(uri.getScheme())) {
            path = copyContentUriToCache(uri.toString());
        } else {
            throw new IOException("Unsupported document URI.");
        }

        if (path == null || path.trim().isEmpty()) {
            throw new IOException("Unable to resolve the selected document.");
        }

        Map<String, Object> document = new HashMap<>();
        document.put("path", path);
        document.put("uri", uri.toString());
        String mimeType = getContentResolver().getType(uri);
        if (mimeType != null) document.put("mimeType", mimeType);
        return document;
    }

    private Uri incomingDocumentUri(Intent intent) {
        String action = intent.getAction();
        if (Intent.ACTION_VIEW.equals(action)) {
            return intent.getData();
        }

        if (Intent.ACTION_SEND.equals(action)) {
            Object stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            return stream instanceof Uri ? (Uri) stream : null;
        }

        return null;
    }

    private String copyContentUriToCache(String uriString) throws IOException {
        Uri uri = Uri.parse(uriString);
        ContentResolver resolver = getContentResolver();
        String displayName = getDisplayName(resolver, uri);

        if (displayName == null || displayName.trim().isEmpty()) {
            displayName = "shared_document" + getExtensionForUri(resolver, uri);
        } else if (!displayName.contains(".")) {
            displayName = displayName + getExtensionForUri(resolver, uri);
        }

        File cacheDir = new File(getCacheDir(), "incoming_documents");
        if (!cacheDir.exists() && !cacheDir.mkdirs()) {
            throw new IOException("Unable to create document cache.");
        }

        File destination = uniqueFile(cacheDir, sanitizeFileName(displayName));
        try (InputStream inputStream = resolver.openInputStream(uri);
             FileOutputStream outputStream = new FileOutputStream(destination)) {
            if (inputStream == null) {
                throw new IOException("Unable to open incoming document.");
            }

            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
        }

        return destination.getAbsolutePath();
    }

    private String getDisplayName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (nameIndex >= 0) {
                    return cursor.getString(nameIndex);
                }
            }
        } catch (Exception ignored) {
        }

        String lastPathSegment = uri.getLastPathSegment();
        if (lastPathSegment == null) return null;
        int slashIndex = lastPathSegment.lastIndexOf('/');
        return slashIndex >= 0 ? lastPathSegment.substring(slashIndex + 1) : lastPathSegment;
    }

    private String getExtensionForUri(ContentResolver resolver, Uri uri) {
        String mimeType = resolver.getType(uri);
        if (mimeType == null) return "";

        switch (mimeType) {
            case "application/pdf":
                return ".pdf";
            case "application/msword":
                return ".doc";
            case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
                return ".docx";
            case "application/rtf":
            case "text/rtf":
                return ".rtf";
            case "application/vnd.oasis.opendocument.text":
                return ".odt";
            case "application/vnd.ms-excel":
                return ".xls";
            case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
                return ".xlsx";
            case "text/csv":
            case "application/csv":
                return ".csv";
            case "application/vnd.oasis.opendocument.spreadsheet":
                return ".ods";
            case "application/vnd.ms-powerpoint":
                return ".ppt";
            case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
                return ".pptx";
            case "application/vnd.oasis.opendocument.presentation":
                return ".odp";
            case "text/plain":
                return ".txt";
            default:
                String extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType);
                return extension == null ? "" : "." + extension.toLowerCase(Locale.US);
        }
    }

    private File uniqueFile(File directory, String fileName) throws IOException {
        File destination = new File(directory, fileName);
        String canonicalDirectory = directory.getCanonicalPath();
        String canonicalDestination = destination.getCanonicalPath();
        if (!canonicalDestination.startsWith(canonicalDirectory + File.separator)) {
            throw new IOException("Invalid document file name.");
        }

        if (!destination.exists()) return destination;

        int dotIndex = fileName.lastIndexOf('.');
        String baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
        String extension = dotIndex > 0 ? fileName.substring(dotIndex) : "";
        return new File(directory, baseName + "_" + System.currentTimeMillis() + extension);
    }

    private String sanitizeFileName(String fileName) {
        String sanitized = fileName.replaceAll("[\\\\/:*?\"<>|]", "_").trim();
        return sanitized.isEmpty() ? "shared_document" : sanitized;
    }

    private List<String> renderPdfPagesToImages(String pdfPath, int scale) throws IOException {
        File source = new File(pdfPath);
        if (!source.exists()) {
            throw new IOException("PDF file does not exist.");
        }

        int safeScale = Math.max(1, Math.min(scale, 3));
        File outputDir = new File(getCacheDir(), "pdf_ocr_pages");
        if (!outputDir.exists() && !outputDir.mkdirs()) {
            throw new IOException("Unable to create OCR page cache.");
        }

        File runDir = new File(outputDir, String.valueOf(System.currentTimeMillis()));
        if (!runDir.exists() && !runDir.mkdirs()) {
            throw new IOException("Unable to create OCR run cache.");
        }

        List<String> paths = new ArrayList<>();
        try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY);
             PdfRenderer renderer = new PdfRenderer(descriptor)) {
            for (int pageIndex = 0; pageIndex < renderer.getPageCount(); pageIndex++) {
                try (PdfRenderer.Page page = renderer.openPage(pageIndex)) {
                    int width = page.getWidth() * safeScale;
                    int height = page.getHeight() * safeScale;
                    Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                    Canvas canvas = new Canvas(bitmap);
                    canvas.drawColor(Color.WHITE);
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);

                    File imageFile = new File(runDir, String.format(Locale.US, "page_%04d.png", pageIndex + 1));
                    try (FileOutputStream outputStream = new FileOutputStream(imageFile)) {
                        if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)) {
                            throw new IOException("Unable to save rendered PDF page.");
                        }
                    } finally {
                        bitmap.recycle();
                    }
                    paths.add(imageFile.getAbsolutePath());
                }
            }
        }

        return paths;
    }
}
