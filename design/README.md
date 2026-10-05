# Shared design foundation — palette undecided

tokens reserves future semantic roles such as background, surface, text, border, primary action, focus, warning and unknown. Light and dark roles will receive values only after a design direction is chosen. No color values, font selection or UI mockup is created now.

assets reserves future reusable brand assets. Token data may later export to Flutter and CSS/TypeScript; frontend implementations should preserve shared meaning without pretending they use identical components.

The target layouts and interaction/accessibility rules live in [UI requirements](../docs/planning/UI_REQUIREMENTS.md). When UI building starts, find/select the design system before creating screens. Review rendered mobile/tablet/desktop states in both modes; no rendered review is claimed for this folder-only foundation.
