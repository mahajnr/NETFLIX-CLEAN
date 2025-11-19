select * from netflix_titles$


-- Create cleaned table with additional columns
SELECT 
    show_id,
    type,
    title,
    NULLIF(LTRIM(RTRIM(director)), '') AS director,
    NULLIF(LTRIM(RTRIM(cast)), '') AS cast,
    NULLIF(LTRIM(RTRIM(country)), '') AS country,
    NULLIF(LTRIM(RTRIM(date_added)), '') AS date_added,
    release_year,
    rating,
    duration,
    listed_in,
    description,

    -- New columns for cleaning
    CAST(NULL AS DATE) AS date_added_clean,
    CAST(NULL AS INT) AS duration_numeric,
    CAST(NULL AS VARCHAR(20)) AS duration_unit
INTO dbo.netflix_clean
FROM dbo.netflix_titles$;

select * from netflix_clean

---Date into standard format
UPDATE dbo.netflix_clean
SET date_added_clean = TRY_PARSE(date_added AS DATE USING 'en-US')
WHERE date_added IS NOT NULL;

---Split duration into numeric and unit components for analysis.

UPDATE dbo.netflix_clean
SET 
duration_numeric = TRY_CAST(
LEFT(duration, CHARINDEX(' ', duration) - 1) 
AS INT
  ),
duration_unit = LTRIM(
SUBSTRING(duration, CHARINDEX(' ', duration), LEN(duration))
  )
WHERE duration IS NOT NULL;

select duration from netflix_clean
--- it assumes one space seperates number and unit

--- this gives the primary production country to simplify the analyis (7976) rows were affected

UPDATE dbo.netflix_clean
SET country = 
    CASE 
        WHEN CHARINDEX(',', country) > 0 
        THEN LTRIM(RTRIM(LEFT(country, CHARINDEX(',', country) - 1)))
        ELSE LTRIM(RTRIM(country))
    END
WHERE country IS NOT NULL;

---
-- Check for duplicate show_id
WITH Duplicates AS (
    SELECT show_id,
    ROW_NUMBER() OVER (PARTITION BY show_id ORDER BY (SELECT NULL)) AS rn
    FROM dbo.netflix_clean
)
DELETE FROM Duplicates WHERE rn > 1;

--- no duplicate showID They are all unique id

1---- What year had the highest number of titles added to Netflix?
SELECT 
    YEAR(date_added_clean) AS year_added,
    COUNT(*) AS titles_count
FROM dbo.netflix_clean
WHERE date_added_clean IS NOT NULL
GROUP BY YEAR(date_added_clean)
ORDER BY titles_count DESC;
-- 2019 has the highest year with titles added on netflix with 2,016 titl counts.

----2 How has the distribution of movies vs. TV shows changed over time?
SELECT 
    YEAR(date_added_clean) AS year_added,
    type,
    COUNT(*) AS count
FROM dbo.netflix_clean
WHERE date_added_clean IS NOT NULL
GROUP BY YEAR(date_added_clean), type
ORDER BY year_added, type;
---movies have the highest distribution over time.

---3 Which countries contribute the most content to Netflix's library?
---- top countries by content

SELECT TOP 10
    country,
    COUNT(*) AS total_titles
FROM dbo.netflix_clean
WHERE country IS NOT NULL
GROUP BY country
ORDER BY total_titles DESC;

--- united s... has the top content, followed by india on netflix

--4  What are the top 5 countries producing TV shows and movies separately?
-- Movies
SELECT TOP 5 country, COUNT(*) AS movie_count
FROM dbo.netflix_clean
WHERE type = 'Movie' AND country IS NOT NULL
GROUP BY country
ORDER BY movie_count DESC;

---united state have the highest movie content

-- TV Shows
SELECT TOP 5 country, COUNT(*) AS show_count
FROM dbo.netflix_clean
WHERE type = 'TV Show' AND country IS NOT NULL
GROUP BY country
ORDER BY show_count DESC;

--- united state highest tv show with 847 show count

---5 Which genres or categories are most common on Netflix?

-- Top 10 genres overall
SELECT TOP 10
    TRIM(value) AS genre,
    COUNT(*) AS title_count
FROM dbo.netflix_clean
CROSS APPLY STRING_SPLIT(listed_in, ',')
GROUP BY TRIM(value)
ORDER BY title_count DESC;


---How many unique genres does Netflix support, and which ones dominate each content type?


-- Total unique genres
SELECT COUNT(DISTINCT TRIM(value)) AS unique_genres
FROM dbo.netflix_clean
CROSS APPLY STRING_SPLIT(listed_in, ',');

--42 unique genres

-- Top genres by type
SELECT 
    type,
    TRIM(value) AS genre,
    COUNT(*) AS count
FROM dbo.netflix_clean
CROSS APPLY STRING_SPLIT(listed_in, ',')
GROUP BY type, TRIM(value)
ORDER BY type, count DESC;

-- the top genre is international movies by type.

---7 Which directors have the most titles available on Netflix?
---top 10 directors

SELECT TOP 10
    TRIM(director) AS director,
    COUNT(*) AS title_count
FROM dbo.netflix_clean
WHERE director IS NOT NULL
GROUP BY TRIM(director)
ORDER BY title_count DESC;

----Rajiv Chilaka has the highest count for directors

---- Which actors appear in the most number of Netflix titles?

SELECT TOP 10
    TRIM(value) AS actor,
    COUNT(*) AS appearances
FROM dbo.netflix_clean
CROSS APPLY STRING_SPLIT(cast, ',')
WHERE cast IS NOT NULL
GROUP BY TRIM(value)
ORDER BY appearances DESC;
--- Anupam Kher has the highest appearances with 43

---What are the most common content ratings (e.g., TV-MA, PG-13), and how do they vary by show type?

SELECT 
    type,
    rating,
    COUNT(*) AS count
FROM dbo.netflix_clean
WHERE rating IS NOT NULL
GROUP BY type, rating
ORDER BY type, count DESC;

--TV-MA for 2062 counts.

---What is the average duration of movies, and how does it compare to TV shows with multiple episodes?

SELECT 
    'Movie' AS content_type,
    AVG(CAST(duration_numeric AS FLOAT)) AS avg_duration_minutes
FROM dbo.netflix_clean
WHERE type = 'Movie' AND duration_unit = 'min'

UNION ALL

SELECT 
    'TV Show' AS content_type,
    AVG(CAST(duration_numeric AS FLOAT)) AS avg_seasons
FROM dbo.netflix_clean
WHERE type = 'TV Show' AND duration_unit = 'Seasons';

---movies avg_dura_mins is 99.5771866840731, that makes it the highest.
