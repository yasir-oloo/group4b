# Project workflow — group4b

**Domain:** Ride-hailing trips &nbsp;|&nbsp; **Paired with:** group4a &nbsp;|&nbsp; **Reads:** `raw_rides` &nbsp;|&nbsp; **Writes:** `group4b`

> **Your question**  
> Which pickup zones generate the most revenue, and where are cancellations concentrated?

---

## How to use this file

Keep this at the top level of your repository as `WORKFLOW.md`. Tick boxes as you finish things by changing `- [ ]` to `- [x]`, then commit. GitHub renders the ticks, so anyone can see where you are without asking.

Two rules that make this work:

- **Tick it when it is genuinely done**, not when you have started it. A checklist everyone has learned to distrust is worse than no checklist.
- **Put your initials next to what you did** — `- [x] Profiled the sales table (KM)`. This is how individual contribution becomes visible.

Each week has a **Deliverable** and a **Done when** line. If you cannot honestly say the Done when is true, the week is not finished — say so on the call rather than ticking it anyway.

---

## Week 0 — Setup (before week 1 starts)

**Goal:** everyone can reach the database and the repository.

### Everyone individually

- [ ] Created a GitHub account and sent my username to the group lead
- [ ] Installed Power BI Desktop (Windows only — flag it now if you are on Mac or Linux)
- [ ] Installed a SQL client (DBeaver recommended)
- [ ] Installed Git and ran `git config --global user.name` and `user.email`
- [ ] Connected to the database and ran the three checks on my access sheet
- [ ] Confirmed I can reach `raw_rides` and write to `group4b`

### As a group

- [ ] Created the group repository on GitHub and added every member
- [ ] Everyone has cloned it and made at least one commit
- [ ] Agreed a communication channel and a weekly working time
- [ ] Agreed who leads each phase (see the rota below)
- [ ] Read the project brief together — all of it, aloud if necessary

**Deliverable:** a repository with every member's name in the commit history.  
**Done when:** every single person has connected to the database on their own machine. Not the group lead on everyone's behalf.

### Phase leads

A different person leads each phase, so nobody specialises by accident and everyone touches every tool. Fill this in during week 0.

| Phase | Weeks | Lead |
|---|---|---|
| Scope | 1 | |
| SQL profiling | 2 | |
| Python cleaning | 3 | |
| Data modelling | 4 | |
| Dashboard build | 5–6 | |
| Presentation | 7–8 | |

The lead is not the only person doing the work. They are the person who makes sure it happens and who speaks for the group on that week's call.

---

## Week 1 — Scope

**Goal:** agree exactly what you are answering before touching data. Groups that skip this spend week 6 arguing about what they were supposed to build.

- [ ] Re-read the question at the top of this file. Write down, in your own words, what it is actually asking
- [ ] Listed the specific sub-questions you will need to answer to answer the main one
- [ ] Decided what "done" looks like — what would a finished dashboard show?
- [ ] Identified who the audience is and what decision they would make with your answer
- [ ] Listed what is **out of scope** — things you are deliberately not doing
- [ ] Looked at each of your four tables in the SQL client, just to see what is there
- [ ] Written `scope.md` and committed it

**Deliverable:** `scope.md` — one page. Your question, your sub-questions, success criteria, out of scope, phase leads.  
**Done when:** every group member could explain the project to a stranger in two sentences.

<details><summary>What good scope looks like</summary>

Bad: "Analyse rides data."

Good: "Which pickup zones generate the most revenue, and where are cancellations concentrated? We will answer this by comparing zone_name across the full 2024–2025 period, broken down by month. Success means a stakeholder can identify the top three and the bottom three at a glance and see how each has moved over time. We are not modelling or forecasting."

</details>

---

## Week 2 — Profile the data in SQL

**Goal:** find out what is in the data and what is wrong with it. Everything after this depends on this week being done honestly.

Work through `week2_profiling_rides.sql` from top to bottom. Do not skip to the interesting queries.

### The seven things you must be able to answer

