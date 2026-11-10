/* =====================================================================
   Airbnb Market Intelligence - SQL Server preparation and analysis
   AnalystLab Africa, Week 1, Track A (Data Analytics)
   Author: Babatunde Omotayo

   Run top to bottom in SSMS. Before running, import Listings.csv and
   Reviews.csv into tables dbo.Listings and dbo.Reviews with the Import
   Flat File wizard, setting every column to nvarchar(MAX) with nulls
   allowed (see README, "How to reproduce").
   ===================================================================== */

-- 0. Database -----------------------------------------------------------
-- CREATE DATABASE AirbnbMarket;   -- run once, before importing the CSVs
USE AirbnbMarket;
GO

/* =====================================================================
   1. Import check: row counts must match the brief
   ===================================================================== */
SELECT COUNT(*) AS listings_rows FROM Listings;   -- expect 279,712
SELECT COUNT(*) AS reviews_rows  FROM Reviews;    -- expect 5,373,143

/* =====================================================================
   2. Data quality checks (raw tables, all columns still text)
   ===================================================================== */

-- 2.1 Is listing_id unique? (total rows = distinct IDs means a valid primary key)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT listing_id) AS unique_ids
FROM Listings;

-- 2.2 How many review_id values appear more than once? (expect 160)
SELECT COUNT(*) AS repeated_ids
FROM (SELECT review_id FROM Reviews GROUP BY review_id HAVING COUNT(*) > 1) d;

-- 2.3 Inspect the repeated rows (320 rows: same review, date and reviewer on two listings)
SELECT *
FROM Reviews
WHERE review_id IN (SELECT review_id FROM Reviews GROUP BY review_id HAVING COUNT(*) > 1)
ORDER BY review_id;

-- 2.4 Is listing_id + review_id unique? (composite key check)
SELECT COUNT(*) AS total,
       COUNT(DISTINCT CONCAT(listing_id, '|', review_id)) AS unique_pairs
FROM Reviews;

-- 2.5 Reviews pointing to a listing that does not exist (expect 0)
SELECT COUNT(*) AS orphan_reviews
FROM Reviews r
LEFT JOIN Listings l ON r.listing_id = l.listing_id
WHERE l.listing_id IS NULL;

-- 2.6 Listings with no reviews at all (result: 86,156)
SELECT COUNT(*) AS listings_without_reviews
FROM Listings l
WHERE NOT EXISTS (SELECT 1 FROM Reviews r WHERE r.listing_id = l.listing_id);

-- 2.7 Missing values in key columns (empty text counted as blank)
SELECT
    SUM(CASE WHEN NULLIF(district, '')             IS NULL THEN 1 ELSE 0 END) AS missing_district,
    SUM(CASE WHEN NULLIF(bedrooms, '')             IS NULL THEN 1 ELSE 0 END) AS missing_bedrooms,
    SUM(CASE WHEN NULLIF(host_response_rate, '')   IS NULL THEN 1 ELSE 0 END) AS missing_response_rate,
    SUM(CASE WHEN NULLIF(host_acceptance_rate, '') IS NULL THEN 1 ELSE 0 END) AS missing_acceptance_rate,
    SUM(CASE WHEN NULLIF(review_scores_rating, '') IS NULL THEN 1 ELSE 0 END) AS missing_rating
FROM Listings;

-- 2.8 Zero or negative prices per city (result: 113 listings in 7 cities)
SELECT city, COUNT(*) AS zero_or_negative
FROM Listings
WHERE TRY_CAST(price AS DECIMAL(18,2)) <= 0
GROUP BY city;

-- 2.9 Prices that are blank or not a number (result: 0 rows)
SELECT city, COUNT(*) AS blank_or_not_number
FROM Listings
WHERE TRY_CAST(price AS DECIMAL(18,2)) IS NULL
GROUP BY city;

-- 2.10 Lowest and highest price per city (local currency; shows extreme outliers)
SELECT city,
       MIN(TRY_CAST(price AS DECIMAL(18,2))) AS lowest_price,
       MAX(TRY_CAST(price AS DECIMAL(18,2))) AS highest_price
FROM Listings
GROUP BY city;

-- 2.11 How values are stored, before converting types
SELECT TOP 10
    host_since, host_response_rate, host_acceptance_rate,
    host_is_superhost, bedrooms, accommodates,
    review_scores_rating, instant_bookable
FROM Listings;

SELECT TOP 10 host_response_rate, host_acceptance_rate
FROM Listings
WHERE host_response_rate IS NOT NULL;   -- rates are stored as decimals 0 to 1

/* =====================================================================
   3. Clean tables with proper data types (raw tables stay unchanged)
   ===================================================================== */

-- 3.1 Listings_clean: typed columns, t/f flags as 1/0, price_valid flag
DROP TABLE IF EXISTS Listings_clean;

