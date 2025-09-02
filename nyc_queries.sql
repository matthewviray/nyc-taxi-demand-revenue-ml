SELECT * FROM nyc_taxi.yellow_taxi;
SELECT * FROM nyc_taxi.nyc_weather;


# Add Date column
ALTER TABLE nyc_taxi.yellow_taxi
ADD COLUMN pickup_date DATE;

UPDATE nyc_taxi.yellow_taxi
SET pickup_date = DATE(tpep_pickup_datetime)
WHERE pickup_date IS NULL;

DESCRIBE nyc_taxi.nyc_weather;

# Merge 2 month taxi data, weather data, and taxi zone data

CREATE TABLE nyc_taxi.taxi_weather_prejoined AS
SELECT yellow.*,
       weather.temp, weather.tempmax, weather.tempmin, weather.feelslike,
       weather.dew, weather.humidity, weather.precip, weather.precipprob,
       weather.preciptype, weather.windgust, weather.windspeed, weather.cloudcover,
       weather.uvindex, weather.conditions, weather.description,
       zones.Zone AS pickup_zone, zones.Borough AS pickup_borough, zones.service_zone AS pickup_service_zone,
       dropoff_zones.Zone AS dropoff_zone, dropoff_zones.Borough AS dropoff_borough, dropoff_zones.service_zone AS dropoff_service_zone
FROM nyc_taxi.yellow_taxi AS yellow
LEFT JOIN nyc_taxi.nyc_weather AS weather
  ON yellow.pickup_date = DATE(weather.datetime)
LEFT JOIN nyc_taxi.taxi_zone_lookup AS zones
  ON yellow.PULocationID = zones.LocationID
LEFT JOIN nyc_taxi.taxi_zone_lookup AS dropoff_zones
  ON yellow.DOLocationID = dropoff_zones.LocationID;
  
SELECT COUNT(*) FROM nyc_taxi.taxi_weather_prejoined;
  
SELECT * FROM nyc_taxi.taxi_weather_prejoined;

# cleaning data, checking for nulls
SELECT COUNT(*) AS TOTAL_ROWS,
SUM(CASE WHEN temp is NULL THEN 1 ELSE 0 END) as missing_temp,
SUM(CASE WHEN pickup_zone IS NULL THEN 1 ELSE 0 END) as missing_zones,
SUM(CASE WHEN dropoff_zone IS NULL THEN 1 ELSE 0 END) as missing_dropoff_zones
FROM nyc_taxi.taxi_weather_prejoined;

SELECT COUNT(*) AS TOTAL_ROWS,
SUM(CASE WHEN VendorID is NULL THEN 1 ELSE 0 END) as missing_id,
SUM(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 ELSE 0 END) as tpep_pickup_datetime,
SUM(CASE WHEN tpep_dropoff_datetime IS NULL THEN 1 ELSE 0 END) as missing_dropoff_zones,
SUM(CASE WHEN passenger_count IS NULL THEN 1 ELSE 0 END) as missing_pass_count,
SUM(CASE WHEN trip_distance IS NULL THEN 1 ELSE 0 END) as missing_distance,
SUM(CASE WHEN fare_amount IS NULL THEN 1 ELSE 0 END) as missing_fare,
SUM(CASE WHEN tip_amount IS NULL THEN 1 ELSE 0 END) as missing_tip,
SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END) as missing_total,
SUM(CASE WHEN temp IS NULL THEN 1 ELSE 0 END) as missing_temp,
SUM(CASE WHEN precip IS NULL THEN 1 ELSE 0 END) as missing_precip,
SUM(CASE WHEN windspeed IS NULL THEN 1 ELSE 0 END) as missing_windspeed,
SUM(CASE WHEN cloudcover IS NULL THEN 1 ELSE 0 END) as missing_cloudcover

FROM nyc_taxi.taxi_weather_prejoined;

SELECT COUNT(*) FROM nyc_taxi.taxi_weather_prejoined
WHERE temp is NULL;

SELECT COUNT(*)
FROM nyc_taxi.taxi_weather_prejoined
WHERE YEAR(tpep_pickup_datetime) != 2024 OR MONTH(tpep_pickup_datetime) NOT BETWEEN 3 AND 4;

SELECT COUNT(*) 
FROM nyc_taxi.yellow_taxi;

