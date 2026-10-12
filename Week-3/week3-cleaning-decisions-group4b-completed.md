# Week 3 — Cleaning decisions

**Group 4b** · Ride-hailing trips · your week 3 deliverable

| | |
|---|---|
| **Group** | group4b |
| **Phase lead this week** | |
| **Who worked on the notebook** | |
| **Date completed** | |

> **What you are producing this week**
> Clean tables in your group4b schema, a notebook that rebuilds them from scratch, and this record of every decision you made and why.

## Why the decisions matter more than the code

Your notebook already has the code. What it cannot have is your judgement. Every problem you found in week 2 has two or three defensible fixes, and choosing between them is the actual analyst work.

You will be asked to defend these choices in week 8. "It seemed fine" is not a defence. "We dropped 60 rows because a negative quantity cannot be a real sale, and 60 out of 30,000 was too few to change any conclusion" is.

> **There is no single right answer to most of this.** There is a wrong one: doing it silently, so that nobody including you can say later what happened to the data.

---

## 1. Your six decisions

One row per problem from week 2. What you did, and the reason. Numbers in the middle column — how many rows were affected.

| The problem | How many rows | What we did, and why |
|---|---|---|
| **Duplicate rows** | 112 of 28,112 (0.4%) | Dropped, kept one copy. Checked individually first: every one of the 112 was a full exact duplicate (same `trip_id`, same every other column) — a load/export artifact, not two genuinely different trips colliding on an ID. |
| **Inconsistent categories** | `status`: 12→3 spellings. `vehicle_type`: 10→3. `payment_preference`: 12→3. | Trimmed whitespace and title-cased all three columns onto their real 3-value set. Fixed one title-case side effect by hand ("SUV" became "Suv") rather than leaving a 4th spelling hiding in the output. |
| **Date formats** | 4 formats across 28,112 rows; 0 failed to parse | Parsed with `pd.to_datetime(format='mixed', dayfirst=True)`. `dayfirst` chosen because slash-dates with a first token above 12 (e.g. 29/05/2025) only make sense read as day-first — see section 2 below for the full reasoning. |
| **Impossible values** | 38 completed trips with `fare = 0` | Set `fare` to NULL for these 38 rows only (not the ~4 zero-fares on cancelled trips, which are legitimate). Kept the rows — the rest of each row (distance, duration, zones) is real; only the fare was lost. |
| **Orphan keys** | 70 trips with a `driver_id` not in `drivers` (90000-block) | Kept the trips, added a synthetic "Unknown Driver" row (`driver_id = -1`) and repointed the 70 orphans at it. Confirmed `rider_id` and `pickup_zone_id` have zero orphans, so only `drivers` needed this. |
| **Missing values** | `fare`: 1,406 → 1,400 after dedup → 1,438 after nulling the 38 impossible values | Left as NULL, no fill. `SUM()` correctly skips NULLs; filling with 0 or an estimate would misstate every affected zone's revenue. No other column had missing values. |

---

## 2. The ambiguous dates

*A date written 03/04/2025 could be 3 April or 4 March. Nothing in the data proves which. Your notebook uses `dayfirst=True`, which reads it as 3 April.*

**Did you keep `dayfirst=True`, or change it? What made you decide?**

Kept `dayfirst=True`. This isn't a coin flip — it's supported by evidence in the data itself: several slash-separated dates have a first token greater than 12 (e.g. 29/05/2025, 28/11/2025, 30/09/2024), and a month can never exceed 12. The only way those values parse at all is if the first token is the day. Since we found no evidence anywhere in the data pointing the other way, we applied day-first consistently to every slash-date rather than deciding case by case.

**How many rows would be affected if you had it backwards?**

630 rows would silently get a different, wrong date. Of the 1,655 slash-form dates: 968 have a first token above 12, so reading them month-first would fail to parse at all (loudly, not silently) — pandas would reject them or return `NaT`, and we'd notice immediately. Another 57 have identical day and month values (e.g. 05/05/2025), so the reading doesn't matter for those. The remaining 630 have both tokens ≤ 12 and different from each other — those are the genuinely dangerous ones: flipping day/month there produces a different but still-valid date, so the error would never surface on its own. That's the real cost of getting this wrong, and why it's worth stating and defending the choice rather than leaving it as a default setting nobody looked at.

---

## 3. Before and after

*From section 10 of your notebook. Every number that changed needs an explanation that adds up.*

### Row count

**Before / after / difference:**

28,112 / 28,000 / −112

**Account for every row you lost — how many were duplicates, how many impossible, how many orphans. The numbers must add up:**

All 112 lost rows are duplicates. Impossible values (38) and orphan keys (70) did not lose any rows — both were kept and repaired in place (fare nulled, `driver_id` repointed to Unknown), not dropped. So the accounting is: 112 duplicates + 0 impossible + 0 orphan = 112, which matches the row-count change exactly.

### Categories in status

**Before / after:**

12 raw spellings before → 3 real categories after (Completed, Cancelled By Rider, Cancelled By Driver).

### Missing values

**Before / after, and what accounts for the change:**

1,406 before → 1,438 after — a net change that hides two moves in opposite directions, not one:

