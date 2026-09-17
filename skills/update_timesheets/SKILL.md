---
name: update_timesheets
description: Updates BambooHR timesheet entries, automatically calculating hours based on day of week.
when_to_use: Use when the user asks to "update timesheets", "fill in hours", "clock in/out", "actualizar timesheets", "rellenar horas" or similar, in English or Spanish, specifying dates in natural language, a range, or a list.
argument-hint: "<dates> [--dry-run] [--session <value>] [--csrf <value>] [--employeeId <value>] [--verbose]"
arguments:
  - name: <dates>
    description: "Dates in natural language: today, this week, 2026-08-14, ranges (2026-08-10...2026-08-14), weekday names, or Spanish equivalents"
    required: true
  - name: dry-run
    description: Simulate without sending any requests to BambooHR
    required: false
  - name: "session=<value>"
    description: Override stored PHPSESSID for this run
    required: false
  - name: "csrf=<value>"
    description: Override stored x-csrf-token for this run
    required: false
  - name: "employeeId=<value>"
    description: Override stored BambooHR employee ID for this run
    required: false
  - name: verbose
    description: Show masked curl commands being executed
    required: false
---

# Update Timesheets

Submits timesheet entries to BambooHR via `POST https://wizeline.bamboohr.com/timesheet/clock/entries`. There is no separate script: you (the agent) interpret the user's request, compute the dates and shifts yourself, manage credentials via the filesystem, and send the requests with `curl` using your bash tool. Works with requests in **English or Spanish** — always reply to the user in the language they used.

## 1. Resolve the dates yourself

Parse the user's request directly (you're better at this than any regex). Support at least:

- Explicit dates: `2026-06-10`
- Lists: `2026-06-10, 2026-06-15`
- Ranges: `2026-06-10...2026-06-13` or "from 2026-06-10 to 2026-06-13" (inclusive)
- Natural language (English): `today`, `tomorrow`, `yesterday`, `this week`, `next week`, `last week`, `next N days`, `last N days`, weekday names
- Natural language (Spanish): `hoy`, `mañana`, `ayer`, `esta semana`, `próxima semana`, `semana pasada`, `próximos N días`, `últimos N días`, nombres de días
- Exclusions in either language: `this week minus friday`, `this week except monday`, `this week without friday`, `esta semana menos viernes`, `esta semana excepto lunes`, `esta semana sin viernes`

Use today's actual date (from the system/session context) as the reference point for relative expressions like "today" or "this week". "This week" / "esta semana" means Monday–Friday of the current week.

## 2. Compute the shift for each date

Apply these rules based on day of week, and drop any date that falls on Saturday or Sunday (no shift):

- Monday–Thursday: `09:00-13:00` and `14:00-18:30` (two entries)
- Friday: `09:00-15:00` (one entry)
- Saturday/Sunday: skip, no entry

## 3. Extract optional parameters from the prompt

If the user includes any of these in their message, use them instead of stored/default values:

- `session=<value>` → PHPSESSID
- `csrf=<value>` → x-csrf-token
- `employeeId=<value>` → employee ID (no default — see step 4 if not provided/stored)
- `dry-run` / `dry run` / `simular` / `simulación` / `prueba` → enable dry-run mode (see step 6b)
- `verbose` / `-v` → show the actual `curl` command(s) being run (masking tokens). Without this, never print `curl` commands to the user, in dry-run or real mode.

## 4. Load or request credentials

**This step is mandatory and non-skippable, in both normal and dry-run mode.** Never proceed to the summary table (step 5) without having resolved real `phpsessid`, `csrf_token`, **and `employee_id`** first — not even "just to preview" or "just to show the table". If any of the three is missing, stop everything else and ask before doing anything more.

Credentials persist in `~/.timesheets_config.json` on the user's machine. Use your bash tool to read it:

```bash
cat ~/.timesheets_config.json 2>/dev/null || echo "{}"
```

Expected shape:

```json
{
  "phpsessid": "...",
  "csrf_token": "...",
  "employee_id": 5010
}
```

