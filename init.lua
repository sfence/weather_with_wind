-- Mods which include functions for animals

-- Definitions made by this mod that other mods can use too
WeatherWithWind = {}

-- localize support via initlib
WeatherWithWind.S = function(s) return s end
if minetest.get_modpath("intllib") and intllib then
  WeatherWithWind.S = intllib.Getter()
end

-- Load files
local WeatherWithWind_path = minetest.get_modpath("weather_with_wind")

dofile(WeatherWithWind_path.."/callback.lua")
dofile(WeatherWithWind_path.."/weathers.lua")
dofile(WeatherWithWind_path.."/step.lua")

WeatherWithWind.S = nil