- 1,406 → 1,400: dropping the 112 duplicate rows removed 6 rows that already had a missing fare, so they left with their twin.
- 1,400 → 1,438: nulling the 38 impossible zero-fares on completed trips (section 1) deliberately added them to the missing count.

The increase is a sign the cleaning worked, not a mistake — it converted a value that was wrong-but-present (a fare of 0 that wasn't real) into a value that's honestly flagged as unknown.

### Date range

**What the range is now, and how it compares with the nonsense you got in week 2:**

Now: 2024-01-01 to 2025-12-30 — a genuine ~2-year span, and 0 rows failed to parse.

Week 2 gave 01-Apr-2024 to 31/12/2024 from `MIN()`/`MAX()` on the raw text column — that was never a real date range, just an alphabetical-sort artifact ("0" sorts low regardless of month). Once `trip_date` is an actual datetime column, `MIN()`/`MAX()` compare chronologically instead of alphabetically, which is why the range only makes sense now.

---

## 4. Tables you wrote back

*Everything now in your group4b schema, with row counts. Power BI reads these next week, so they need to be right.*

| Table name | Rows | What it is |
|---|---|---|
| `trips_clean` | 28,000 | The fact table — one row per trip, deduplicated, dates parsed, fare corrected, driver_id fully resolved. |
| `drivers_clean` | 201 | 200 real drivers plus the synthetic "Unknown Driver" row (`driver_id = -1`) added in section 1. Note: the 200 figure only becomes 201 once the orphan-key fix in this notebook actually runs — confirm this count after your own run. |
| `riders_clean` | 1,000 | Unchanged from raw — riders had no data-quality problems in week 2 (zero orphans, zero missing values). |
| `zones_clean` | 15 | Unchanged from raw — zones had no data-quality problems in week 2. |

---

## 5. Reproducibility check

*A notebook that only works on one laptop, in the order that person happened to click, is not finished. Test it properly before answering this.*

*Runtime → Restart runtime, then Run all. Then have somebody else do the same on their machine.*

**Who else ran it, on what machine, and did they get the same tables?**

To be completed by the group after an actual second run — this needs a real teammate, on their own machine, doing Restart runtime → Run all and comparing their table row counts against section 4 above. Left blank rather than filled with a guess, since this is specifically a check that someone else, not the same person who wrote the code, can reproduce it.

**If it failed the first time, what was wrong and how did you fix it?**

To be completed once the reproducibility check above has actually been run. One likely failure point worth watching for: cell 4 requires typing the group4b password interactively via `getpass()` — if the notebook is run non-interactively (e.g. "Run all" without the runtime pausing for input), that cell can hang or error rather than fail cleanly, which can look like a bug elsewhere in the notebook when the real cause is upstream.

---

## 6. Is it ready for week 4?

*Next week you build a star schema on these tables. Think ahead.*

**Which table will be your fact table, and what does one row represent?**

`trips_clean`. One row = one completed or cancelled ride, with its date, driver, rider, pickup/dropoff zone, distance, duration, status, and fare.

**Which will be your dimensions?**

`drivers_clean`, `riders_clean`, and `zones_clean`. `zones_clean` will need to be modeled as a role-playing dimension, since `trips_clean` has two foreign keys into it — `pickup_zone_id` and `dropoff_zone_id` — and Power BI can only treat one of those as the active relationship at a time (the other has to be invoked explicitly with `USERELATIONSHIP`). A date dimension will also need to be built separately, since `trip_date` is a plain date column, not a ready-made date table.

**Do any columns still need work before the model will hold together?**

`trip_date` needs a surrogate date key (e.g. `YYYYMMDD` as an integer) to join cleanly against a date dimension table — the raw datetime column can join directly, but a proper star schema is easier to build and faster to query with an explicit key. Nothing else is outstanding: `driver_id`, `rider_id`, `pickup_zone_id` and `dropoff_zone_id` are all fully resolved with no remaining orphans.

**Anything you deliberately left alone, and why:**

The 1,438 missing fares stay as NULL rather than filled — this is deliberate, not unfinished. A revenue measure written as `SUM(fare)` will correctly skip them in Power BI, which is the behaviour we want; filling them with 0 or an estimate would have been the wrong kind of "done." We also left the trips predating a rider's signup date or a driver's join date untouched (flagged in week 2) — that inconsistency doesn't affect the revenue/cancellation question this project answers, and fixing it would mean discarding real trip rows to satisfy a field the model doesn't use.

---

## 7. Questions for the weekly call

- Is the 90000-block of orphan `driver_id`s meant to represent something specific (e.g. drivers removed from the roster), or should we treat it as unlabelled synthetic noise?
- For the 1,438 trips with no usable fare, is there a reference table or business rule we're missing that would let us reconstruct the real fare, or is NULL-and-exclude the right long-term call for the week 4 model too?

---

> **Before you submit this**
> Notebook committed to `notebooks/` and runs from a fresh runtime. Clean tables visible in your schema. Every decision above has a reason attached. No password anywhere in the notebook. Cleaning approaches can be discussed openly with group4a. Your decisions and your reasoning stay yours.