Resolution order, applied independently to each of the three values (`phpsessid`, `csrf_token`, `employee_id`) — same order for normal runs and dry-runs:
1. Value passed in the current prompt (`session=`, `csrf=`, `employeeId=`).
2. Value stored in `~/.timesheets_config.json`.
3. If a value isn't found in either place, **stop and ask the user** for just that missing value (see "How to ask for missing values" below). Never invent, placeholder, guess, or default any of these — including `employee_id` (there is no default; it must come from the prompt, the file, or the user). This applies in dry-run mode too, and even if the user only asked for a "preview" or "simulation".

In **normal mode only** (not dry-run), after a successful send, persist the credentials/employeeId used, e.g.:

```bash
cat > ~/.timesheets_config.json << 'EOF'
{
  "phpsessid": "VALUE",
  "csrf_token": "VALUE",
  "employee_id": VALUE
}
EOF
```

### How to ask for missing values

Ask for all missing values **in a single call to your interactive question tool**, with one question per missing value (`employee_id`, `PHPSESSID`, `x-csrf-token`).

Important: this tool is multiple-choice, not a text field — the actual value the user types always comes through its free-text "Other" option, not through any preset option label. The tool requires **at least 2 preset options per question**, so for each question use exactly these two:
- Option 1: "I need help finding it" (or "No lo tengo a mano" in Spanish) — just a shortcut, not meant to hold the answer.
- Option 2: "I'll enter it now" (or "Lo voy a escribir ahora" in Spanish) — also just a shortcut; don't put the actual value here either.

Neither preset option should look like it contains or should contain the real value — both are just shortcuts. Word the question itself to tell the user to type/paste the actual value using the free-text "Other" option, e.g. "What's your PHPSESSID? (use 'Other' to type/paste it)". Expect the real answers for all three values to arrive via "Other" in each question's response.

If you need to explain how to find `PHPSESSID`/`x-csrf-token` before asking (e.g. first time, or the user seems unsure), give this explanation in chat first, then open the interactive question tool:

1. Open `https://wizeline.bamboohr.com` in the browser.
2. Open Developer Tools (F12 or Cmd+Option+I).
3. Application → Cookies → `wizeline.bamboohr.com` → copy the value of `PHPSESSID`.
4. Network → reload the page → click any POST request to `entries`.
5. In Headers, copy the value of `x-csrf-token`.

`employee_id` doesn't need this explanation — just ask for it directly (it's the numeric BambooHR employee ID, e.g. `5010`).

## 5. Show a summary table and confirm

Before sending anything, show the user a table like this (translate headers/labels to the language they used):

| Date       | Day    | Shift                     | Status  |
|------------|--------|---------------------------|---------|
| 2026-06-10 | Monday | 09:00-13:00, 14:00-18:30  | Pending |
| 2026-06-13 | Friday | 09:00-15:00               | Pending |

Ask for explicit confirmation before submitting. If there are no valid entries (e.g. only weekend dates), say so and stop.

Keep this exact table (same rows, same order) in memory: you will re-render it in step 7 replacing the `Status` column with a ✅/❌ per row instead of a separate report.

## 6. Submit each date with curl

For each valid date, build the JSON body and send it. Example for a Monday–Thursday date (two entries):

```bash
curl -s -X POST "https://wizeline.bamboohr.com/timesheet/clock/entries" \
  -H "accept: application/json, text/plain, */*" \
  -H "content-type: application/json;charset=UTF-8" \
  -H "origin: https://wizeline.bamboohr.com" \
  -H "referer: https://wizeline.bamboohr.com/employees/timesheet/" \
  -H "x-csrf-token: <CSRF_TOKEN>" \
  -b "PHPSESSID=<PHPSESSID>" \
  --data-raw '{
    "entries": [
      {"id": null, "trackingId": 1, "employeeId": <EMPLOYEE_ID>, "date": "<YYYY-MM-DD>", "start": "09:00", "end": "13:00", "note": "", "projectId": null, "taskId": null, "breakId": null},
      {"id": null, "trackingId": 2, "employeeId": <EMPLOYEE_ID>, "date": "<YYYY-MM-DD>", "start": "14:00", "end": "18:30", "note": "", "projectId": null, "taskId": null, "breakId": null}
    ]
  }' \
  -w "\nHTTP_STATUS:%{http_code}\n"
```

