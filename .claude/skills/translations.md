---
name: translations
description: How to add missing translations to the Localizable.xcstrings file
---

# Adding missing translations

## When to use

When asked to add missing translations, or when new user-facing strings have been added without translations.

## Languages

The project supports these languages/locales:

| Code | Language |
|------|----------|
| en | English (source language) |
| de | German |
| es | Spanish (Spain) |
| es-419 | Spanish (Latin America) |
| fr | French |
| nl | Dutch |

All five non-English languages must have translations for every string entry.

## Procedure

1. Read `Spaceman/Localizable.xcstrings` and identify entries that are missing translations for any of the five languages.
2. For each missing translation:
   - Scan existing translations in the file for comparable terminology. If a specific word choice has been established (e.g., a particular word for "pill", "space", "icon", or the distinction between "Borrar" and "Quitar" in Spanish), reuse it consistently.
   - Use macOS-standard terminology for UI concepts. Match Apple's own localization where applicable.
   - For `es` and `es-419`: these may share translations, but check existing entries — sometimes they differ.
3. Add translations using the Edit tool, matching Xcode's JSON formatting (`" : "` with space before colon, 2-space indentation). See the `xcstrings-conflicts` skill for formatting rules.
4. Validate the JSON afterward: `python3 -c "import json; json.load(open('Spaceman/Localizable.xcstrings')); print('Valid JSON')"`

## Language-specific rules

### Dutch (nl)
- Prefer infinitive-last (unseparated) verb forms: "XYZ uitwissen", not "Wis XYZ uit".
- This applies to labels, menu items, and descriptions.

### Spanish (es / es-419)
- Use "escritorios" for Spaces (virtual desktops), matching Apple's macOS terminology. Not "espacios".
- `es` (Spain) uses "icono" (no accent); `es-419` (Latin America) uses "ícono" (with accent). Never mix these up.
- Use "modificador"/"modificadores" for modifier keys, not "teclas modificadoras".
- Maintain consistency in word choice across the file. If "Quitar" has been used for "remove" in existing translations, don't switch to "Eliminar" for a new similar string.

### German (de) / Dutch (nl)
- Keep "Spaces" as a loanword for the feature (Apple's macOS keeps this untranslated in German and Dutch).

### French (fr)
- Use "espaces" for Spaces (matching Apple's French macOS localization).
- Use "modificateur"/"modificateurs" for modifier keys, not "touches de modification".

### All languages
- Keep translations concise — these appear in menus and preferences UI where space is limited.
- Do not translate keyboard shortcut symbols (⌘, ⌥, ⇧, etc.) or technical identifiers.
