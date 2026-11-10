# Airbnb Market Intelligence Dashboard

**AnalystLab Africa Experience Lab · Week 1 · Track A (Data Analytics)**
Author: Babatunde Omotayo

An end-to-end analysis of **279,712 Airbnb listings** and **5,373,143 guest review records** across 10 cities (November 2008 to March 2021). The data is cleaned and validated in **SQL Server**, modelled and visualised in a four-page **Power BI** dashboard, and summarised in an executive report.

---

## 1. Business problem

Airbnb listings are spread across 10 cities, and each city has its own currency, property mix, pricing and host behaviour. There was no single, validated view of where supply is concentrated, what typical prices look like, how hosts perform, or how guest review activity changes over time.

**Intended users:** market analysts, property investors and hosts, and platform operations teams.

**Decisions supported:** where supply is concentrated, how to price a listing against comparable homes in the same city, which cities need host support, and which segments attract the most review activity.

## 2. Tools

| Tool | Used for |
| --- | --- |
| Microsoft SQL Server Express + SSMS | Import, inspection, cleaning, summary views, validation queries |
| Power BI Desktop | Data model, DAX measures, four-page dashboard |
| DAX | KPI measures (counts, medians, averages, shares) |
| Custom JSON theme | Consistent warm colour palette and fonts |
| Claude (Anthropic) | AI assistant: explained SQL and DAX concepts, helped troubleshoot errors and drafted documentation. All queries were run, checked and validated by me. |

Excel was not used, as required by the assignment.

## 3. Data

| File | Rows | Columns | Description |
| --- | --- | --- | --- |
| Listings.csv | 279,712 | 33 | One row per listing: host, location, property, price, review scores |
| Reviews.csv | 5,373,143 | 4 | One row per review: listing_id, review_id, date, reviewer_id |

Prices are advertised nightly prices in each city's **local currency**. The data has no currency column.

**Data source:** dataset supplied by AnalystLab Africa for the Week 1 assignment. The CSV files are not included in this repository because Reviews.csv is larger than GitHub's 100 MB file limit. To reproduce the work, place `Listings.csv` and `Reviews.csv` in `data/raw/`.

## 4. Repository structure

```
airbnb-market-intelligence/
├── data/
│   ├── raw/            Original CSVs (not committed if too large; see Setup)
│   └── processed/      Optional exports of clean tables
├── scripts/
│   └── airbnb_market.sql      All SQL: inspection, cleaning, views, validation
├── dashboard/
│   ├── Air_bnb_Market_Dashboard.pbix
│   └── airbnb_warm.json       Power BI theme
├── docs/
│   ├── project_log.pdf        Full step-by-step log, data quality report, KPI sheet, validation
│   └── executive_summary.pdf  Findings and recommendations
├── screenshots/
│   ├── page1_market_overview.png
│   ├── page2_pricing.png
│   ├── page3_hosts.png
│   └── page4_reviews.png
└── README.md
```

## 5. How to reproduce

1. **Create the database.** In SSMS, run `CREATE DATABASE AirbnbMarket;`
2. **Import the raw files.** Right-click the database → *Tasks → Import Flat File* for each CSV, creating tables `Listings` and `Reviews`. On the *Modify Columns* screen, set **every column to `nvarchar(MAX)` with nulls allowed**, and set no primary key. Everything is loaded as text on purpose so that bad values can be found and documented rather than blocking the import.
3. **Check the row counts** match 279,712 and 5,373,143.
4. **Run `scripts/airbnb_market.sql` in order.** It contains:
   - data quality checks (keys, duplicates, relationship, missing values, invalid prices, value formats)
   - creation of `Listings_clean` and `Reviews_clean` with proper data types (`TRY_CAST`)
   - summary views `vw_reviews_per_listing` and `vw_reviews_per_month_city`
   - the business-question and validation queries
5. **Open the dashboard.** Open `dashboard/Air_bnb_Market_Dashboard.pbix`. If prompted, point the SQL Server source to your own server name (*Transform data → Data source settings*), then **Refresh**. The first refresh can take several minutes, because Power BI rebuilds the review summary views from 5.3 million rows.

## 6. Method

### Data quality findings

| Check | Result | Decision |
| --- | --- | --- |
| listing_id unique | 279,712 rows = 279,712 unique IDs | Valid primary key |
| Repeated review_id | 160 IDs, each appearing twice (320 rows). Same date and reviewer, different listing | Kept all rows; `listing_id + review_id` used as composite key (confirmed unique) |
| Reviews with no matching listing | 0 | Relationship valid (one listing → many reviews) |
| Listings with no reviews | 86,156 (30.8%) | Kept; review KPIs state whether they include them |
| Missing district | 242,700 (86.8%) | Too incomplete for cross-city district analysis |
| Missing response / acceptance rate | 128,782 (46.0%) / 113,087 (40.4%) | Left blank, not filled with zero; averages use reporting hosts only |
| Missing review score | 91,405 (32.7%) | Left blank; mostly listings with no reviews |
| Price ≤ 0 | 113 listings in 7 cities | Flagged with `price_valid = 0`; excluded from price measures only |
| Non-numeric price | 0 | Safe to convert to DECIMAL |
| Extreme prices | Every city has very high outliers (e.g. €12,000/night in Paris) | Kept and flagged; **median** used instead of average |

