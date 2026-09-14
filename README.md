<<<<<<< HEAD
# Accra Ride-Hailing — Revenue & Cancellation Analysis

**Question:** Which pickup zones generate the most revenue, and where are
cancellations concentrated?

**Short answer:** Revenue is genuinely uneven across zones — Teshie, Lapaz
and Airport City lead, about 10% ahead of the lowest zone (Adenta), and
the ranking doesn't track zone class (Central/Suburban/Peripheral)
cleanly. Cancellations, by contrast, are **not** concentrated anywhere:
the rate sits in a narrow 13–15% band across every zone, every day of the
week, and every month in the two-year window. See
`dashboard/index.html` for the visual answer and
`docs/data_quality_notes.md` for how the underlying data was cleaned to
get there.

## What's in this repo

```
sql/01_profiling_queries.sql   SQL used to find every data quality problem below
docs/data_quality_notes.md     What was wrong with the data, how big each problem was, and the fix
python/clean_data.py           Cleans the four raw extracts, writes a star schema to data/clean/
data/raw/                      Original CSVs, untouched
data/clean/                    Cleaned fact + dimension tables, ready for Power BI
powerbi/model_setup.md         Step-by-step: build the star schema and relationships in Power BI Desktop
powerbi/dax_measures.md        Every DAX measure used, with the reasoning behind the fare/status logic
dashboard/index.html           A working preview of the dashboard (open directly in a browser)
```

There is no `.pbix` file in this repo. The analysis environment this was
built in doesn't have Power BI Desktop installed, so it can't produce
that binary directly — everything Power BI needs is here in the exact
shape it needs it (`data/clean/*.csv` + `powerbi/model_setup.md` +
`powerbi/dax_measures.md`), and following `model_setup.md` end to end
takes about 10 minutes of clicking, no further analysis required.
`dashboard/index.html` is a standalone working preview of the same
answer, built directly from the cleaned data, so there's something to
look at without Power BI installed at all.

## How to reproduce this from scratch

1. **Profile.** Load the four raw CSVs into SQLite with every column
   typed as TEXT (so bad values surface instead of getting silently
   coerced), then run `sql/01_profiling_queries.sql` top to bottom.
   Findings are written up in `docs/data_quality_notes.md`.
2. **Clean.** `cd python && python3 clean_data.py`. Reads
   `data/raw/*.csv`, writes `data/clean/{fact_trips,dim_driver,dim_rider,
   dim_zone,dim_date}.csv`. Each fix is explained in
   `data_quality_notes.md`, not just applied silently — the script's
   comments point back to the relevant section.
3. **Model.** Follow `powerbi/model_setup.md` to load the five clean CSVs
   into Power BI Desktop and wire up the star schema (one fact table,
   four dimensions, `dim_zone` used twice as a role-playing dimension for
   pickup vs dropoff).
4. **Measure and build.** Paste the DAX in `powerbi/dax_measures.md` into
   a measures table, then build the visuals described at the end of
   `model_setup.md`.
5. **Iterate.** The "things the first draft usually exposes" section in
   `model_setup.md` covers the two mistakes most likely to show up
   (revenue chart sorted wrong, cancellation rate that won't slice by
   zone class) and how to fix each.

## Data quality, in brief

Four tables, four different problems, all documented in full in
`docs/data_quality_notes.md`:

| Table | Problem | Scale |
|---|---|---|
| trips | 112 exact duplicate rows | dropped, 28,112 → 28,000 |
| trips | status/date columns in 12 spellings / 4 date formats | standardised |
| trips | 1,444 trips with missing or not-credible ($0 on a completed ride) fares | excluded from revenue, not zeroed |
| trips | 70 trips pointing at a driver_id that doesn't exist in drivers.csv | repointed to a surrogate "Unknown driver" row |
| drivers | vehicle_type in 10 spellings for 3 categories | standardised |
| drivers | 17 pairs of drivers sharing a name | checked — different people, kept as-is |
| riders | payment_preference in 12 spellings for 3 categories | standardised |
| zones | — | clean, no changes |

## Caveat on the cancellation finding

This isn't a case of "the chart needs more filters to find the
pattern" — the cancellation rate was checked by zone, by zone class, by
day of week, and by month, and it's flat on every cut (see the bottom of
`docs/data_quality_notes.md` and the companion checks run alongside
`clean_data.py`). Reporting a flat result honestly is more useful to an
operations lead than manufacturing a zone-level story that isn't in the
data — it means the fix for cancellations probably isn't "move drivers,"
it's something that touches the whole operation evenly (driver supply at
busy hours, payment friction, app reliability), which is worth
investigating separately from this zone-level dataset.
=======
#Data Analytic Intenship
>>>>>>> 0d3bade9b174aa45d0d276ad04d8a4ac9e58fe61
