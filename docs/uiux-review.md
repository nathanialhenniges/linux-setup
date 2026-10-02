# UI/UX Review: MacBook Air Linux Guide

**Reviewed:** 2026-10-02 · **Input:** locally served `docs/index.html` · **Method:** NN/g heuristic evaluation plus Chromium/Playwright interaction checks

## Executive summary

- The page gives the MacBook Air install steps a clear order and keeps the main setup commands easy to find and copy.
- Progress can be saved, transferred, resumed, and reset with visible feedback and a confirmation before clearing it.
- The mobile layout reflows cleanly in the tested viewport widths, and the keyboard path works for the tested controls.
- No severity 3 or 4 usability problems were found in this review; no severity 1–2 findings were recorded either.

**Findings:** 🟥 0 catastrophic · 🟧 0 major · 🟨 0 minor · ⬜ 0 cosmetic

## Findings

No findings rated 1–4 in the tested page and flows.

## Unverified (needs a different input to check)

- The deployed GitHub Pages version — this review served the local `docs/` build, so it does not confirm the public deployment has the same files.
- Actual use on the 2015 MacBook Air, another physical phone/tablet, or a touch screen — browser viewport emulation is not a hardware test.
- Screen reader and voice-control behavior, browser zoom at 400%, forced-colors/high-contrast mode, and browser compatibility beyond Chromium.
- Whether the installation commands and hardware instructions match current EndeavourOS packages and this laptop — this review assessed the guide UI, not the technical instructions.

## What's working well

- The header presents the laptop model, desktop choice, bootloader, progress behavior, and disk-erasure warning before the detailed checklist. The four-part illustration reinforces the sequence.
- Six section links and the “Continue” action reduce the need to remember where to resume. The guide shows checkbox totals and progress, saves locally, and provides a JSON export/import path to move progress between machines.
- The tested structure has one `h1`, no skipped heading levels, named buttons and links, descriptive checkbox labels, and declared image alt text. Body text is 16px with a 1.65 line-height; the responsive `h1` is 40px on mobile and scales up to 68px on desktop, followed by 24px `h2` and 18px `h3` headings.
- Measured foreground/background pairs exceed WCAG AA text contrast thresholds: body text 16.30:1, muted text 9.18:1, cyan links 11.47:1, and the amber warning 11.70:1. The figures use the colors in `docs/guide-source.css`.
- The keyboard test reaches the skip link first, activates it, toggles a checkbox with Space, sees a 3px focus outline, and uses keyboard activation for progress export/import and reset. All 18 copy controls copied their matching command in Chromium.
- At 320, 375, 390, 768, 1280, and 1440 CSS-pixel widths, the document had no horizontal overflow. At the 390px mobile width, visible links, buttons, and checkboxes measured at least 24×24 CSS pixels. This tests the measured target-size threshold in [WCAG 2.2 SC 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum) and page reflow at [320 CSS pixels](https://www.w3.org/WAI/WCAG21/Understanding/reflow); it is not a complete WCAG conformance audit.
- Import tests covered valid data, invalid schema, oversized files, and canceling the replace confirmation. Invalid/canceled imports preserved current progress. Copy fallback and blocked local storage also left the guide usable.

## Quick wins

- None identified in this pass.

## Test evidence

Automated checks are in [`tests/test_guide.cjs`](https://github.com/nathanialhenniges/linux-setup/blob/main/tests/test_guide.cjs) and run with `npm run test:guide`. The completed run passed 25 checklist-item, 18 copy-control, progress persistence/reset/transfer, keyboard, blocked-storage, clipboard-fallback, semantic markup, and responsive overflow checks. Focus visibility was checked against [WCAG 2.2 SC 2.4.7](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible).

The heuristic review follows NN/g's [10 usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/). Heuristic evaluation is a review method, not a substitute for observing users with assistive technology or on the target laptop.