#MULTIPLE DUPLICATES
SELECT COUNT(*)
FROM nyc_taxi.taxi_weather_prejoined
GROUP BY fare_amount,tpep_pickup_datetime, tpep_dropoff_datetime
HAVING COUNT(*) > 1;

# Checked the range of fare amounts
SELECT
  fare_amount,
  COUNT(*) AS freq
FROM nyc_taxi.taxi_weather_prejoined
GROUP BY fare_amount
ORDER BY fare_amount DESC
LIMIT 1000;


#Checked if there are location id's that were not in the given location id's
SELECT DISTINCT PULocationID FROM nyc_taxi.yellow_taxi_clean WHERE PULocationID NOT BETWEEN 1 and 265;
SELECT DISTINCT DOLocationID FROM nyc_taxi.yellow_taxi_clean WHERE DOLocationID NOT BETWEEN 1 and 265;

#Checked if there are 'N/A' or NULLS with pickup and dropoff boroughs,zones,and service zones
SELECT COUNT(*) AS null_count
FROM nyc_taxi.yellow_taxi_clean
WHERE pickup_borough = 'N/A';


SELECT COUNT(*) AS null_count
FROM nyc_taxi.yellow_taxi_clean
WHERE pickup_borough is NULL;

# check outliers in python from taxi_weather_prejoined

SELECT fare_amount FROM nyc_taxi.taxi_weather_prejoined;

-- tip distribution
SELECT tip_amount AS count FROM nyc_taxi.taxi_weather_prejoined;

-- total distribution
SELECT total_amount FROM nyc_taxi.taxi_weather_prejoined;

-- trip distance distribution
SELECT trip_distance FROM nyc_taxi.taxi_weather_prejoined;

-- trip duration distribution
SELECT TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime) AS trip_duration FROM nyc_taxi.taxi_weather_prejoined;

-- passenger count distribution
SELECT passenger_count FROM nyc_taxi.taxi_weather_prejoined;

SELECT 
    MIN(TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime)) AS min_minute,
    MAX(TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime)) AS max_minute,
    AVG(TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime)) AS avg_minute
FROM nyc_taxi.taxi_weather_prejoined;

#cleaned table removing outliers, duplicates, nulls due to out of date range
CREATE TABLE nyc_taxi.yellow_taxi_clean AS
SELECT DISTINCT *,
       TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime) AS Trip_Duration
FROM nyc_taxi.taxi_weather_prejoined
WHERE passenger_count BETWEEN 1 AND 5
  AND trip_distance BETWEEN 0.38 AND 18.35
  AND fare_amount BETWEEN 4.4 AND 70.0
  AND tip_amount BETWEEN 0.0 AND 16.19
  AND total_amount BETWEEN 9.1 AND 98.88
  AND TEMP IS NOT NULL
  AND PULocationID NOT IN (264, 265)
  AND DOLocationID NOT IN (264, 265)
  AND TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime, tpep_dropoff_datetime) BETWEEN 2 AND 57;


#EDA query data such as summary stats andqueries to understand/get a feel of the data

SELECT COUNT(*) FROM nyc_taxi.yellow_taxi_clean;
SELECT * FROM nyc_taxi.yellow_taxi_clean;



# Total rides and total money made
SELECT COUNT(*) AS total_rides, SUM(total_amount) AS total_made
FROM nyc_taxi.yellow_taxi_clean;

#distributions(plot in python)
-- Fare distribution
SELECT fare_amount,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY fare_amount
ORDER BY fare_amount;

-- tip distribution
SELECT tip_amount,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY tip_amount
ORDER BY tip_amount;

-- total distribution
SELECT total_amount,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY total_amount
ORDER BY total_amount;

-- trip duration distribution
SELECT trip_duration,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY trip_duration
ORDER BY trip_duration;

-- condition distribution
SELECT conditions, COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY conditions;

-- hour distribution
SELECT HOUR(tpep_pickup_datetime) AS hour,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY HOUR(tpep_pickup_datetime);

-- day of week distribution
SELECT DAYOFWEEK(tpep_pickup_datetime) AS day,COUNT(*) AS count FROM nyc_taxi.yellow_taxi_clean
GROUP BY DAYOFWEEK(tpep_pickup_datetime);

# median of fare, tip, and total per ride to do in python as more insight than average

-- condition median
SELECT conditions, fare_amount, tip_amount, total_amount
FROM nyc_taxi.yellow_taxi_clean;

