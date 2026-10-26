# Jenius Tryout — Backend Integration Checklist

## Implemented now
- Proposed isolated schema in `supabase/migrations/20261026_jenius_tryout.sql`.
- RLS on all proposed tables. Published category/exam metadata only is publicly readable.
- No browser access to answer keys, answer records, scores, or payment mutation.
- Existing public pages and local demo are intentionally unchanged.

## Still required before launch
1. Choose the Supabase project and confirm whether the panel-baru admin uses the same project. Never run this SQL blindly against the production panel database.
2. Review migration, test it on staging and run once using Supabase SQL Editor or migrations.
3. Implement real Supabase Auth (email verification, password recovery, session handling). Replace local demo login; never treat a local nickname as authentication.
4. Implement trusted server endpoints for eligible attempt creation, question delivery **without answer keys**, autosave, submission and server-side grading with enforced duration.
5. Add admin role/permission enforcement and auditing in panel-baru, with scoped access to question banks, scheduling, results and orders.
6. Configure payment provider, server-side order creation, signed webhook validation, reconciliation, and idempotency. Do not accept browser-reported payment status.
7. Privacy notices, retention, consent for minors, abuse protections, logging, backups and staging end-to-end tests.
8. Replace mock illustrations with licensed assets; verify visual quality on Vercel preview.

## Security notes
- Never expose `service_role` or provider secret in client assets.
- The migration intentionally grants no client access to `jt_questions` and `jt_answers`.
- Client cannot create or modify `jt_attempts`, `jt_orders` or score fields.
- Correct answer/explanation must be returned only by trusted code after submission.
- The sample CBT in `js/portal.js` is explicitly a demo and not suitable for paid exams.