- [ ] How many rows are in each of the four tables?
- [ ] Which columns have missing values, and how many in each?
- [ ] How many duplicate rows are there, and in which table?
- [ ] How many *real* categories are hiding behind the messy `status` values?
- [ ] Which date formats appear in `trip_date`, and how many rows use each?
- [ ] How many impossible values are there — zero fares on completed trips?
- [ ] How many orphan keys — driver_id values with no matching driver?

### Also

- [ ] Worked out how the four tables join together — which column links to which
- [ ] Noticed what happens when you sort the date column as text (query 9). Understood why
- [ ] Ran the monthly rollup (query 10) and worked out how many rows it silently discards
- [ ] Decided, as a group, what you will do about each problem — and written down why
- [ ] Committed your queries to `sql/`
- [ ] Written and committed `data_quality_notes.md`

**Deliverable:** `data_quality_notes.md` answering all seven questions with numbers, plus your `.sql` files.  
**Done when:** you can state the seven numbers from memory. A group that says "the data looks fine" has not done this week.

> Share data-quality findings openly with group4a. If you find a broken column, say so — everyone hits the same potholes. Your **analysis** stays yours.

---

## Week 3 — Clean in Python

**Goal:** turn the raw data into something you can build on, and write it back to your own schema.

### In Colab

- [ ] Connected to the database from a notebook (sqlalchemy + psycopg2)
- [ ] Pulled `raw_rides.trips` and the three dimension tables into pandas
- [ ] Parsed `trip_date` into a real date type, handling all four formats
- [ ] Decided and documented how you read ambiguous dates like `03/04/2025`
- [ ] Standardised `status` — trimmed whitespace, fixed casing
- [ ] Checked every other text column for the same problem
- [ ] Removed duplicate rows
- [ ] Handled missing values — decided per column whether to drop, fill, or keep as "Unknown"
- [ ] Dealt with the impossible values (zero fares on completed trips)
- [ ] Dealt with the orphan keys — dropped, or kept with an "Unknown" placeholder
- [ ] Re-ran your week 2 profiling checks on the cleaned data to prove the problems are gone

### Writing back

- [ ] Wrote cleaned tables into `group4b` (e.g. `group4b.trips_clean`)
- [ ] Confirmed the row counts are what you expect after cleaning
- [ ] Committed the notebook to `notebooks/`
- [ ] Updated `data_quality_notes.md` with what you decided and why

**Deliverable:** a committed notebook, plus cleaned tables in `group4b`.  
**Done when:** someone else in your group can re-run your notebook start to finish and get the same tables. If it only works on one laptop, it is not done.

> **Do not download cleaned CSVs and work from them.** The database is the single source of truth. Files on laptops get out of sync and somebody always ends up analysing an old version.

---

## Week 4 — Build the data model

**Goal:** a star schema in Power BI. This is the part employers probe in interviews, and the part most beginners skip.

- [ ] Connected Power BI Desktop to `group4b` (PostgreSQL connector)
- [ ] Loaded your cleaned fact table and your dimension tables
- [ ] Built a **date table** — one row per day covering your full range
- [ ] Marked it as a date table in Power BI
- [ ] Added year, quarter, month name, month number and day-of-week columns to it
- [ ] Created relationships from the fact table to each dimension
- [ ] Checked every relationship is one-to-many, single direction, from dimension to fact
- [ ] Confirmed no relationship is many-to-many
- [ ] Looked at the Model view — it should look like a star, not a chain or a web
- [ ] Renamed columns to something a non-analyst would understand
- [ ] Hidden the raw key columns from the report view
- [ ] Committed the `.pbix` to `dashboard/`

**Deliverable:** a `.pbix` with a working model and **no visuals yet**.  
**Done when:** the Model view shows one fact table in the middle with three dimensions and a date table radiating out from it.

<details><summary>Why not just use one flat table?</summary>

Because it stops working the moment you want to slice by something that is not in the fact table, and because every filter you add gets slower. A star schema is the standard for a reason, and "I built a star schema" is a sentence that gets you through interviews. Flat tables are the single most common thing that marks out a beginner portfolio.

