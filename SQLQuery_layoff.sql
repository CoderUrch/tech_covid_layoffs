USE test;

SELECT *
FROM [dbo].[layoffs]

--DATA CLEANING PROCESS
-- Create a staging table by duplicating the original dataset. This ensures you can fall back to the original dataset if anything should go wrong
select *
into staging
from layoffs;

select *
from staging

-- Remove Duplicates using windows function
with remove_duplicates as (
     select *, ROW_NUMBER() over (partition by company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions order by(select NULL)) as row_num
	 from staging)
DELETE from remove_duplicates
where row_num > 1

-- Trimming Whitespaces
UPDATE staging
SET company = TRIM(company)

UPDATE staging
SET location = TRIM(location)

UPDATE staging
SET country = TRIM(country)

UPDATE staging
SET industry = TRIM(industry)

UPDATE staging
SET stage = TRIM(stage)

-- STANDARDIZING COLUMNS
-- Standardize location Column
SELECT DISTINCT location
FROM staging
ORDER BY location;

-- ('D√ºsseldorf' should be renamed Dusseldorf. 'Florian√≥polis' renamed Florianopolis. 'Malm√∂' renamed Malmo. should be unified into one consistent name called "United States")
UPDATE staging
SET location = 'Dusseldorf'
WHERE location LIKE 'D%sseldorf';

UPDATE staging
SET location = 'Florianopolis'
WHERE location LIKE 'Florian%polis';

UPDATE staging
SET location = 'Malmo'
WHERE location LIKE 'Malm%';

-- Standardize industry column
SELECT DISTINCT industry
FROM staging
ORDER BY industry;

-- (Crypto, Crypto Currency, CryptoCurrency should be unified into one consistent name called "Crypto")
UPDATE staging
SET industry = 'Crypto'
WHERE industry = 'Crypto Currency';

UPDATE staging
SET industry = 'Crypto'
WHERE industry = 'CryptoCurrency';

-- Standardize Country column
SELECT DISTINCT country
FROM staging
ORDER BY country;

-- (United States and United States. should be unified into one consistent name called "United States")
UPDATE staging
SET country = 'United States'
WHERE country = 'United States.';

-- REMOVING/UPDATING NULL VALUES
-- Check for companies, locations without industries imputed
SELECT company, location, industry
FROM staging
WHERE industry IS NULL or industry = 'NULL';

-- impute 'Travel' industry for Airbnb
SELECT company, location, industry
FROM staging
WHERE company = 'Airbnb' and location = 'SF Bay Area'

UPDATE staging
SET industry = 'Travel'
WHERE industry IS NULL AND company = 'Airbnb' AND location = 'SF Bay Area';

-- impute 'Consumer' industry for Juul
SELECT company, location, industry
FROM staging
WHERE company = 'Juul' and location = 'SF Bay Area'

UPDATE staging
SET industry = 'Consumer'
WHERE industry IS NULL AND company = 'Juul' AND location = 'SF Bay Area';

-- impute 'Transportation' industry for Carvana
SELECT company, location, industry
FROM staging
WHERE company = 'Carvana' and location = 'Phoenix'

UPDATE staging
SET industry = 'Transportation'
WHERE industry IS NULL AND company = 'Carvana' AND location = 'Phoenix';

-- Delete rows where total_laid_off and percentage_laid_off are both NULL
DELETE FROM staging
WHERE total_laid_off = 'NULL' AND percentage_laid_off = 'NULL';

-- DATA TYPE CONVERSION
-- Add a new date column as DATE
ALTER TABLE staging
ADD standardized_date DATE;

UPDATE staging
SET standardized_date = TRY_CAST(date AS DATE);

-- Drop redundant date column
ALTER TABLE staging
DROP COLUMN date;

-- Rename standardized date column
EXEC sp_rename 'staging.standardized_date', 'date', 'COLUMN';

-- Add a new column for total_laid_off as INT
ALTER TABLE staging
ADD total_laid_off_int INT;

-- Convert total_laid_off to INT
UPDATE staging
SET total_laid_off_int = TRY_CAST(total_laid_off AS INT);

-- Drop redundant total_laid_off column
ALTER TABLE staging
DROP COLUMN total_laid_off;

-- Rename total_laid_off column
EXEC sp_rename 'staging.total_laid_off_int', 'total_laid_off', 'COLUMN';

-- Add a new column for percentage_laid_off as FLOAT
ALTER TABLE staging
ADD percentage_laid_off_float FLOAT;

-- Convert percentage_laid_off to FLOAT
UPDATE staging
SET percentage_laid_off_float = TRY_CAST(percentage_laid_off AS FLOAT);

-- Drop redundant percentage_laid_off column
ALTER TABLE staging
DROP COLUMN percentage_laid_off;

-- Rename percentage_laid_off column
EXEC sp_rename 'staging.percentage_laid_off_float', 'percentage_laid_off', 'COLUMN';

-- Add a new column for funds_raised_millions as INT
ALTER TABLE staging
ADD funds_raised_millions_int INT;

-- Convert funds_raised_millions to INT
UPDATE staging
SET funds_raised_millions = TRY_CAST(funds_raised_millions AS INT);

-- Drop redundant funds_raised_millions column
ALTER TABLE staging
DROP COLUMN funds_raised_millions;

-- Rename funds_raised_millions column
EXEC sp_rename 'staging.funds_raised_millions_int', 'funds_raised_millions', 'COLUMN';



--- EXPLORATORY DATA ANALYSIS ---

-- Total number of layoffs
select SUM(total_laid_off) as total_layoffs
from staging

-- Company with the single largest layoff
select company, total_laid_off as max_layoff
from staging
where total_laid_off IN 
(select max(total_laid_off) as laid_off
from staging)

-- Top 10 companies with the most cumulative layoffs
select company, SUM(total_laid_off) as max_layoff
from staging
GROUP BY company
order by 2 desc
offset 0 rows
fetch next 10 rows only;

-- Top 10 industries with the most cumulative layoffs
select industry, SUM(total_laid_off) as max_layoff
from staging
GROUP BY industry
order by 2 desc
offset 0 rows
fetch next 10 rows only;

-- Top 10 countries with the most cumulative layoffs
select country, SUM(total_laid_off) as max_layoff
from staging
GROUP BY country
order by 2 desc
offset 0 rows
fetch next 10 rows only;

-- Total yearly layoffs in descending order
select year(date) as year, SUM(total_laid_off) as max_layoff
from staging
where year(date) is not null
GROUP BY year(date)
order by 2 desc;