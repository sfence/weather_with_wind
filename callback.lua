
local S = weather_with_wind.S;

-- default callback

weather_with_wind.callback_get_new_weather = function(weather_old)
    local weather_new = table.copy(weather_old);
    local time_diff = weather_old.time_end - weather_old.time_start;
    weather_new.time_start = weather_old.time_end+time_diff;
    weather_new.time_end = weather_old.time_end+2*time_diff;
    
    return weather_new;
  end


weather_with_wind.callback_get_humidity = function(pos)
    local pos_humidity = minetest.get_humidity(pos);
    
    return pos_humidity;
  end
weather_with_wind.callback_get_temperature = function(pos)
    local pos_heat = minetest.get_heat(pos);
    
    return pos_heat - 25;
  end

weather_with_wind.callback_get_temperature_and_humidity_in_time = function(temperature, humidity)
    return temperature, humidity;
  end
