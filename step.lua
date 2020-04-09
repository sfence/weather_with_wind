
local S = WeatherWithWind.S;
local storage = WeatherWithWind.storage;

local weather_time_diff = 0;
local weather_time_update = 10;
local weather_time = 0;
local weather_old = WeatherWithWind.clear_weather;
local weather_new = WeatherWithWind.clear_weather;
local weather_actual = WeatherWithWind.clear_weather;

local player_time_update = 1;
local player_time_diff = player_time_update;
local players_downfalls = {};

local function WeatherWithWind_player_weather(player)
  local player_pos = player:getpos();
  local player_name = player:get_player_name();
  
  --minetest.log("warning", "w_a: "..dump(weather_actual));
  local weather_localized = WeatherWithWind.localized_weather(weather_actual, player_pos);
  --minetest.log("warning", "w_l: "..dump(weather_localized));
  
  local clouds = table.copy(weather_localized.clouds);
  clouds.speed = weather_localized.wind;
  player:set_clouds(clouds);
  
  --minetest.log("warning", "clouds update. "..dump(clouds))
  
  local player_downfalls = {
      wind = nil,
      clouds_height = clouds.height,
      downfalls={},
    };
  
  if (player_pos.y<clouds.height) then
    player_downfalls.wind = table.copy(weather_localized.wind);
    
    for falling_index,falling in pairs(weather_localized.fallings) do
      --minetest.log("warning", "p_f: "..dump(falling));
      local downfall = table.copy(falling.downfall);
      downfall.amount = falling.precipitation;
      
      if (downfall.amount>0) then
        player_downfalls.downfalls[falling_index] = downfall;
      end
    end
  end
  
  players_downfalls[player_name] = player_downfalls;
end

local function WeatherWithWind_apply_weather()
  if (weather_new.time_end<=weather_time) then
    local time_minus = weather_old.time_end;
    weather_new.time_start = weather_new.time_start - time_minus;
    weather_new.time_end = weather_new.time_end - time_minus;
    weather_old = weather_new;
    weather_new = WeatherWithWind.callback_get_new_weather(weather_new);
    weather_actual = WeatherWithWind.actual_weather(weather_old, weather_actual, weather_time);
    --minetest.log("warning", "w_o: "..dump(weather_old));
    --minetest.log("warning", "w_n: "..dump(weather_new));
    --minetest.log("warning", "w_a: "..dump(weather_actual));
    
    time_update = weather_actual.update_interval;
    
    weather_time = weather_time - time_minus;
  end
  
  for _, player in ipairs(minetest.get_connected_players()) do
    WeatherWithWind_player_weather(player);
  end
  
  minetest.log("warning", "clouds update")
end

-- get data from storage
if (storage:contains("weather_time_diff")==true) then
  weather_time_diff = storage:get_int("weather_time_diff");
  storage:set_string("weather_time_diff", "");
end
if (storage:contains("weather_time")==true) then
  weather_time = storage:get_int("weather_time");
end
if (storage:contains("weather_old")==true) then
  weather_old = minetest.deserialize(storage:get_string("weather_old"));
end
if (storage:contains("weather_new")==true) then
  weather_old = minetest.deserialize(storage:get_string("weather_new"));
end

-- calculate actual weather from loaded data
WeatherWithWind_apply_weather();

local function WeatherWithWind_globalstep(dtime)
  weather_time_diff = weather_time_diff + dtime;
  if (weather_time_diff>=weather_time_update) then
    weather_time_diff = weather_time_diff - weather_time_update;
    weather_time = weather_time + weather_time_update;
    
    WeatherWithWind_apply_weather();
    
    storage:set_int("weather_time", weather_time);
    storage:set_string("weather_old", minetest.serialize(weather_old));
    storage:set_string("weather_new", minetest.serialize(weather_new));
  end
  
  player_time_diff = player_time_diff + dtime;
  if (player_time_diff>=player_time_update) then
    player_time_diff = player_time_diff - player_time_update;
    for _, player in ipairs(minetest.get_connected_players()) do
      local player_name = player:get_player_name();
      local player_pos = player:getpos();
      
      local player_downfalls = players_downfalls[player_name];
      
      --minetest.log("warning", "p_df: "..dump(player_downfalls))
      
      for _,downfall in pairs(player_downfalls.downfalls) do
        --minetest.log("warning", "df: "..dump(downfall))
        downfall = table.copy(downfall); 
          
          -- prevent falling from position above clouds
          local limit_fall_height = player_downfalls.clouds_height - player_pos.y;
          if (downfall.minpos.y>limit_fall_height) then
            downfall.minpos.y = limit_fall_height;
          end
          if (downfall.maxpos.y>limit_fall_height) then
            downfall.maxpos.y = limit_fall_height;
          end
          
          -- spawn position change due to wind_pos
          local fall_speed = (downfall.minvel.y + dewnfall.maxvel.y)/2;
          local fall_height = (downfall.minpos.y + dewnfall.maxpos.y)/2;
          local wind_pos = vector.multiply(player_downfalls.wind,-fall_height/fall_speed);
          vector.add(downfall.minpos, player_pos)
      
          minetest.add_particlespawner(
            {
              amount=downfall.amount*player_time_update, time=player_time_update,
              minpos=downfall.minpos, maxpos=downfall.maxpos,
              minvel=downfall.minvel, maxvel=downfall.maxvel,
              minacc=downfall.minacc, maxacc=downfall.maxacc,
              minexptime=downfall.minexptime, maxexptime=downfall.maxexptime,
              minsize=downfall.minsize, maxsize=downfall.maxsize,
              collisiondetection=true, collision_removal=true,
              object_collision = false,
              --attached = nil,
              vertical=true,
              texture=downfall.texture,
              player=player_name,
            })
      end
    end
  end
end

local function WeatherWithWind_joinplayer(player)
  local player_name = player:get_player_name();
  
  players_downfalls[player_name] = {downfalls={}};
  WeatherWithWind_player_weather(player);
end
local function WeatherWithWind_leaveplayer()
  
end

minetest.register_globalstep(WeatherWithWind_globalstep);
minetest.register_on_joinplayer(WeatherWithWind_joinplayer);

minetest.register_on_shutdown( function()
    storage:set_int("weather_time_diff", weather_time_diff);
  end);