-- day median
SELECT DAYOFWEEK(tpep_pickup_datetime) AS day, fare_amount, tip_amount, total_amount
FROM nyc_taxi.yellow_taxi_clean;

-- hour median
SELECT HOUR(tpep_pickup_datetime) AS hour, fare_amount, tip_amount, total_amount
FROM nyc_taxi.yellow_taxi_clean;

-- pickup borough median
SELECT pickup_borough, fare_amount, tip_amount, total_amount FROM nyc_taxi.yellow_taxi_clean;

-- pickup zone median
SELECT pickup_zone, fare_amount, tip_amount, total_amount FROM nyc_taxi.yellow_taxi_clean;

-- rainy vs non rainy median
SELECT fare_amount, tip_amount, total_amount, CASE WHEN precip > 0 THEN 'Rainy' ELSE 'Non-rainy' END AS rain_case FROM nyc_taxi.yellow_taxi_clean;

-- weekday vs weekend median
SELECT fare_amount, tip_amount, total_amount , CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 'Weekday' ELSE 'Weekend' END AS day_case FROM nyc_taxi.yellow_taxi_clean;



# percentage of fare and tip of total amount 
SELECT SUM(fare_amount)/SUM(total_amount) AS fare_percentage, SUM(tip_amount)/SUM(total_amount) AS tip_percentage
FROM nyc_taxi.yellow_taxi_clean;

# fare amount of total amount by borough 
SELECT pickup_borough, SUM(fare_amount)/SUM(total_amount) as fare_percentage FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_borough
ORDER BY SUM(fare_amount)/SUM(total_amount);

#AVG/SUM of FARE/TIP/TOTAL count by pickup(zone) (TAB)
SELECT pickup_zone, AVG(fare_amount) AS average_fare_amount, AVG(tip_amount) AS average_tip_amount,AVG(total_amount) AS average_total_amount,COUNT(fare_amount) AS trip_count,
SUM(fare_amount) AS total_fare, SUM(tip_amount) AS total_tip, SUM(total_amount) AS total
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_zone
ORDER BY AVG(fare_amount) DESC;

#AVG/SUM of FARE/TIP/TOTAL count by pickup borough (TAB)
SELECT pickup_borough, AVG(fare_amount) AS average_fare_amount, AVG(tip_amount) AS average_tip_amount, AVG(total_amount) AS average_total_amount , COUNT(fare_amount) AS trip_count, 
SUM(fare_amount) AS total_fare, SUM(tip_amount) AS total_tip, SUM(total_amount) AS total
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_borough
ORDER BY AVG(fare_amount) DESC;


#AVG/SUM of FARE/TIP/TOTAL count by pickup service zone
SELECT pickup_service_zone, AVG(fare_amount) AS average_fare_amount, AVG(tip_amount) AS average_tip_amount, AVG(total_amount) AS average_total_amount, COUNT(fare_amount) as trip_count, 
SUM(fare_amount) AS total_fare, SUM(tip_amount) AS total_tip, SUM(total_amount) AS total
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_service_zone
ORDER BY AVG(fare_amount) DESC;


#MEAN OF FARE/TIP/TOTAL 
SELECT AVG(fare_amount) AS average_fare_amount, AVG(tip_amount) AS average_tip_amount, AVG(total_amount) AS average_total_amount FROM nyc_taxi.yellow_taxi_clean;

#TRIP DURATION average fare amount, tip amount, and total amount
SELECT Trip_duration, AVG(fare_amount) AS average_fare_amount, AVG(tip_amount) AS average_tip_amount, AVG(total_amount) AS average_total_amount FROM nyc_taxi.yellow_taxi_clean
GROUP BY Trip_duration
ORDER BY Trip_duration;

#TRIP DURATION SUMMARY STATS
#Trip duration is skewed so it will be cleaned in python
SELECT AVG(Trip_duration) AS average_trip_duration , MAX(Trip_Duration) AS max_trip_duration, MIN(Trip_duration) AS min_trip_duration
FROM nyc_taxi.yellow_taxi_clean;

