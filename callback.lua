
local S = WeatherWithWind.S;

-- default callback

WeatherWithWind.callback_get_new_weather = function(weather_old)
    local weather_new = table.copy(weather_old);
    local time_diff = weather_old.time_end - weather_old.time_start;
    weather_new.time_start = weather_old.time_end+time_diff;
    weather_new.time_end = weather_old.time_end+2*time_diff;
  end


WeatherWithWind.callback_get_temperature = function(pos)
    local pos_heat = minetest.get_heat(pos);
    
    return pos_heat - 25;
  end
