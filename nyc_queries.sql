SELECT * FROM nyc_taxi.yellow_taxi;
SELECT * FROM nyc_taxi.nyc_weather;
# merging data together 
ALTER TABLE nyc_taxi.yellow_taxi
ADD COLUMN pickup_date DATE;


UPDATE nyc_taxi.yellow_taxi
SET pickup_date = DATE(tpep_pickup_datetime)
WHERE pickup_date IS NULL;

DESCRIBE nyc_taxi.nyc_weather;

  
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
#26 rows have temp that is null we remove it as date is not between mar-apr
SELECT COUNT(*) AS TOTAL_ROWS,
SUM(CASE WHEN temp is NULL THEN 1 ELSE 0 END) as missing_temp,
SUM(CASE WHEN pickup_zone IS NULL THEN 1 ELSE 0 END) as missing_zones,
SUM(CASE WHEN dropoff_zone IS NULL THEN 1 ELSE 0 END) as missing_dropoff_zones
FROM nyc_taxi.taxi_weather_prejoined;

SELECT * FROM nyc_taxi.taxi_weather_prejoined
WHERE temp is NULL;

SELECT COUNT(*)
FROM nyc_taxi.taxi_weather_prejoined
WHERE YEAR(tpep_pickup_datetime) = 2024 AND MONTH(tpep_pickup_datetime) BETWEEN 3 AND 4;

SELECT COUNT(*) 
FROM nyc_taxi.yellow_taxi;

#MULTIPLE DUPLICATES
SELECT fare_amount,tpep_pickup_datetime, tpep_dropoff_datetime
FROM nyc_taxi.taxi_weather_prejoined
GROUP BY fare_amount,tpep_pickup_datetime, tpep_dropoff_datetime
HAVING COUNT(*) > 1; 

#check the largest fair amount
SELECT
  fare_amount,
  COUNT(*) AS freq
FROM nyc_taxi.taxi_weather_prejoined
GROUP BY fare_amount
ORDER BY fare_amount DESC
LIMIT 1000;

SELECT DISTINCT PULocationID FROM nyc_taxi.yellow_taxi_clean WHERE PULocationID NOT BETWEEN 1 and 265;
SELECT DISTINCT DOLocationID FROM nyc_taxi.yellow_taxi_clean WHERE DOLocationID NOT BETWEEN 1 and 265;
#checked if there are 'N/A' or NULLS with pickup and dropoff boroughs,zones,and service zones
SELECT COUNT(*) AS null_count
FROM nyc_taxi.yellow_taxi_clean
WHERE pickup_borough = 'N/A';

SELECT COUNT(*) AS null_count
FROM nyc_taxi.yellow_taxi_clean
WHERE pickup_borough is NULL;

#cleaned table removing outliers, duplicates, nulls due to out of date range
CREATE TABLE nyc_taxi.yellow_taxi_clean AS
SELECT DISTINCT *, TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime,tpep_dropoff_datetime) as Trip_Duration
FROM nyc_taxi.taxi_weather_prejoined
WHERE passenger_count > 0
  AND trip_distance > 0
  AND fare_amount > 0
  AND passenger_count <= 6
  AND trip_distance <= 100
  AND fare_amount <= 100
  AND TEMP IS NOT NULL
  AND PULocationID != 265 AND PULocationID != 264
  AND DOLocationID != 265 AND DOLocationID != 264
  AND TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime,tpep_dropoff_datetime) BETWEEN 1 AND 60;

# trip duration >= to 60 is 1-2% of the data and most taxis duration are less than an hour so we will focus on between 1 and 60
SELECT SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime,tpep_dropoff_datetime) > 40 THEN 1 ELSE 0 END)/COUNT(*) FROM nyc_taxi.taxi_weather_view;


# add a trip duration column (Feature engineer)
ALTER TABLE nyc_taxi.yellow_taxi_clean
ADD COLUMN Trip_Duration FLOAT;


UPDATE nyc_taxi.yellow_taxi_clean
SET Trip_Duration = TIMESTAMPDIFF(MINUTE, tpep_pickup_datetime,tpep_dropoff_datetime);


SELECT COUNT(*) FROM nyc_taxi.yellow_taxi_clean;

#EDA query data such as summart stats and easy queries to understand and get a feel of the data

SELECT * FROM nyc_taxi.yellow_taxi_clean;


#AVG FARE/TRIP count by pickup(zone)
SELECT pickup_zone, AVG(fare_amount), COUNT(fare_amount) as trip_count FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_zone
ORDER BY AVG(fare_amount) DESC;

#AVG FARE/TRIP count by pickup borough
SELECT pickup_borough, AVG(fare_amount), COUNT(fare_amount) as trip_count FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_borough
ORDER BY AVG(fare_amount) DESC;


#SUMMARY STATS OF FARE
SELECT AVG(fare_amount) FROM nyc_taxi.yellow_taxi_clean;

#TRIP DISTANCE SUMMARY STATS
SELECT Trip_duration, AVG(fare_amount) FROM nyc_taxi.yellow_taxi_clean
GROUP BY Trip_duration
ORDER BY Trip_duration;

#TRIP DURATION SUMMARY STATS
#Trip duration is skewed so it will be cleaned in python
SELECT AVG(Trip_duration), MAX(Trip_Duration), MIN(Trip_duration)
FROM nyc_taxi.yellow_taxi_clean;