#COMPARING RAINY VS NON RAINY - AVG hourly fare, tip, total amount within a hour(TAB)
SELECT rain_case, AVG(count_of_rides) as avg_trip_count, AVG(Fare) AS average_fare_total, AVG(Tip) AS average_tip_total, AVG(duration) AS average_duration_total, AVG(total) AS average_total
FROM (SELECT COUNT(*) as count_of_rides, pickup_date, HOUR(tpep_pickup_datetime) as hour_taxi, SUM(fare_amount) as Fare, SUM(tip_amount) as Tip, SUM(total_amount) as total,
AVG(trip_duration) as duration, CASE WHEN precip > 0 THEN 'Rainy' ELSE 'Non-rainy' END AS rain_case FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_date , HOUR(tpep_pickup_datetime), CASE WHEN precip > 0 THEN 'Rainy' ELSE 'Non-rainy' END) AS mini
WHERE hour_taxi IN (10,14,20)
GROUP BY rain_case;

# COMPRARING RAINY VS NON RAINY - COUNT, AVG hourly fare, tip, total amount 
SELECT rain_case, COUNT(*) AS count, AVG(fare_amount) AS average_fare, AVG(tip_amount) AS average_tip, AVG(total_amount) AS average_total, var_samp(fare_amount) AS fare_variance,
var_samp(tip_amount) AS tip_variance, var_samp(total_amount) AS total_variance
FROM (SELECT *, CASE WHEN precip > 0 THEN 'Rainy' ELSE 'Non-rainy' END AS rain_case FROM nyc_taxi.yellow_taxi_clean) AS mini
GROUP BY rain_case;

# WEEKDAY VS WEEKEND - Trips, AVG fare/tip/total/trip duration
SELECT day_case, COUNT(*) AS Trip_count, AVG(fare_amount) AS average_fare, AVG(tip_amount) AS average_tip, AVG(total_amount) AS average_total , 
AVG(Trip_duration) AS average_trip_duration, VAR_SAMP(fare_amount) AS var_fare, VAR_SAMP(tip_amount) AS var_tip, VAR_SAMP(total_amount) AS var_total
FROM (SELECT *, CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 'Weekday' ELSE 'Weekend' END AS day_case FROM nyc_taxi.yellow_taxi_clean) AS mini
GROUP BY day_case;

#WEEKDAY vs WEEKEND Count of rides, AVG fare, AVG trip duration, AVG tip amount, AVG total amount by the hour - borough(TAB)
SELECT 
  pickup_borough,
  
  -- Total trip counts (now counting date/zone/hour combinations)
  SUM(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN total_rides END) AS weekday_total_count,
  SUM(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN total_rides END) AS weekend_total_count,
  
  -- Combinations by day type
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN total_rides END) AS avg_weekday_ride_count,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN total_rides END) AS avg_weekend_ride_count,
  
  -- Average of summed fare amounts (average daily/hourly fare totals)
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN total_fare END) AS avg_hourly_fare_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN total_fare END) AS avg_hourly_fare_Weekend,
  
  -- Average of averaged trip durations
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN avg_duration END) AS avg_duration_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN avg_duration END) AS avg_duration_Weekend,
  
  -- Average of summed tip amounts
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN total_tips END) AS avg_hourly_tips_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN total_tips END) AS avg_hourly_tips_Weekend,
  
  -- Average of summed total amounts
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN total_amount_sum END) AS avg_hourly_total_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN total_amount_sum END) AS avg_hourly_total_Weekend

FROM (
  SELECT 
    pickup_date, 
    pickup_borough, 
    COUNT(*) AS total_rides,
    SUM(fare_amount) AS total_fare,
    AVG(trip_duration) AS avg_duration,
    SUM(tip_amount) AS total_tips,
    SUM(total_amount) AS total_amount_sum,
    HOUR(tpep_pickup_datetime) AS hour_taxi,
    CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN 'Weekday' ELSE 'Weekend' END AS day_type
  FROM nyc_taxi.yellow_taxi_clean
  GROUP BY pickup_date, pickup_borough, HOUR(tpep_pickup_datetime), 
           CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN 'Weekday' ELSE 'Weekend' END
) AS subquery
GROUP BY pickup_borough
ORDER BY pickup_borough;


# temp vs RIDE COUNT/AVG FARE TOTAL/TIP TOTAL/TOTAL AMOUNT at hours with no rush/commute and late night(TAB)
SELECT temp, hour_taxi, AVG(count_of_rides) AS avg_count_of_rides, AVG(fare_sum) AS avg_fair_sum, AVG(tip_sum) AS avg_tip_sum, AVG(total_sum) AS avg_total_sum
FROM (SELECT pickup_date, HOUR(tpep_pickup_datetime) AS hour_taxi, ROUND(temp) AS temp, COUNT(*) AS count_of_rides, SUM(fare_amount) AS fare_sum, SUM(tip_amount) AS tip_sum , SUM(total_amount) AS total_sum 
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime), ROUND(temp)) AS temp_by_hour
WHERE hour_taxi IN (10,14,20)
GROUP BY temp,hour_taxi
ORDER BY temp, hour_taxi;

