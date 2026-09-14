-- =====================================================================
--  WEEK 2 - PROFILING QUERY PACK
--  Domain: Rides
--  Schema: raw_rides
--
--  Your question this term:
--    Which pickup zones generate the most revenue, and where are cancellations concentrated?
--
--  HOW TO USE THIS FILE
--  Work through it top to bottom. Run each query, look at the result,
--  and write down what you find. By the end you should be able to
--  answer: what is in this data, and what is wrong with it?
--
--  Do not skip to the interesting queries at the bottom. The whole
--  point of week 2 is finding the problems BEFORE you build on them.
--
--  Write your findings in a file called data_quality_notes.md and
--  commit it. Week 3 depends on it.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. WHAT IS HERE?
--    Always start by finding out what tables you have and how big.
-- ---------------------------------------------------------------------

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'raw_rides'
ORDER BY table_name;

-- Row counts, one per table.
SELECT 'trips' AS table_name, count(*) AS rows FROM raw_rides.trips
UNION ALL
SELECT 'drivers' AS table_name, count(*) AS rows FROM raw_rides.drivers
UNION ALL
SELECT 'riders' AS table_name, count(*) AS rows FROM raw_rides.riders
UNION ALL
SELECT 'zones' AS table_name, count(*) AS rows FROM raw_rides.zones
ORDER BY table_name;


-- ---------------------------------------------------------------------
-- 2. LOOK AT THE DATA
--    Never analyse a table you have not actually looked at.
-- ---------------------------------------------------------------------

SELECT * FROM raw_rides.trips LIMIT 20;
SELECT * FROM raw_rides.drivers LIMIT 10;
SELECT * FROM raw_rides.riders LIMIT 10;
SELECT * FROM raw_rides.zones LIMIT 10;

-- Column names and declared types.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'raw_rides'
ORDER BY table_name, ordinal_position;

-- NOTE: the date columns are stored as TEXT, not DATE. That is not a
-- mistake in the setup - the source data has mixed formats and would
-- not load as dates. Converting them is your job in week 3.


-- ---------------------------------------------------------------------
-- 3. MISSING VALUES
--    Which columns have gaps, and how big are they?
-- ---------------------------------------------------------------------

SELECT
    count(*)                                        AS total_rows,
    count(*) FILTER (WHERE trip_date IS NULL)             AS missing_trip_date,
    count(*) FILTER (WHERE status IS NULL)                AS missing_status,
    count(*) FILTER (WHERE fare IS NULL)                  AS missing_fare,
    count(*) FILTER (WHERE driver_id IS NULL)             AS missing_driver_id,
    count(*) FILTER (WHERE rider_id IS NULL)              AS missing_rider_id,
    count(*) FILTER (WHERE pickup_zone_id IS NULL)        AS missing_pickup_zone_id
FROM raw_rides.trips;

-- Ask yourself: is a NULL here a data-entry failure, or does it mean
-- something real? The answer changes how you handle it.


-- ---------------------------------------------------------------------
-- 4. DUPLICATES
--    Exact duplicate rows are usually a loading or export error.
-- ---------------------------------------------------------------------

-- Is the primary key actually unique?
SELECT count(*) AS total_rows,
       count(DISTINCT trip_id) AS distinct_ids,
       count(*) - count(DISTINCT trip_id) AS extra_rows
FROM raw_rides.trips;

-- Show the offending rows so you can see what they look like.
SELECT trip_id, count(*) AS times_repeated
FROM raw_rides.trips
GROUP BY trip_id
HAVING count(*) > 1
ORDER BY times_repeated DESC, trip_id
LIMIT 20;


-- ---------------------------------------------------------------------
-- 5. INCONSISTENT CATEGORIES
--    The same value written several different ways will split your
--    totals in Power BI. This is the classic silent error.
-- ---------------------------------------------------------------------

SELECT status, count(*) AS rows
FROM raw_rides.trips
GROUP BY status
ORDER BY status;

-- Now compare with the cleaned-up version. How many real categories
-- are there actually?
SELECT upper(trim(status)) AS cleaned, count(*) AS rows
FROM raw_rides.trips
GROUP BY cleaned
ORDER BY rows DESC;

-- Check the other text columns the same way before you assume they
-- are fine.


-- ---------------------------------------------------------------------
-- 6. DATE FORMATS
--    The date column is text and does not use one format.
-- ---------------------------------------------------------------------

-- Group by shape to see which formats are present.
SELECT
    CASE
        WHEN trip_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 'YYYY-MM-DD'
        WHEN trip_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 'DD/MM/YYYY'
        WHEN trip_date ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN 'YYYY/MM/DD'
        WHEN trip_date ~ '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN 'DD-Mon-YYYY'
        ELSE 'OTHER - investigate'
    END AS date_format,
    count(*) AS rows
