CREATE database AirbnbMarket;
Select * from dbo.Reviews

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT listing_id) AS unique_ids FROM Listings;

SELECT COUNT(*) AS repeated_ids
FROM (SELECT review_id FROM Reviews GROUP BY review_id HAVING COUNT(*) > 1) d;

SELECT * FROM Reviews
WHERE review_id IN (SELECT review_id FROM Reviews GROUP BY review_id HAVING COUNT(*) > 1)
ORDER BY review_id;

SELECT COUNT(*) AS total,
       COUNT(DISTINCT CONCAT(listing_id, '|', review_id)) AS unique_pairs
FROM Reviews;

SELECT COUNT(*) AS orphan_reviews
FROM Reviews r
LEFT JOIN Listings l ON r.listing_id = l.listing_id
WHERE l.listing_id IS NULL;

SELECT COUNT(*) AS listings_without_reviews
FROM Listings l
WHERE NOT EXISTS (SELECT 1 FROM Reviews r WHERE r.listing_id = l.listing_id);

SELECT
  SUM(CASE WHEN NULLIF(district,'') IS NULL THEN 1 ELSE 0 END) AS missing_district,
  SUM(CASE WHEN NULLIF(bedrooms,'') IS NULL THEN 1 ELSE 0 END) AS missing_bedrooms,
  SUM(CASE WHEN NULLIF(host_response_rate,'') IS NULL THEN 1 ELSE 0 END) AS missing_response_rate,
  SUM(CASE WHEN NULLIF(host_acceptance_rate,'') IS NULL THEN 1 ELSE 0 END) AS missing_acceptance_rate,
  SUM(CASE WHEN NULLIF(review_scores_rating,'') IS NULL THEN 1 ELSE 0 END) AS missing_rating
FROM Listings;

SELECT city, COUNT(*) AS zero_or_negative
FROM Listings
WHERE TRY_CAST(price AS DECIMAL(18,2)) <= 0
GROUP BY city;

SELECT  city, COUNT (*) As Blank_or_not_number 
FROM listings
WHERE TRY_CAST (price As DECIMAL (18,2)) IS NULL
GROUP BY city;

SELECT city,
       MIN(TRY_CAST(price AS DECIMAL(18,2))) AS lowest_price,
       MAX(TRY_CAST(price AS DECIMAL(18,2))) AS highest_price
FROM Listings
GROUP BY city;

SELECT TOP 10
    host_since, host_response_rate, host_acceptance_rate,
    host_is_superhost, bedrooms, accommodates,
    review_scores_rating, instant_bookable
FROM Listings;

SELECT MIN(review_date) AS first_review, MAX(review_date) AS last_review
FROM Reviews_clean;

SELECT TOP 10
    host_response_rate, host_acceptance_rate
FROM Listings
WHERE host_response_rate IS NOT NULL;

SELECT
    TRY_CAST(listing_id AS BIGINT)            AS listing_id,
    name,
    TRY_CAST(host_id AS BIGINT)               AS host_id,
    TRY_CAST(host_since AS DATE)              AS host_since,
    TRY_CAST(host_response_rate AS DECIMAL(5,2))   AS host_response_rate,
    TRY_CAST(host_acceptance_rate AS DECIMAL(5,2)) AS host_acceptance_rate,
    CASE host_is_superhost WHEN 't' THEN 1 WHEN 'f' THEN 0 END AS is_superhost,
    TRY_CAST(host_total_listings_count AS INT) AS host_total_listings_count,
    neighbourhood,
    district,
    city,
    property_type,
    room_type,
    TRY_CAST(accommodates AS INT)             AS accommodates,
    TRY_CAST(bedrooms AS INT)                 AS bedrooms,
    TRY_CAST(price AS DECIMAL(18,2))          AS price,
    CASE WHEN TRY_CAST(price AS DECIMAL(18,2)) > 0 THEN 1 ELSE 0 END AS price_valid,
    TRY_CAST(minimum_nights AS INT)           AS minimum_nights,
    TRY_CAST(maximum_nights AS INT)           AS maximum_nights,
    TRY_CAST(review_scores_rating AS DECIMAL(5,2)) AS review_scores_rating,
    CASE instant_bookable WHEN 't' THEN 1 WHEN 'f' THEN 0 END AS instant_bookable
INTO Listings_clean
FROM Listings;

select * from Listings_clean
SELECT SUM(price_valid) FROM Listings_clean
listings_clean

SELECT
    TRY_CAST(listing_id AS BIGINT) AS listing_id,
    TRY_CAST(review_id AS BIGINT) AS review_id,
    TRY_CAST([date] AS DATE) AS review_date,
    TRY_CAST(reviewer_id AS BIGINT) AS reviewer_id
INTO Reviews_clean
FROM Reviews;

select * from Reviews_clean
CREATE VIEW vw_reviews_per_listing AS
SELECT listing_id, COUNT(*) AS Reviews_count
FROM Reviews_clean
GROUP BY listing_id

SELECT TOP 10 * FROM vw_reviews_per_listing;

CREATE VIEW vw_reviews_per_month_city AS
SELECT
    l.city,
    DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1) AS review_month,
    COUNT(*) AS review_count
FROM Reviews_clean r
JOIN Listings_clean l ON r.listing_id = l.listing_id
GROUP BY l.city, DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1);

select top 10 * from vw_reviews_per_month_city

select sum(Review_count)
from vw_reviews_per_month_city

select city, count (*) 
from listings 
Group by city

SELECT Room_type, COUNT (*) AS Listings_across_room_types
from listings_clean
Group by Room_type
Order by Listings_across_room_types DESC;

SELECT TOP 10 Property_type, COUNT(*) AS Most_Common_Property
FROM Listings_clean
GROUP BY Property_type
ORDER BY Most_Common_Property DESC;

SELECT City,  AVG (
                 host_response_rate ) AS AVG_host_response_rate,
                 AVG (host_acceptance_rate) AS AVG_host_acceptance_rate
FROM listings_clean
GROUP BY city
ORDER BY AVG_host_response_rate DESC;

SELECT DISTINCT
    city,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER (PARTITION BY city) AS median_price,
    AVG(price) OVER (PARTITION BY city) AS average_price
FROM Listings_clean
WHERE price_valid = 1;

SELECT city, COUNT(host_response_rate) AS reported, AVG(host_response_rate) AS avg_rate
FROM Listings_clean
GROUP BY city;

SELECT MIN(review_date) AS first_review, MAX(review_date) AS last_review
FROM Reviews_clean;