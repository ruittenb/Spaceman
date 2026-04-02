---
name: xcstrings-conflicts
description: How to resolve merge conflicts in Xcode .xcstrings localization files
---

# Resolving .xcstrings merge conflicts

## Xcode formatting

Xcode formats `.xcstrings` JSON with a **space before every colon**: `"key" : "value"`, not `"key": "value"`. This applies to all levels of the JSON structure. Never write JSON without this space — it will cause whitespace conflicts on the next Xcode edit or merge.

## Why conflicts happen

The `.xcstrings` file is a single large JSON file with alphabetically ordered keys. Commits that add or modify different string entries often conflict because:
- Both sides touched nearby entries in the alphabetical order
- One side reformatted whitespace (e.g., Python's `json.dumps` strips the space before colons)

## Resolution strategy

1. **Never use Python `json.dumps` to write `.xcstrings` files.** It produces `"key": "value"` (no space before colon), which mismatches Xcode's format and causes cascading whitespace conflicts.

2. **For conflicts during rebase/merge:**
   - Identify which string keys each side added or modified (use `python3 -c "import sys,json; ..."` to *read* and compare keys — reading is fine, just don't write back with it)
   - Take one side's complete file as the base (usually HEAD)
   - Manually add missing entries from the other side using the Edit tool, matching Xcode's formatting: `" : "` (space-colon-space) everywhere

3. **When adding a new entry**, match the exact indentation and formatting of surrounding entries:
   ```json
   "New String Key" : {
     "localizations" : {
       "de" : {
         "stringUnit" : {
           "state" : "translated",
           "value" : "German translation"
         }
       }
     }
   },
   ```
   Note: 2-space indentation, `" : "` on every key-value pair.

4. **After resolving, validate** with: `python3 -c "import json; json.load(open('path/to/file.xcstrings')); print('Valid JSON')"`
