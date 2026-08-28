# EduSheet website concept audit

Audited source: `C:\Users\baish\Baisalya-Roul\EduSheet`

## Verdict

The positioning is strong and matches the product: **a math-first question-paper
workspace for teachers**, not a generic office editor. The clearest USP is the
visual/semantic Math Keyboard, followed by the connected paper workflow,
Question Bank, geometry, OCR, OMR and PDF/Word export.

The quantitative homepage claim is also source-backed: the app currently has 16
specialized catalog files and 293 `MathSymbol` placements, so “16” and “290+”
are accurate.

## Publish blockers

1. `privacy.html` still contains legal placeholders and calls itself a draft.
2. `assets/js/site.js` has empty Google Play and Microsoft Store URLs, so the
   download buttons are intentionally disabled.
3. `sitemap.xml` still points at `https://example.com`; `robots.txt` has no
   production sitemap URL.
4. `support@edusheet.com` is explicitly marked unverified in the manual.
5. The site has no Premium, rating, update-check or premium-theme information,
   and its Settings manual is now behind app version `1.1.0+2`.
6. The privacy policy does not yet disclose store billing, rating requests or
   automatic store update checks added in `1.1.0+2`.
7. In the parent Git repository the old `EduSheet_static_website/` tree is
   deleted while the new `EduSheet/` tree is untracked. The move must be staged
   and committed before deployment can include it.

## Recommended website change

Keep the current hero and teacher-workflow story. Add a small, transparent
Premium section that says the current one-time supporter upgrade unlocks colour
styles and a supporter badge while essential creation tools remain free. Do not
claim subscription-only features, cloud backup or downloaded AI models until
those capabilities exist.