### Data model

- `Listings_clean` (1) — (1) `vw_reviews_per_listing` on `listing_id`
- `Cities` (1) → (many) `Listings_clean` on `city`
- `Cities` (1) → (many) `vw_reviews_per_month_city` on `city`

`Cities = DISTINCT(Listings_clean[city])` is a shared lookup table, so one city slicer filters every visual. Only the clean table and the two small summary views are loaded into Power BI; the 5.3 million raw review rows stay in SQL Server.

### Key measures (DAX)

| Measure | Formula |
| --- | --- |
| Total Listings | `COUNTROWS(Listings_clean)` |
| Median Price | `CALCULATE(MEDIAN(Listings_clean[price]), Listings_clean[price_valid] = 1)` |
| Price Skew | `DIVIDE([Average Price], [Median Price])` |
| Total Review Records | `SUM(vw_reviews_per_month_city[review_count])` |
| Avg Reviews per Listing | `DIVIDE(SUM(vw_reviews_per_listing[Reviews_count]), [Total Listings])` |
| Superhost Share | `AVERAGE(Listings_clean[is_superhost])` (1/0 column, so the average is the share) |
| Listings per Host | `DIVIDE([Total Listings], DISTINCTCOUNT(Listings_clean[host_id]))` |

The full KPI definition sheet, with interpretation for each measure, is in `docs/project_log.pdf`.

## 7. Dashboard

| Page | What it shows |
| --- | --- |
| **Overview** | Total listings, cities, review records, average score; listings by city; room type split; top 10 property types |
| **Pricing** | Median and average price, price skew; median price by room type and by guest capacity; typical price table for all 10 cities |
| **Hosts** | Listings per host, superhost share, response and acceptance rates; each by city |
| **Reviews** | Review records, reviews per listing, listings with no reviews; reviews by city; review count vs rating; review activity over time |

Every page has City, Room type and Property type slicers. On the Pricing page the city slicer is **single select**, so prices are never mixed across currencies.

### Page 1 · Market Overview
![Market Overview](screenshots/page1_market_overview.png)

### Page 2 · Pricing & Property
![Pricing](screenshots/page2_pricing.png)

### Page 3 · Host Performance
![Hosts](screenshots/page3_hosts.png)

### Page 4 · Review Activity & Listing Scores
![Reviews](screenshots/page4_reviews.png)

### Presentation video
A 5–10 minute walkthrough of the project: [Watch the presentation](PASTE_YOUR_VIDEO_LINK_HERE)

## 8. Validation

Eleven dashboard figures were recalculated independently in SQL, and all match. Examples: total listings (279,712), total review records (5,373,143), Paris median and average price (80 / 113.20), all 30 city price values and all 20 city host rates. The city bars on the Overview and Reviews pages add up exactly to the totals.

Two discrepancies were found and fixed:
1. **Mixed currencies.** With all cities selected, the Pricing cards combined 10 currencies (median 150, skew 4.06). Fixed by making the Pricing city slicer single select.
2. **Hidden visual filter.** A host chart showed rates slightly different from SQL while the overall card matched. The cause was a Top 10 property type filter carried over when a page was duplicated. After removing it, all 20 values match SQL.

## 9. Key findings

1. Paris holds almost 1 in 4 listings (64,690), nearly twice New York.
2. 65.1% of listings are entire homes; hotel and shared rooms are under 4%.
3. Average prices are 1.4–2.7× the median in every city; the median is the fair benchmark.
4. Host acceptance ranges from 75.7% (Rio de Janeiro) to 90.5% (Bangkok).
5. Hong Kong averages 3.5 listings per host (professional operators); Paris averages 1.2.
6. 30.8% of listings have no reviews; Rome averages 40 reviews per listing, Istanbul 8.
7. Review activity grew every year to 1.63 million in 2019, then fell 54% in 2020.

Recommendations and how to evaluate them are in `docs/executive_summary.pdf`.

## 10. Assumptions and limitations

- Currencies are **assumed** from each city; prices are compared only within a city.
- Advertised price is not revenue: there are no bookings or occupancy data.
- Review records show activity, not satisfaction: there is no review text.
- District, response rate and acceptance rate are heavily incomplete.
- 2021 is a partial year (data ends 1 March 2021).
- Findings show associations, not causes.
