import streamlit as st
import pandas as pd
import joblib

# Load model
xgb_model = joblib.load('best_xgboost_model.pkl')

# Load lookup CSV
lookup_zone = pd.read_csv('taxi_zone_lookup.csv')

# Create zone dictionary
zone_dict = dict(zip(lookup_zone['LocationID'], lookup_zone['Zone']))
zone_dict.pop(264, None)
zone_dict.pop(265, None)

# Streamlit inputs
pickup_zone = st.selectbox('Select Pickup Zone', options=list(zone_dict.keys()), format_func=lambda x: zone_dict[x])
day = st.selectbox('Select Day of Week', options=[1,2,3,4,5,6,7], format_func=lambda x: ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][x-1])
# format to display time am/pm
hour_of_day = st.selectbox('Select Hour of Day', options=list(range(24)), format_func=lambda x: f"{x % 12 or 12} {'AM' if x < 12 else 'PM'}")
temp = st.slider('Select Temperature (°F)', min_value=-10, max_value=100, value=70)
precip = st.slider('Select Precipitation (inches)', min_value=0.0, max_value=4.0, value=0.0)
windspeed = st.slider('Select Windspeed (mph)', min_value=0, max_value=35, value=10)
cloudcover = st.slider('Select Cloud Cover (%)', min_value=0, max_value=100, value=50)

# Prepare input data
input_data = pd.DataFrame({
    'Day':[day],
    'hour_of_day':[hour_of_day],
    'PULocationID':[pickup_zone],
    'temp':[temp],
    'precip':[precip],
    'windspeed':[windspeed],
    'cloudcover':[cloudcover]
})

# Predict
predicted_rides = xgb_model.predict(input_data)

# Display results
st.write(f'Predicted Number of Rides: {int(predicted_rides[0]):,}')

