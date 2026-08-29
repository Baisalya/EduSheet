# EduSheet Premium subscription add-on - inactive scaffold

## Store identity

- Product ID: `edusheet_premium_yearly`
- Partner Center Store ID: `9PGCF60ZZ4ZC`
- Type: Subscription add-on
- Intended period: Annual
- Current status: Created in Partner Center; no submission started, no price/availability configured, and not published
- App checkout flag: `PREMIUM_ENABLED=false`
- Current customer experience: All workspace colour styles are unlocked for free

## Future Partner Center copy

Title: EduSheet Premium - Annual

Short description: Optional annual supporter plan with premium workspace personalisation. Core paper creation, current exports, and teacher tools remain usable without a subscription.

Feature boundary:

- Premium colour styles and supporter status only.
- Do not remove current core paper creation, Question Bank, OMR, document preview, calculator, or current PDF/Word export from free users without a separately reviewed product decision.
- Do not publish the add-on until purchase, cancellation, expiry, refund, offline licence, and restore flows are tested with Store licence accounts.

## Activation contract

When the owner explicitly decides to charge users:

1. Reuse the existing Microsoft add-on and create the exact product ID above only in any additional intended store.
2. Keep the Microsoft runtime product-kind query as `Durable`; the Partner Center product type itself remains `Subscription`.
3. Configure price, tax, markets, privacy URL, support details, subscription period, and reviewer notes.
4. Build with `--dart-define=PREMIUM_ENABLED=true` only for a private test track first.
5. Add server-side purchase verification before relying on subscription revenue or cross-device account recovery at scale.
6. Update the app UI, privacy policy, Store disclosures, website, and `RELEASE_HELPER.md` before public activation.