#COMPARING RAINY VS NON RAINY 
SELECT rain_case, COUNT(*) as Trip_count, AVG(fare_amount), AVG(Trip_duration) FROM (SELECT *, CASE WHEN precip > 0 THEN 'Rainy' ELSE 'Non-rainy' END AS rain_case FROM nyc_taxi.yellow_taxi_clean) AS mini
GROUP BY rain_case;

#TRIPS PER WEEKDAY VS WEEKEND 
SELECT day_case, COUNT(*) AS Trip_count, AVG(fare_amount), AVG(Trip_duration) FROM (SELECT *, CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 'Weekday' ELSE 'Weekend' END AS day_case FROM nyc_taxi.yellow_taxi_clean) AS mini
GROUP BY day_case;

#Trips PER WEEKDAY VS WEEK BY BOROUGH
SELECT 
  pickup_zone,
  
  -- Total trip counts
  COUNT(*) AS Trip_count,
  -- Trip counts
  COUNT(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN 1 END) AS Trip_count_Weekday,
  COUNT(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN 1 END) AS Trip_count_Weekend,
  
  -- Average fare amounts
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN fare_amount END) AS Avg_fare_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN fare_amount END) AS Avg_fare_Weekend,
  
  -- Average trip duration
  AVG(CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 AND 6 THEN Trip_duration END) AS Avg_duration_Weekday,
  AVG(CASE WHEN DAYOFWEEK(pickup_date) NOT BETWEEN 2 AND 6 THEN Trip_duration END) AS Avg_duration_Weekend

FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_zone
ORDER BY pickup_zone;

# temp vs Ride count/Fare sum avg at hours with no rush/commute and late night
SELECT temp, hour_taxi, AVG(count_of_rides), AVG(fare_sum) as avg_fair_sum
FROM (SELECT pickup_date, HOUR(tpep_pickup_datetime) as hour_taxi, ROUND(temp) as temp, COUNT(*) as count_of_rides, SUM(fare_amount) AS fare_sum FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime), ROUND(temp)) AS temp_by_hour
WHERE hour_taxi IN (10,14,20)
GROUP BY temp,hour_taxi
ORDER BY temp, hour_taxi;



#Top zone, boroughs, pickup_service_zone

SELECT pickup_zone, SUM(fare_amount)
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_zone
ORDER BY SUM(fare_amount) desc;

SELECT pickup_borough, SUM(fare_amount)
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_borough
ORDER BY SUM(fare_amount) desc;

SELECT pickup_service_zone, SUM(fare_amount)
FROM nyc_taxi.yellow_taxi_clean
GROUP BY pickup_service_zone
ORDER BY SUM(fare_amount) desc;

# percentage of yellow taxi count per passenger count
SELECT passenger_count, 100 * COUNT(*)/SUM(COUNT(*)) OVER() as Proportion_of_passenger_count
FROM nyc_taxi.yellow_taxi_clean
GROUP BY passenger_count;


# for each hour of a day what is the average fare amount and count of rides 
SELECT hour_per_day,AVG(fare_amount), COUNT(hour_per_day) FROM (SELECT *, HOUR(tpep_pickup_datetime) as hour_per_day FROM nyc_taxi.yellow_taxi_clean) as hour_taxi 
GROUP BY hour_per_day;

# each condition showing average fare amount and count of rides
SELECT conditions, AVG(ride_count) FROM (SELECT pickup_date , HOUR(tpep_pickup_datetime) as hour_of_day, conditions, COUNT(*) AS ride_count FROM nyc_taxi.yellow_taxi_clean GROUP BY pickup_date , HOUR(tpep_pickup_datetime),conditions) AS hour_taxi
GROUP BY conditions;

#condition percentage
SELECT conditions, 100 * COUNT(*)/SUM(COUNT(*)) OVER() as Proportion_of_condition_count
FROM nyc_taxi.yellow_taxi_clean
GROUP BY conditions;




# machine learning query  
SELECT   DAYOFWEEK(pickup_date) as Day , HOUR(tpep_pickup_datetime) as hour_of_day,  CASE WHEN DAYOFWEEK(pickup_date) BETWEEN  2 and 6 THEN 0 ELSE 1 END AS is_weekend ,PULocationID, temp, 
	CASE WHEN LOWER(conditions) LIKE '%rain%' THEN 1 ELSE 0 END AS is_rain,
	CASE WHEN LOWER(conditions) LIKE '%overcast%' THEN 1 ELSE 0 END AS is_overcast,
	CASE WHEN LOWER(conditions) LIKE '%partially cloudy%' THEN 1 ELSE 0 END AS is_partially_cloudy,
	CASE WHEN LOWER(conditions) LIKE '%clear%' THEN 1 ELSE 0 END AS is_clear,
    COUNT(*) as ride_count
FROM  nyc_taxi.yellow_taxi_clean
GROUP BY  DAYOFWEEK(pickup_date), HOUR(tpep_pickup_datetime), PULocationID, LOWER(conditions), temp, CASE WHEN DAYOFWEEK(pickup_date) BETWEEN 2 and 6 THEN 0 ELSE 1 END,
	CASE WHEN LOWER(conditions) LIKE '%rain%' THEN 1 ELSE 0 END,
	CASE WHEN LOWER(conditions) LIKE '%overcast%' THEN 1 ELSE 0 END,
	CASE WHEN LOWER(conditions) LIKE '%partially cloudy%' THEN 1 ELSE 0 END,
	CASE WHEN LOWER(conditions) LIKE '%clear%' THEN 1 ELSE 0 END
ORDER BY  DAYOFWEEK(pickup_date), hour_of_day, PULocationID;