# precipitation vs RIDE COUNT/AVG FARE TOTAL/TIP TOTAL/TOTAL AMOUNT at hours with no rush/commute and late night(TAB)
SELECT precip, hour_taxi, AVG(count_of_rides) AS avg_count_of_rides, AVG(fare_sum) AS avg_fair_sum, AVG(tip_sum) AS avg_tip_sum, AVG(total_sum) AS avg_total_sum
FROM (SELECT pickup_date, HOUR(tpep_pickup_datetime) AS hour_taxi, precip, COUNT(*) AS count_of_rides, SUM(fare_amount) AS fare_sum, SUM(tip_amount) AS tip_sum , SUM(total_amount) AS total_sum
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime),precip) AS temp_by_hour
WHERE hour_taxi IN (10,14,20)
GROUP BY precip,hour_taxi
ORDER BY precip, hour_taxi;

# windspeed vs RIDE COUNT/AVG FARE TOTAL/TIP TOTAL/TOTAL AMOUNT at hours with no rush/commute and late night(TAB)
SELECT windspeed, hour_taxi, AVG(count_of_rides) AS avg_count_of_rides, AVG(fare_sum) AS avg_fair_sum, AVG(tip_sum) AS avg_tip_sum, AVG(total_sum) AS avg_total_sum
FROM (SELECT pickup_date, HOUR(tpep_pickup_datetime) as hour_taxi, windspeed, COUNT(*) as count_of_rides, SUM(fare_amount) AS fare_sum, SUM(tip_amount) AS tip_sum , SUM(total_amount) AS total_sum
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime),windspeed) AS temp_by_hour
WHERE hour_taxi IN (10,14,20)
GROUP BY windspeed,hour_taxi
ORDER BY windspeed, hour_taxi;

# cloud cover vs RIDE COUNT/AVG FARE TOTAL/TIP TOTAL/TOTAL AMOUNT at hours with no rush/commute and late night(TAB)
SELECT cloud_cover, hour_taxi, AVG(count_of_rides) AS avg_count_of_rides, AVG(fare_sum) as avg_fair_sum, AVG(tip_sum) as avg_tip_sum, AVG(total_sum) as avg_total_sum
FROM (SELECT pickup_date, HOUR(tpep_pickup_datetime) as hour_taxi, ROUND(cloudcover) as cloud_cover, COUNT(*) as count_of_rides, SUM(fare_amount) AS fare_sum, SUM(tip_amount) AS tip_sum , SUM(total_amount) AS total_sum 
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime),ROUND(cloudcover)) AS temp_by_hour
WHERE hour_taxi IN (10,14,20)
GROUP BY cloud_cover,hour_taxi
ORDER BY cloud_cover, hour_taxi;




# percentage of yellow taxi count per passenger count
SELECT passenger_count, 100 * COUNT(*)/SUM(COUNT(*)) OVER() as proportion_of_passenger_count
FROM nyc_taxi.yellow_taxi_clean
GROUP BY passenger_count;

# distribution of hour and day avgs

SELECT hour_per_day, AVG(fare_amount) AS avg_fare, AVG(tip_amount) AS avg_tip , AVG(total_amount) AS avg_total, COUNT(hour_per_day) AS count FROM (SELECT *, HOUR(tpep_pickup_datetime) as hour_per_day FROM nyc_taxi.yellow_taxi_clean) as hour_taxi 
GROUP BY hour_per_day;


#  each hour of a day what is the average fare amount,tip amount, total amount and count of rides(TAB)
SELECT hour_per_day, AVG(fare_amount) AS avg_fare, AVG(tip_amount) AS avg_tip , AVG(total_amount) AS avg_total, COUNT(hour_per_day) AS count FROM (SELECT *, HOUR(tpep_pickup_datetime) as hour_per_day FROM nyc_taxi.yellow_taxi_clean) as hour_taxi 
GROUP BY hour_per_day;

