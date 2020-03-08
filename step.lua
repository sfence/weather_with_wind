
local S = WeatherWithWind.S;

local time_diff = 0;

local function WeatherWithWind_globalstep(dtime)
  time_diff = time_diff + dtime;
  if (time_diff>10) then
    time_diff = time_diff - 10;
    
    for _, player in ipairs(minetest.get_connected_players()) do
      local clouds = player:get_clouds();
    
      clouds.density = clouds.density + 0.05;
      player:set_clouds(clouds);
    end
    minetest.log("warning", "clouds update.")
  end
end


minetest.register_globalstep(WeatherWithWind_globalstep);

