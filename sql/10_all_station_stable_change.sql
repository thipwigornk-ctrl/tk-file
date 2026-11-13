-- Compare Jan–Oct ride changes for station IDs with stable coordinates.
-- Coordinates are rounded to four decimals; exact full-row duplicates count once.
WITH eligible_trips AS (
  SELECT
    t.start_station_id,
    ROUND(t.start_station_latitude, 4) AS latitude,
    ROUND(t.start_station_longitude, 4) AS longitude,
    EXTRACT(YEAR FROM t.starttime) AS trip_year,
    TO_JSON_STRING(t) AS full_row
  FROM `bigquery-public-data.new_york_citibike.citibike_trips` AS t
  WHERE t.starttime IS NOT NULL
    AND t.start_station_id IS NOT NULL
    AND t.start_station_name IS NOT NULL
    AND TRIM(t.start_station_name) != ''
    AND t.start_station_latitude IS NOT NULL
    AND t.start_station_longitude IS NOT NULL
    AND DATE(t.starttime) >= DATE '2014-01-01'
    AND DATE(t.starttime) < DATE '2016-01-01'
    AND EXTRACT(MONTH FROM t.starttime) BETWEEN 1 AND 10
),
stable_station_ids AS (
  SELECT start_station_id
  FROM eligible_trips
  GROUP BY start_station_id
  HAVING COUNT(DISTINCT TO_JSON_STRING(STRUCT(latitude, longitude))) = 1
),
station_year AS (
  SELECT
    e.start_station_id,
    e.latitude,
    e.longitude,
    e.trip_year,
    COUNT(DISTINCT e.full_row) AS rides
  FROM eligible_trips AS e
  JOIN stable_station_ids USING (start_station_id)
  GROUP BY e.start_station_id, e.latitude, e.longitude, e.trip_year
),
paired AS (
  SELECT
    start_station_id,
    latitude,
    longitude,
    MAX(IF(trip_year = 2014, rides, NULL)) AS rides_2014,
    MAX(IF(trip_year = 2015, rides, NULL)) AS rides_2015
  FROM station_year
  GROUP BY start_station_id, latitude, longitude
  HAVING COUNTIF(trip_year IN (2014, 2015)) = 2
)
SELECT
  start_station_id,
  latitude,
  longitude,
  rides_2014,
  rides_2015,
  rides_2015 - rides_2014 AS ride_change,
  ROUND(SAFE_DIVIDE(rides_2015 - rides_2014, rides_2014) * 100, 2)
    AS percent_change
FROM paired
ORDER BY ride_change;