For Friday, send a single entry with `"start": "09:00", "end": "15:00"`.

Run these `curl` commands with your bash tool, but **do not print the command itself to the user** unless they included `verbose`/`-v` in their request — just run it silently and report the outcome (success/error) from the summary in step 7. If `verbose` was requested, you may show the command with `PHPSESSID=***` and `x-csrf-token: ***` masked instead of the real values.

Send one request per date (don't batch multiple dates into a single request). Check the trailing `HTTP_STATUS`:

- `200` → success (✅) for that date.
- `401` or `403` → credentials expired/invalid. Do this instead of just failing that row:
  1. Clear the saved file (`rm ~/.timesheets_config.json` or blank out `phpsessid`/`csrf_token` — you can leave `employee_id` as-is unless the user tells you it's wrong).
  2. Tell the user their session expired and ask for new `PHPSESSID` and `x-csrf-token` together via the interactive question tool (see "How to ask for missing values").
  3. Once you have new values, save them to `~/.timesheets_config.json` and **retry that same date** (and any remaining dates that haven't been sent yet) with the new credentials.
  4. If it fails again with 401/403 after retrying with fresh credentials, mark that date ❌, stop retrying, and tell the user something else is wrong (e.g. wrong `employee_id`, account without permission) — also ask them to double check `employee_id` at that point.
- Anything else (4xx/5xx not related to auth, timeout, connection error) → mark that date ❌, note the HTTP status/error, and keep going with the rest — don't stop the whole run for a single failed date.

## 6b. Dry-run mode

Trigger dry-run mode if the user's message contains `dry-run`, `dry run`, `simular`, `simulación`/`simulacion`, or `prueba` (in addition to any request that explicitly says "don't send it yet" / "no lo envíes todavía").

In dry-run mode:

- Do everything in steps 1–5 normally, **including step 4 (resolving/requesting `phpsessid`, `csrf_token`, and `employee_id`) — this is not optional in dry-run.** If you don't already have all three real values (from the prompt or from `~/.timesheets_config.json`), you must stop and ask the user for the missing ones first, together via the interactive question tool, exactly as in normal mode, before showing anything else.
- The only difference from normal mode: whatever values you end up with (typed by the user, passed as parameters, or already on disk), use them only in memory for this run. Do **not** create, update, or overwrite `~/.timesheets_config.json` in dry-run mode under any circumstance — not even if the user passed `session=`/`csrf=`/`employeeId=` in the prompt.
- **Never execute the `curl` commands.** Do not call your bash/network tool to hit BambooHR at all.
- Describe what would be sent for each date (date, entries, shift times) using the summary table — you also don't need to show the actual `curl` command unless the user also included `verbose`/`-v`. If they did, show the command(s) with `PHPSESSID=***` and `x-csrf-token: ***` masked instead of the real tokens.
- Clearly label the output as a dry run, e.g. start with "🔎 DRY RUN — no requests were sent" (or the Spanish equivalent "🔎 SIMULACIÓN — no se ha enviado ninguna petición"). If credentials were provided this run but not saved, say so explicitly, e.g. "Credentials were used for this simulation only and were not saved."
- Skip the confirmation question (step 5) — there's nothing destructive to confirm since nothing will be sent. Still show the summary table.
- End by asking if the user wants to run it for real (without dry-run) to actually submit and save the credentials.

## 7. Report results

Re-render the same table from step 5, replacing `Status` (`Pending`) with the actual outcome per row: ✅ if that date's request returned `200`, ❌ if it ultimately failed (include a short reason in the same cell or a trailing note, e.g. `❌ HTTP 500`). Don't write a separate prose summary of successes/failures — the table itself is the report.

Below the table, add one line confirming whether credentials are saved for next time, and if you had to ask for new credentials mid-run, mention that briefly.

## Notes

- Never print the full `PHPSESSID` or `x-csrf-token` back to the user in chat — just confirm they were saved.
- If the user's message mixes English and Spanish, just respond in whichever language dominates or matches their last message.
- Always show the confirmation table before making any network call.
