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

## Key prefixes

| Prefix | Area |
|--------|------|
| `UI_MSM_Common_` | Shared buttons and warnings |
| `UI_MSM_Save_` | Save screen |
| `UI_MSM_Load_` | Load screen |
| `UI_MSM_Dialog_` | Confirmation dialogs |
| `UI_MSM_Ops_` | Save operations panel |
| `UI_MSM_Help_` | In-game help screen |

## Submit

Open a pull request or send the file directly via Steam.