</details>

---

## Week 5 — Measures and first draft

**Goal:** working DAX and an ugly dashboard. Ugly is expected — feedback matters more than polish at this stage.

### Measures

- [ ] Total fares
- [ ] Completion rate
- [ ] Average fare per zone
- [ ] Revenue per driver
- [ ] Cancellations by zone
- [ ] Every measure has a clear name a non-analyst would understand
- [ ] Tested each measure by slicing it by a dimension — the numbers still make sense

### First dashboard

- [ ] One page, laid out roughly
- [ ] A time trend using your date table
- [ ] A breakdown by zone_name
- [ ] At least one slicer or filter
- [ ] Checked the totals against a SQL query — they must match
- [ ] Committed the `.pbix`

**Deliverable:** an ugly but functional dashboard.  
**Done when:** the numbers on screen match what SQL says. If they do not, the model is wrong — fix it now, not in week 7.

---

## Week 6 — Iterate

**Goal:** fix what the draft exposed. Usually a missing dimension, or a measure that does not slice correctly.

- [ ] Collected feedback from the week 5 call and written it down
- [ ] Shown the draft to someone outside your group and watched them try to read it
- [ ] Fixed whatever the draft revealed about the model
- [ ] Added the pages you actually need (suggested: Revenue overview, Zone comparison, Cancellation analysis)
- [ ] Made sure every page answers part of your question — deleted anything that does not
- [ ] Added tooltips explaining anything non-obvious
- [ ] Checked it reads left-to-right, top-to-bottom, most important first
- [ ] Tested every slicer and cross-filter interaction
- [ ] Committed

**Deliverable:** a near-final dashboard.  
**Done when:** someone who has never seen it can tell you what it says without you narrating.

> The test that matters: hand your laptop to someone and say nothing. If they ask "what am I looking at?", you are not done.

---

## Week 7 — Freeze and rehearse

**Goal:** stop building. Start finishing.

**Scope is frozen from the start of this week.** No new pages, no new measures, no new ideas. Write them in a "next steps" list instead — that list is worth marks in the presentation.

### Polish

- [ ] Consistent colours, fonts and number formatting across every page
- [ ] Every axis and legend labelled
- [ ] No default titles left saying things like "Sum of fare by zone_name"
- [ ] Dashboard loads and responds without lag

### Documentation

- [ ] `README.md` — what the project is, what question it answers, how to run it, what you found
- [ ] Repository tidy: `sql/`, `notebooks/`, `dashboard/`, `presentation/`
- [ ] No passwords or connection strings anywhere in the repository
- [ ] `data_quality_notes.md` complete and final
- [ ] A "what we would do next" list

### Presentation

- [ ] Slides drafted — question, data, what you found, what you would do next
- [ ] Decided who speaks when. Everyone speaks
- [ ] Rehearsed with a timer. Ten minutes means ten
- [ ] Rehearsed once more after cutting whatever ran over
- [ ] Prepared for the obvious questions: why did you clean it that way, why that model, what surprised you

**Deliverable:** frozen `.pbix`, complete repository, rehearsed demo.  
**Done when:** you could present tomorrow with no further work.

---

## Week 8 — Submit and present

- [ ] Final `.pbix` committed
- [ ] Repository link submitted
- [ ] Presentation delivered
- [ ] Every group member has commits under their own name
- [ ] Repository made public (or access shared) so you can show it to employers

**Done when:** you could send the repository link to an employer today and be glad they clicked it.

---

## Quick reference

| | |
|---|---|
| Host | `internship-db.coh86gwewtxb.us-east-1.rds.amazonaws.com` |
| Port | `5432` |
| Database | `internship` |
| Username | `group4b` |
| Read from | `raw_rides` |
| Write to | `group4b` |
| Fact table | `raw_rides.trips` — 28,112 rows, one trip |
| Dimensions | drivers (200), riders (1,000), zones (15) |

**Every week:** bring something visible to the call. A query, a chart, a thing that broke. A progress update with nothing to show does not count.

