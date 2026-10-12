# Data Quality Notes — Week 2

**Schema:** `raw_rides` · **Question:** which pickup zones generate the most revenue, and where are cancellations concentrated?

Ran `sql/week2_profile.sql` top to bottom against `raw_rides`. Every finding below is numbered to match the query pack section it came from, so it's traceable back to the exact query that found it.

## 1. What is here?

| table | rows |
|---|---|
| trips | 28,112 |
| drivers | 200 |
| riders | 1,000 |
| zones | 15 |

Four tables, one fact (`trips`), three dimensions.

## 2. Look at the data

All date columns (`trip_date`) are declared as `TEXT`, not `DATE` — confirmed via `information_schema.columns`. This isn't a setup mistake; it's because the source mixes multiple formats and wouldn't load as a real date type. Parsing them is week 3's job, not something to paper over here with a cast.

## 3. Missing values

| column | missing |
|---|---|
| trip_date | 0 |
| status | 0 |
| **fare** | **1,406** |
| driver_id | 0 |
| rider_id | 0 |
| pickup_zone_id | 0 |

Only `fare` has gaps — every key column and `status` is fully populated. That's good news for the join integrity question (§8) but means the 1,406 missing fares need a real decision, not a shrug: **treat as NULL, exclude from `SUM(fare)`, don't zero-fill.** Zero-filling would understate revenue; dropping the rows would lose real trip volume for a column that isn't even the reason the row exists.

## 4. Duplicates

- 28,112 total rows, 28,000 distinct `trip_id` → **112 extra rows.**
- Checked the offending rows individually (not just counted them): every one of the 112 is a full exact duplicate — same `trip_id`, same every other column, not a reused ID attached to different data.
- **Decision: drop, keep one copy.** This is a load/export artifact, not two genuinely different trips colliding on an ID.

## 5. Inconsistent categories

`status` returns **12 distinct raw values**, not 3:

| raw value | rows |
|---|---|
| `Completed` | 21,145 |
| `Cancelled by rider` | 2,225 |
| `Cancelled by driver` | 1,258 |
| `COMPLETED` | 1,041 |
| `  Completed ` | 974 |
| `completed` | 961 |
| `  Cancelled by rider ` | 124 |
| `CANCELLED BY RIDER` | 111 |
| `cancelled by rider` | 101 |
| `cancelled by driver` | 66 |
| `CANCELLED BY DRIVER` | 63 |
| `  Cancelled by driver ` | 43 |

`UPPER(TRIM(status))` collapses this to the real 3 categories — **COMPLETED 24,121 · CANCELLED BY RIDER 2,561 · CANCELLED BY DRIVER 1,430** — and those three sum to exactly 28,112, confirming nothing hides underneath. Same pattern, checked and confirmed present in two other columns not on the original checklist but worth flagging since they'll hit the model the same way:

- `drivers.vehicle_type`: 10 raw spellings → 3 real categories (Saloon, Shared, SUV)
- `riders.payment_preference`: 12 raw spellings → 3 real categories (Cash, Card, Mobile Money)

**Decision: trim + normalize case on all three columns** before anything downstream groups by them.

## 6. Date formats

Four shapes live in `trip_date`, all in one column:

| shape | rows |
|---|---|
| `YYYY-MM-DD` | 23,021 |
| `YYYY/MM/DD` | 1,727 |
| `DD-Mon-YYYY` | 1,709 |
| `DD/MM/YYYY` | 1,655 |

The ambiguous case — `DD/MM/YYYY` vs `MM/DD/YYYY` — is resolved by evidence, not assumption: several slash-dates have a first token above 12 (e.g. `29/05/2025`, `28/11/2025`, `30/09/2024`), which is only possible if the first token is the day. **Decision: day-first (`DD/MM/YYYY`) for every slash-separated value**, applied consistently rather than row-by-row guessing.

## 7. Impossible values

- **42 trips have `fare = 0`.** Sampled 15 directly: they span both `Completed` and cancelled statuses, and show normal, non-trivial distance/duration alongside the zero fare (e.g. a 25.76 km / 100.2 min trip billed at 0.0) — a real fare that got lost, not a legitimately free ride.
- `MIN(fare) = 0`, `MAX(fare) = 125.81`, `AVG(fare) = 24.64` — no negative fares, and the max isn't absurd for a longer trip, so the range itself isn't the alarm; the 42 zeros are.
- **Decision: treat `fare = 0` the same as missing fare (§3)** — set to NULL, exclude from revenue sums — rather than count it as GH₵0 of real revenue.