SELECT
    TRY_CAST(listing_id AS BIGINT)                  AS listing_id,
    name,
    TRY_CAST(host_id AS BIGINT)                     AS host_id,
    TRY_CAST(host_since AS DATE)                    AS host_since,
    TRY_CAST(host_response_rate AS DECIMAL(5,2))    AS host_response_rate,
    TRY_CAST(host_acceptance_rate AS DECIMAL(5,2))  AS host_acceptance_rate,
    CASE host_is_superhost WHEN 't' THEN 1 WHEN 'f' THEN 0 END AS is_superhost,
    TRY_CAST(host_total_listings_count AS INT)      AS host_total_listings_count,
    neighbourhood,
    district,
    city,
    property_type,
    room_type,
    TRY_CAST(accommodates AS INT)                   AS accommodates,
    TRY_CAST(bedrooms AS INT)                       AS bedrooms,
    TRY_CAST(price AS DECIMAL(18,2))                AS price,
    CASE WHEN TRY_CAST(price AS DECIMAL(18,2)) > 0 THEN 1 ELSE 0 END AS price_valid,
    TRY_CAST(minimum_nights AS INT)                 AS minimum_nights,
    TRY_CAST(maximum_nights AS INT)                 AS maximum_nights,
    TRY_CAST(review_scores_rating AS DECIMAL(5,2))  AS review_scores_rating,
    CASE instant_bookable WHEN 't' THEN 1 WHEN 'f' THEN 0 END AS instant_bookable
INTO Listings_clean
FROM Listings;

-- Checks: 279,712 rows; 279,599 valid prices (279,712 minus 113)
SELECT COUNT(*) AS rows_clean FROM Listings_clean;
SELECT SUM(price_valid) AS valid_prices FROM Listings_clean;

-- 3.2 Reviews_clean: IDs as BIGINT, date as DATE
DROP TABLE IF EXISTS Reviews_clean;

SELECT
    TRY_CAST(listing_id AS BIGINT)  AS listing_id,
    TRY_CAST(review_id AS BIGINT)   AS review_id,
    TRY_CAST([date] AS DATE)        AS review_date,   -- [date] in brackets: date is a SQL keyword
    TRY_CAST(reviewer_id AS BIGINT) AS reviewer_id
INTO Reviews_clean
FROM Reviews;

SELECT COUNT(*) AS rows_clean FROM Reviews_clean;   -- expect 5,373,143
GO

/* =====================================================================
   4. Summary views for Power BI (so it never loads 5.3M review rows)
   ===================================================================== */

-- 4.1 Review count per listing (193,556 rows = listings with at least one review)
CREATE OR ALTER VIEW vw_reviews_per_listing AS
SELECT listing_id, COUNT(*) AS Reviews_count
FROM Reviews_clean
GROUP BY listing_id;
GO

-- 4.2 Review count per city per month (joins each review to its listing's city)
CREATE OR ALTER VIEW vw_reviews_per_month_city AS
SELECT
    l.city,
    DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1) AS review_month,
    COUNT(*) AS review_count
FROM Reviews_clean r
JOIN Listings_clean l ON r.listing_id = l.listing_id
GROUP BY l.city, DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1);
GO

-- Checks: views return rows, and monthly piles add back up to every review
SELECT TOP 10 * FROM vw_reviews_per_listing;
SELECT TOP 10 * FROM vw_reviews_per_month_city;
SELECT SUM(review_count) AS total_reviews FROM vw_reviews_per_month_city;   -- expect 5,373,143

/* =====================================================================
   5. Business questions (Track A, Task 2)
   ===================================================================== */

-- Q1 Which cities have the most listings?
SELECT city, COUNT(*) AS listings
FROM Listings_clean
GROUP BY city
ORDER BY listings DESC;

-- Q2 How are listings distributed across room types?
SELECT room_type, COUNT(*) AS listings
FROM Listings_clean
GROUP BY room_type
ORDER BY listings DESC;

-- Q3 Which property types are most common? (top 10)
SELECT TOP 10 property_type, COUNT(*) AS listings
FROM Listings_clean
GROUP BY property_type
ORDER BY listings DESC;

-- Q4 How do prices vary across cities, within each local currency?
--    Median (PERCENTILE_CONT 0.5) vs average; zero prices excluded
SELECT DISTINCT
    city,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER (PARTITION BY city) AS median_price,
    AVG(price) OVER (PARTITION BY city) AS average_price
FROM Listings_clean
WHERE price_valid = 1;

-- Q7 How many reviews are recorded per city? (per listing: see vw_reviews_per_listing)
SELECT city, SUM(review_count) AS review_records
FROM vw_reviews_per_month_city
GROUP BY city
ORDER BY review_records DESC;

-- Q8 How does review activity change over time? (data runs 16 Nov 2008 to 1 Mar 2021)
SELECT YEAR(review_month) AS review_year, SUM(review_count) AS review_records
FROM vw_reviews_per_month_city
GROUP BY YEAR(review_month)
ORDER BY review_year;

SELECT MIN(review_date) AS first_review, MAX(review_date) AS last_review
FROM Reviews_clean;

-- Q9 How do host response and acceptance rates vary across cities?
--    AVG skips blanks, so these describe hosts who report a rate
SELECT city,
       AVG(host_response_rate)   AS avg_host_response_rate,
       AVG(host_acceptance_rate) AS avg_host_acceptance_rate
FROM Listings_clean
GROUP BY city
ORDER BY avg_host_response_rate DESC;

/* =====================================================================
   6. Validation against the dashboard
   ===================================================================== */

-- 6.1 Reporting hosts per city: counts sum to 150,930 (279,712 - 128,782 missing);
--     the count-weighted average is 86.59%, matching the Avg Response Rate card
SELECT city,
       COUNT(host_response_rate) AS reported,
       AVG(host_response_rate)   AS avg_rate
FROM Listings_clean
GROUP BY city;
