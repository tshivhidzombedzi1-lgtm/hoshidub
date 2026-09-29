# Hoshidub

Before doing anything, read `docs/HANDOFF.md`. It explains the product, the owner, the hard rules, the architecture, what's done and what's left.

The short version of the rules:
- Never bypass DRM, copy protection or bot checks. Never enter the owner's passwords or card details, create accounts or buy anything for him.
- Don't start the app, the Python engine or Hoshi's brain (they use his GPU) without asking. Tests run off-screen or headless.
- Keep replies short and plain, one next step at a time. Credit MCP Labs and Tshivhidzo (Moss) Mbedzi.
- Website: `website/`. Build the upload with `npm run package` and check the live site with `node tools/shots.mjs <url> <dir>`.
