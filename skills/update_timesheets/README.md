# update_timesheets

Automatically submit timesheet entries to BambooHR with intelligent shift calculation based on day of week. Supports natural language date parsing in **English and Spanish**, credential management, and dry-run mode.

## Quick Start

```bash
/gtools:update_timesheets this week
```

You'll be prompted to provide missing credentials (first time only), see a summary table, confirm, and the entries will be submitted to BambooHR.

## Date Formats

The skill accepts dates in many formats:

### Explicit dates
- `2026-08-10` — single date
- `2026-08-10, 2026-08-12` — comma-separated list
- `2026-08-10...2026-08-14` — range (inclusive)

### Natural language (English)
- `today`
- `tomorrow` / `yesterday`
- `this week` — Monday to Friday of current week
- `next week` / `last week`
- `next 5 days` / `last 3 days`
- Monday, Tuesday, Wednesday, Thursday, Friday (by name)

### Natural language (Spanish)
- `hoy` — today
- `mañana` / `ayer` — tomorrow / yesterday
- `esta semana` — this week (Monday–Friday)
- `próxima semana` / `semana pasada` — next/last week
- `próximos 5 días` / `últimos 3 días` — next/last N days
- lunes, martes, miércoles, jueves, viernes (by name)

### Exclusions (English & Spanish)
- `this week minus friday` — exclude a day
- `this week except monday` — alternate wording
- `esta semana sin viernes` — Spanish variant

## Shift Schedule

Shifts are calculated automatically based on day of week:

| Day | Shift | Duration |
|-----|-------|----------|
| Monday–Thursday | 09:00–13:00, 14:00–18:30 | Two 4.5h entries |
| Friday | 09:00–15:00 | One 6h entry |
| Saturday/Sunday | *(skip)* | No entry submitted |

For example, if you submit timesheets for "this week" (Mon–Fri):
- Mon, Tue, Wed, Thu: 4 separate 4.5-hour entries (1 morning, 1 afternoon each)
- Friday: 1 six-hour entry
- Total: 24 hours (18 + 6)

## Usage

### Basic: dates only
```bash
/gtools:update_timesheets this week
```
Prompts for credentials (first time), shows a summary table, asks for confirmation, submits.

### Dry-run mode (preview without submitting)
```bash
/gtools:update_timesheets this week dry-run
```
Shows what *would* be submitted — no requests sent, credentials not saved (even if you provide them this run).

### Custom credentials this run (override stored)
```bash
/gtools:update_timesheets 2026-08-10...2026-08-14 session=your_phpsessid csrf=your_token employeeId=5010
```
Uses the provided credentials instead of stored ones. In normal mode, these are saved for future use.

### Verbose mode (see masked curl commands)
```bash
/gtools:update_timesheets this week verbose
```
Prints the actual curl commands being executed, with credentials masked as `PHPSESSID=***` and `x-csrf-token: ***`.

### Combined
```bash
/gtools:update_timesheets this week dry-run verbose
```
Preview with commands shown (credentials masked).

## Credential Management

### First Run
The first time you use this skill, you'll be asked for three values:
1. **PHPSESSID** — your BambooHR session cookie
2. **x-csrf-token** — CSRF token from BambooHR requests
3. **employee_id** — your numeric BambooHR employee ID

**How to find them:**

1. Open `https://wizeline.bamboohr.com` in your browser
2. Open Developer Tools (F12 or Cmd+Option+I)
3. **For PHPSESSID:**
   - Go to Application → Cookies → `wizeline.bamboohr.com`
   - Copy the value of `PHPSESSID`
4. **For x-csrf-token:**
   - Go to Network tab → reload the page
   - Click any POST request to `entries`
   - In Headers, copy `x-csrf-token`
5. **For employee_id:** (find in your BambooHR profile or ask your manager)

These are saved locally in `~/.timesheets_config.json` for future runs.

### Session Expiration
If you get a 401/403 error:
- The skill will clear the saved session and ask for new credentials
- Provide fresh `PHPSESSID` and `x-csrf-token`, and the run will retry
- If it fails again after retry, check your `employee_id` — you may have the wrong one

### Override without saving
Pass credentials as parameters:
```bash
/gtools:update_timesheets this week session=temp_session csrf=temp_token employeeId=5010
```
In dry-run mode, these are never saved. In normal mode, they're saved for next time.

## Examples

### Submit timesheets for this week
```bash
/gtools:update_timesheets this week
# Shows summary table, asks for confirmation, submits
```

### Submit for a specific range
```bash
/gtools:update_timesheets 2026-08-10...2026-08-14
# Mon–Fri of that week
```

### Submit individual dates
```bash
/gtools:update_timesheets 2026-08-10, 2026-08-12, 2026-08-15
# Monday, Wednesday, Friday only
```

### Next 5 business days
```bash
/gtools:update_timesheets next 5 days
# Current day + next 4, skipping weekends
```

### Spanish: submit last week
```bash
/gtools:update_timesheets semana pasada
# Lunes–viernes of last week
```

### Exclude a day
```bash
/gtools:update_timesheets this week minus friday
# Mon–Thu only
```

### Preview first, then submit
```bash
# First, dry-run to see what would happen
/gtools:update_timesheets this week dry-run

# Looks good? Run for real
/gtools:update_timesheets this week
```

## Summary Table

Before submitting, you'll always see a table like this:

| Date | Day | Shift | Status |
|------|-----|-------|--------|
| 2026-08-10 | Monday | 09:00-13:00, 14:00-18:30 | Pending |
| 2026-08-11 | Tuesday | 09:00-13:00, 14:00-18:30 | Pending |
| 2026-08-12 | Wednesday | 09:00-13:00, 14:00-18:30 | Pending |
| 2026-08-13 | Thursday | 09:00-13:00, 14:00-18:30 | Pending |
| 2026-08-14 | Friday | 09:00-15:00 | Pending |

After submission, the Status column is replaced with ✅ (success) or ❌ (failed, with reason).

## Troubleshooting

### "Session expired" (401/403)
Your PHPSESSID or x-csrf-token is no longer valid. The skill will ask for fresh ones. Find them again from your browser's DevTools and provide them.

### Wrong employee_id
If your submissions fail after retrying with fresh credentials, your `employee_id` may be wrong. Check:
1. Your BambooHR profile
2. Ask your manager
3. Try a different ID and run the skill again

### Weekend dates are skipped
Saturdays and Sundays are automatically excluded (no timesheet entries). This is by design.

### "No valid entries"
You requested dates that are all weekends or already submitted. Check your date range:
```bash
# If you only selected Sat-Sun:
/gtools:update_timesheets saturday sunday
# → "No valid entries — no weekday dates found"

# Correct approach:
/gtools:update_timesheets this week
```

### Credential file corruption
If `~/.timesheets_config.json` is corrupted:
```bash
rm ~/.timesheets_config.json
# Re-run the skill to re-enter credentials
/gtools:update_timesheets this week
```

## See Also

- **[post-push-review](../post-push-review/)** — Auto-fix PR review comments
- **[team-lead](../team-lead/)** — Multi-agent task orchestration
