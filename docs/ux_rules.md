# UX & UI Rules

This document outlines the design standards and interaction rules for the admin application.

## 1. ID Display & Tooltips
- **Rule**: All technical IDs (UUIDs) displayed in the UI must be truncated using ellipsis if they exceed a certain length.
- **Interaction**: Truncated IDs must show a **Tooltip** with the full ID on hover.
- **Implementation**: Use the `TruncatedText` widget.

## 2. Error & Success Handling
- **Rule**: Never show raw API error strings directly to the user if they are excessively long or cryptic.
- **Interaction**: use a centralized `ResponseHandler` to parse errors and show clean, actionable snackbars.
- **Success Tone**: Use the "✓" symbol for success messages.

## 3. Empty States
- **Rule**: Lists must show a clear "No items found" message with a descriptive reason rather than a blank screen.
