# Step 6 — Final Integration & Release QA

This phase does not introduce another authoring model or persistence schema. It
locks the Universal Smart Paper Editor delivered in Steps 1–5 behind focused
integration gates that exercise the product as a teacher would actually use it.

## Release gates added

1. **Paper compatibility**
   - Full Step 1–5 paper is encoded to JSON and decoded again.
   - Section structure, option layout, advanced metadata, tables, attachments,
     sub-questions, internal OR choices and unrelated legacy metadata must
     survive unchanged.
   - Pre-refactor MCQ / descriptive / fill-in-the-blank payloads must still open.

2. **Question Bank round-trip**
   - An advanced reusable question is written through the real local Question
     Bank repository and loaded again.
   - Stimulus, word bank, answer space, table, attachment metadata, parts, OR
     choices, option layout and teaching metadata must remain intact.

3. **Preview / PDF / Word semantic parity**
   - The same complex paper is rendered in the on-screen preview, exported to
     DOCX, and exported to PDF.
   - A shared set of semantic markers must appear in all three outputs.
   - Teacher-only marks diagnostics remain excluded from student documents.

4. **Phone and Windows responsive authoring**
   - The same advanced question is pumped at a compact Android-size viewport
     and an expanded Windows-size viewport.
   - Both must render without Flutter layout exceptions.

5. **Advanced-paper performance**
   - A 200-question paper containing stimulus metadata, word banks, tables,
     nested parts and OR choices is profiled through the existing paper
     validator/serializer.
   - It must remain inside the existing 5-second service budget.

## One-command Windows gate

Run from the EduSheet project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_smart_paper_release_gate.ps1
```

The script intentionally runs the focused Step-6 tests first and then the full
suite. A release is not considered green unless both pass.

## No schema/dependency changes

- No database migration.
- No new package.
- Existing Question/Paper JSON remains the persistence contract.
- Existing Step 1–5 production behavior is not replaced by a second editor.