## 8. Broken relationships

| foreign key | orphan rows |
|---|---|
| `driver_id` → `drivers` | **70** |
| `rider_id` → `riders` | 0 |
| `pickup_zone_id` → `zones` | 0 |

Only `driver_id` has a problem, and it's a specific, deliberate-looking one: every orphaned ID sits in a distinct 90000-block (`90000`, `90001`, `90002`, ...) — nowhere near the real driver ID range (1–200). That's not a typo pattern (a fat-fingered `12` becoming `120` would still land in-range); it reads as a placeholder for "driver unknown / removed from roster."

**Decision: keep the rows, don't drop them.** Add a synthetic `Unknown Driver` row to `dim_driver` and repoint these 70 trips at it. Dropping them would understate trip volume and revenue for zones that happen to have more of these; a silent orphan-driven disappearance from the model would be worse than an explicit "Unknown Driver" line item a stakeholder can see and ask about.

## 9. Time coverage

`MIN`/`MAX` on the raw text column returns `01-Apr-2024` to `31/12/2024` — and that's **wrong, not just imprecise.** `MIN`/`MAX` on a `TEXT` column sorts alphabetically, not chronologically. `01-Apr-2024` sorts low because `"0"` is a low character, not because April 2024 is early; `31/12/2024` sorts high for the same string reason. This is exactly why §2 flagged the column type — nothing that touches `trip_date` as text can be trusted for range, filtering, or ordering. The real range has to wait for week 3's parsed date column.

**Known knock-on risk, checked directly:** the temporary `WHERE trip_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'` shortcut used to get a monthly breakdown today (§10) keeps 23,021 rows and **silently drops 5,091** — 18% of all trips — because it only matches the `YYYY-MM-DD` shape. Any month-by-month number produced this way before week 3 is undercounted by nearly a fifth, invisibly.

## 10. First real analysis (raw, unfixed — for comparison against the cleaned version in week 3)

Revenue by pickup zone, run on the raw data with duplicates still in and all three status spellings still uncollapsed:

| zone_name | rows | total_fare |
|---|---|---|
| Teshie | 2,007 | 46,687.80 |
| Lapaz | 1,930 | 45,595.23 |
| Airport City | 1,891 | 45,351.39 |
| Tema | 1,871 | 44,822.12 |
| East Legon | 1,886 | 44,598.32 |
| Weija | 1,904 | 44,530.84 |
| Osu | 1,851 | 44,438.73 |
| Madina | 1,900 | 44,375.59 |
| Dansoman | 1,885 | 43,666.22 |
| Achimota | 1,867 | 43,388.71 |
| Spintex | 1,806 | 42,352.31 |
| Kaneshie | 1,831 | 42,226.74 |
| Adenta | 1,802 | 42,144.19 |
| Ashaiman | 1,842 | 41,920.62 |
| Haatso | 1,839 | 41,848.84 |

This table is **not the answer to the term question yet** — it still includes cancelled-trip fares (should be ~0 or excluded), still double-counts the 112 duplicate trips, and still can't be trusted for any date-based cut. It's here as a baseline to sanity-check against once week 3's cleaning is done — if the cleaned total revenue for Teshie isn't noticeably lower than 46,687.80, something in the cleaning step didn't take.

## 11. The full join

Confirmed all three joins (`drivers`, `riders`, `zones`) resolve without introducing duplicate trip rows — row count from the 25-row preview join matches the fact table's grain (one row per trip), so the star schema shape planned for week 4 (one fact, three dimensions, no fan-out) is sound once the fixes above are in place.

---

## Summary — decisions carried into week 3

| # | Issue | Decision |
|---|---|---|
| 4 | 112 exact duplicate trip rows | Drop, keep one copy |
| 5 | 12 status spellings / 10 vehicle_type / 12 payment_preference spellings | Trim + normalize case onto the real 3-value set each |
| 6 | 4 date formats, ambiguous slash-dates | Parse all 4 explicitly; slash-dates are day-first, confirmed by day>12 evidence |
| 7 | 42 zero-fare rows | Treat as missing, exclude from revenue sums |
| 3 | 1,406 missing fares | NULL, not zero-filled |
| 8 | 70 orphan `driver_id` (90000-block) | Keep trips, map to synthetic "Unknown Driver" |
| 9 | Text-based date min/max is meaningless; naive format-shortcut drops 18% of rows | Full multi-format parse required before any date-based query in week 3 |

Committed as `data_quality_notes.md`. Week 3 starts from this file.