# each hour of a day(hourly total average)
SELECT hour_per_day, AVG(ride_count) AS ride_count_hourly, AVG(fare_total) AS avg_fare_total_hourly, AVG(tip_total) AS avg_tip_total_hourly, AVG(total) AS avg_total_hourly FROM
(SELECT pickup_date, HOUR(tpep_pickup_datetime) AS hour_per_day, COUNT(*) AS ride_count, SUM(fare_amount) as fare_total, SUM(tip_amount) as tip_total, SUM(total_amount) as total
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date ,HOUR(tpep_pickup_datetime)) as day
GROUP BY hour_per_day;


# each condition showing average count of rides in a hour on average
SELECT conditions, AVG(ride_count) AS ride_count_hourly, AVG(fare_total) AS avg_fare_total_hourly, AVG(tip_total) AS avg_tip_total_hourly, AVG(total) AS avg_total_hourly FROM
(SELECT pickup_date , HOUR(tpep_pickup_datetime) as hour_of_day, conditions, COUNT(*) AS ride_count, SUM(fare_amount) as fare_total, SUM(tip_amount) as tip_total, SUM(total_amount) as total
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime),conditions) AS hour_taxi
GROUP BY conditions;

# each condition showing average count of rides on average
SELECT conditions, COUNT(*) AS count, AVG(fare_amount) AS avg_fare, AVG(tip_amount) AS avg_tip, AVG(total_amount) AS avg_total,
VAR_SAMP(fare_amount) AS var_fare, VAR_SAMP(tip_amount) AS var_tip, VAR_SAMP(total_amount) AS var_total
FROM nyc_taxi.yellow_taxi_clean
GROUP BY conditions;






#condition percentage
SELECT conditions, 100 * COUNT(*)/SUM(COUNT(*)) OVER() as Proportion_of_condition_count
FROM nyc_taxi.yellow_taxi_clean
GROUP BY conditions;


# day by day query
SELECT DAYOFWEEK(tpep_pickup_datetime), AVG(fare_amount) AS avg_fare, AVG(tip_amount) AS avg_tip, AVG(total_amount) AS avg_total, COUNT(*) AS count 
FROM nyc_taxi.yellow_taxi_clean GROUP BY DAYOFWEEK(tpep_pickup_datetime);

#   day by day hourly(TAB)
SELECT day_of_week, AVG(ride_count) AS ride_count_hourly, AVG(fare_total) AS avg_fare_total_hourly, AVG(tip_total) AS avg_tip_total_hourly, AVG(total) AS avg_total_hourly FROM
(SELECT pickup_date , DAYOFWEEK(tpep_pickup_datetime) AS day_of_week, HOUR(tpep_pickup_datetime) as hour_of_day, COUNT(*) AS ride_count, SUM(fare_amount) as fare_total, SUM(tip_amount) as tip_total, SUM(total_amount) as total
FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , DAYOFWEEK(tpep_pickup_datetime),HOUR(tpep_pickup_datetime)) as day
GROUP BY day_of_week;
# machine learning query  

SELECT  DAYOFWEEK(pickup_date) as Day , HOUR(tpep_pickup_datetime) as hour_of_day,  CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 0 ELSE 1 END AS is_weekend ,PULocationID, temp, precip,
	windspeed, cloudcover,
    COUNT(*) as ride_count
FROM  nyc_taxi.yellow_taxi_clean
GROUP BY  DAYOFWEEK(pickup_date), HOUR(tpep_pickup_datetime), PULocationID, temp,precip, windspeed, cloudcover, CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 and 6 THEN 0 ELSE 1 END
ORDER BY  DAYOFWEEK(pickup_date), hour_of_day, PULocationID;
#checking for weather multicollinearity

SELECT  DAYOFWEEK(pickup_date) as Day , HOUR(tpep_pickup_datetime) as hour_of_day,  CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 0 ELSE 1 END AS is_weekend ,PULocationID, temp, precip,
	windspeed, cloudcover, dew, humidity, uvindex,
    COUNT(*) as ride_count
FROM  nyc_taxi.yellow_taxi_clean
GROUP BY  DAYOFWEEK(pickup_date), HOUR(tpep_pickup_datetime), PULocationID, temp,precip, windspeed, cloudcover, dew, humidity, uvindex, CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 and 6 THEN 0 ELSE 1 END
ORDER BY  DAYOFWEEK(pickup_date), hour_of_day, PULocationID;




