-- One regression-ready row per stable station ID.
-- Baseline predictors use Jan–Oct 2014; ride_change is 2015 minus 2014.
-- Weekday peak windows are 7:00–9:59 a.m. and 4:00–6:59 p.m.
WITH eligible_trips AS (
  SELECT
    t.start_station_id,
    ROUND(t.start_station_latitude, 4) AS latitude,
    ROUND(t.start_station_longitude, 4) AS longitude,
    EXTRACT(YEAR FROM t.starttime) AS trip_year,
    EXTRACT(DAYOFWEEK FROM t.starttime) AS day_of_week,
    EXTRACT(HOUR FROM t.starttime) AS trip_hour,
    t.usertype,
    t.gender,
    TO_JSON_STRING(t) AS ride_key
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
)
SELECT
  e.start_station_id,
  MAX(e.latitude) AS latitude,
  MAX(e.longitude) AS longitude,
  COUNT(DISTINCT IF(e.trip_year = 2014, e.ride_key, NULL)) AS rides_2014,
  COUNT(DISTINCT IF(e.trip_year = 2015, e.ride_key, NULL)) AS rides_2015,
  COUNT(DISTINCT IF(e.trip_year = 2015, e.ride_key, NULL))
    - COUNT(DISTINCT IF(e.trip_year = 2014, e.ride_key, NULL))
    AS ride_change,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(
      e.trip_year = 2014 AND e.usertype = 'Subscriber',
      e.ride_key, NULL
    )),
    COUNT(DISTINCT IF(e.trip_year = 2014, e.ride_key, NULL))
  ) AS subscriber_share_2014,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(
      e.trip_year = 2014
        AND e.usertype = 'Subscriber'
        AND e.gender = 'female',
      e.ride_key, NULL
    )),
    COUNT(DISTINCT IF(
      e.trip_year = 2014
        AND e.usertype = 'Subscriber'
        AND e.gender IN ('female', 'male'),
      e.ride_key, NULL
    ))
  ) AS female_share_of_known_gender_subscribers_2014,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(
      e.trip_year = 2014
        AND e.day_of_week BETWEEN 2 AND 6
        AND (e.trip_hour BETWEEN 7 AND 9 OR e.trip_hour BETWEEN 16 AND 18),
      e.ride_key, NULL
    )),
    COUNT(DISTINCT IF(e.trip_year = 2014, e.ride_key, NULL))
  ) AS weekday_peak_share_2014
FROM eligible_trips AS e
JOIN stable_station_ids USING (start_station_id)
GROUP BY e.start_station_id
HAVING COUNT(DISTINCT IF(e.trip_year = 2014, e.ride_key, NULL)) > 0
   AND COUNT(DISTINCT IF(e.trip_year = 2015, e.ride_key, NULL)) > 0;
