-- Mods which include functions for animals

-- Definitions made by this mod that other mods can use too
weather_with_wind = {}

-- localize support via initlib
weather_with_wind.S = function(s) return s end
if minetest.get_modpath("intllib") and intllib then
  weather_with_wind.S = intllib.Getter()
end

-- storage
weather_with_wind.storage = minetest.get_mod_storage();

-- Load files
local weather_with_wind_path = minetest.get_modpath("weather_with_wind")

dofile(weather_with_wind_path.."/callback.lua")
dofile(weather_with_wind_path.."/weathers.lua")
dofile(weather_with_wind_path.."/step.lua")

weather_with_wind.S = nil