FROM raw_rides.trips
GROUP BY date_format
ORDER BY rows DESC;

-- Careful: 03/04/2025 is ambiguous. Is it 3 April or 4 March?
-- Decide, write your decision down, and apply it consistently.


-- ---------------------------------------------------------------------
-- 7. IMPOSSIBLE VALUES
--    Values that are technically valid numbers but cannot be real.
-- ---------------------------------------------------------------------

SELECT count(*) AS zero_fare_completed_trips
FROM raw_rides.trips
WHERE fare = 0;

SELECT *
FROM raw_rides.trips
WHERE fare = 0
LIMIT 15;

-- Also check the range of every numeric column. Anything at the
-- extremes worth questioning?
SELECT
    min(fare) AS min_fare,
    max(fare) AS max_fare,
    round(avg(fare), 2) AS avg_fare
FROM raw_rides.trips;


-- ---------------------------------------------------------------------
-- 8. BROKEN RELATIONSHIPS
--    Fact rows pointing at dimension records that do not exist.
--    These will silently disappear from your Power BI model.
-- ---------------------------------------------------------------------

-- driver_id without a matching row in drivers
SELECT count(*) AS orphan_driver_id
FROM raw_rides.trips f
LEFT JOIN raw_rides.drivers d ON f.driver_id = d.driver_id
WHERE d.driver_id IS NULL;

-- rider_id without a matching row in riders
SELECT count(*) AS orphan_rider_id
FROM raw_rides.trips f
LEFT JOIN raw_rides.riders d ON f.rider_id = d.rider_id
WHERE d.rider_id IS NULL;

-- pickup_zone_id without a matching row in zones
SELECT count(*) AS orphan_pickup_zone_id
FROM raw_rides.trips f
LEFT JOIN raw_rides.zones d ON f.pickup_zone_id = d.zone_id
WHERE d.zone_id IS NULL;

-- If you find orphans: do you drop those rows, or keep them with an
-- "Unknown" placeholder? Both are defensible. Document which you chose.


-- ---------------------------------------------------------------------
-- 9. TIME COVERAGE
--    Does the data actually cover the period you think it does?
-- ---------------------------------------------------------------------

SELECT
    min(trip_date) AS earliest_text,
    max(trip_date) AS latest_text
FROM raw_rides.trips;

-- That result is misleading, because text sorts alphabetically, not
-- chronologically. Work out why, then check the real range once you
-- have parsed the dates in week 3. This is a good thing to note down.


-- ---------------------------------------------------------------------
-- 10. YOUR FIRST REAL ANALYSIS
--     Only meaningful once you know what is broken above.
-- ---------------------------------------------------------------------

-- Volume and value by zone_name.
SELECT
    d.zone_name,
    count(*)                       AS rows,
    round(sum(f.fare), 2)      AS total_fare,
    round(avg(f.fare), 2)      AS avg_fare
FROM raw_rides.trips f
JOIN raw_rides.zones d ON f.pickup_zone_id = d.zone_id
GROUP BY d.zone_name
ORDER BY total_fare DESC;

-- The same thing by month. substring() is a temporary shortcut that
-- only works for the rows already in YYYY-MM-DD form - which is
-- exactly why week 3 exists.
SELECT
    substring(trip_date FROM 1 FOR 7) AS month,
    count(*)                           AS rows,
    round(sum(fare), 2)            AS total_fare
FROM raw_rides.trips
WHERE trip_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
GROUP BY month
ORDER BY month;

-- How many rows did that WHERE clause silently throw away?
-- Check. Then think about what that would have done to a dashboard.


-- ---------------------------------------------------------------------
-- 11. THE FULL JOIN
--     Everything connected. This is roughly the shape your fact table
--     will take in week 4.
-- ---------------------------------------------------------------------

SELECT
    f.trip_id,
    f.trip_date,
    f.fare,
    drivers.*,
    riders.*,
    zones.*
FROM raw_rides.trips f
JOIN raw_rides.drivers AS drivers ON f.driver_id = drivers.driver_id
JOIN raw_rides.riders AS riders ON f.rider_id = riders.rider_id
JOIN raw_rides.zones AS zones ON f.pickup_zone_id = zones.zone_id
LIMIT 25;


-- =====================================================================
--  BEFORE YOU FINISH WEEK 2
--
--  Your data_quality_notes.md should answer:
--    1. How many rows in each table?
--    2. Which columns have missing values, and how many?
--    3. How many duplicate rows, and in which table?
--    4. How many real categories are hiding behind the messy ones?
--    5. Which date formats are present?
--    6. How many impossible values, and what will you do about them?
--    7. How many orphan keys, and what will you do about them?
--
--  Commit it. Week 3 starts from this file, not from memory.
-- =====================================================================
