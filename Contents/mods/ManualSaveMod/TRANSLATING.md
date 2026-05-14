# Translating Manual Save Mod

## Setup

1. Copy `42/media/lua/shared/Translate/EN/UI.json` into your language folder:
   `42/media/lua/shared/Translate/XX/UI.json` (replace `XX` with your language code)

2. Translate only the values — never the keys:
   ```json
   "UI_MSM_Common_BtnCancel": "Cancel"
     ^--- do not touch          ^--- translate this
   ```

## Rules

- Keep `\n` in place — it is a line break, not visible text.
- Keep `%1`, `%2` etc. — they are runtime placeholders.
- Keep the JSON syntax intact (quotes, commas).

## Language codes

| Language | Code | Language | Code |
|----------|------|----------|------|
| English (reference) | EN | Russian | RU |
| Italian | IT | Chinese Simplified | CN |
| French | FR | Chinese Traditional | CH |
| German | DE | Korean | KO |
| Spanish | ES | Japanese | JP |
| Polish | PL | Portuguese (BR) | PT |

Full list: [pzwiki.net/wiki/Translations](https://pzwiki.net/wiki/Translations)

---

## Sections

You do not have to translate everything. The UI strings are the most useful.
The Help section is large and entirely optional — untranslated keys fall back
to English automatically.

The full list of keys is in `42/media/lua/shared/Translate/EN/UI.json`.

---

## Submit

Open a pull request on GitHub or send the file directly via the Steam Workshop
discussion thread.
