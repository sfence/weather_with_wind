
local S = weather_with_wind.S;
local storage = weather_with_wind.storage;

local weather_time_diff = 0;
local weather_time_update = 10;
local weather_time = 0;
local weather_old = weather_with_wind.clear_weather;
local weather_new = weather_with_wind.clear_weather;
local weather_actual = weather_with_wind.clear_weather;

local player_time_update = 1;
local player_time_diff = player_time_update;
local players_adaptation = {};

local hud_screen_def = {
  hud_elem_type = "image",
  text = "weather_with_wind_screen.png",
  scale = {x=-100,y=-100},
  alignment = {x=1,y=1},
};
 
local clear_player_adaptation = {
      max_sunlight = 1.0,
      wind = {x=0,z=0},
      clouds_height = 120,
      downfalls={},
      screen = nil,
      last_clear_pos = nil,
    };

local function weather_with_wind_player_weather(player)
  local player_pos = player:getpos();
  local player_name = player:get_player_name();
  
  --minetest.log("warning", "w_a: "..dump(weather_actual));
  local weather_localized = weather_with_wind.localized_weather(weather_actual, player_pos);
  --minetest.log("warning", "w_l: "..dump(weather_localized));
  
  local clouds = table.copy(weather_localized.clouds);
  clouds.speed = weather_localized.wind;
  player:set_clouds(clouds);
  
  --minetest.log("warning", "clouds update. "..dump(clouds))
  
  local player_adaptation = table.copy(clear_player_adaptation);
  player_adaptation.screen = players_adaptation[player_name].screen;
  player_adaptation.last_downfall_pos = players_adaptation[player_name].last_downfall_pos;
  local max_sunlight = 1.0;
  
  if (player_pos.y<clouds.height) then
    player_adaptation.wind = table.copy(weather_localized.wind);
    
    for falling_index,falling in pairs(weather_localized.fallings) do
      --minetest.log("warning", "p_f: "..dump(falling));
      local downfall = table.copy(falling.downfall);
      downfall.amount = falling.precipitation;
      downfall.darken_color = falling.darken_color;
      
      if (downfall.amount>0) then
        player_adaptation.downfalls[falling_index] = downfall;
      end
    end
    
    -- alpha 255 means full opaque/ no trasnsparent
    max_sunlight = (weather_localized.clouds.color.a/255);
    max_sunlight = 1-(max_sunlight*weather_localized.clouds.density);
  end
  
  players_adaptation[player_name] = player_adaptation;
end

local function weather_with_wind_apply_weather()
  if (weather_new.time_end<=weather_time) then
    local time_minus = weather_old.time_end;
    weather_new.time_start = weather_new.time_start - time_minus;
    weather_new.time_end = weather_new.time_end - time_minus;
    weather_old = weather_new;
    weather_new = weather_with_wind.callback_get_new_weather(weather_new);
    weather_actual = weather_with_wind.actual_weather(weather_old, weather_actual, weather_time);
    --minetest.log("warning", "w_o: "..dump(weather_old));
    --minetest.log("warning", "w_n: "..dump(weather_new));
    --minetest.log("warning", "w_a: "..dump(weather_actual));
    
    weather_time_update = weather_actual.update_interval;
    
    weather_time = weather_time - time_minus;
  end
  
  for _, player in ipairs(minetest.get_connected_players()) do
    weather_with_wind_player_weather(player);
  end
  
  --minetest.log("warning", "clouds update")
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
weather_with_wind_apply_weather();

local function colorToText(color)
  return string.format("%02X%02X%02X%02X", color.r, color.g, color.b, color.a);
end
local function colorMix(colorSrc, colorDst)
  local srcA = colorSrc.a/255;
  local dstA = colorDst.a/255;
  local outA = srcA + dstA*(1-srcA);
  local colorOut = {
      r = (colorSrc.r*srcA+colorDst.r*dstA*(1-srcA))/outA,
      g = (colorSrc.g*srcA+colorDst.g*dstA*(1-srcA))/outA,
      b = (colorSrc.b*srcA+colorDst.b*dstA*(1-srcA))/outA,
      a = outA,
    };
  return colorOut;
end

local function weather_with_wind_globalstep(dtime)
  weather_time_diff = weather_time_diff + dtime;
  if (weather_time_diff>=weather_time_update) then
    weather_time_diff = weather_time_diff - weather_time_update;
    weather_time = weather_time + weather_time_update;
    
    weather_with_wind_apply_weather();
    
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
      
      local player_adaptation = players_adaptation[player_name];
      
      -- to meka minetest.get_node_light works
      player_pos.x = math.floor(player_pos.x+0.5);
      player_pos.y = math.floor(player_pos.y+0.5);
      player_pos.z = math.floor(player_pos.z+0.5);
      
      --minetest.log("warning", "p_df: "..dump(player_adaptation))
      --minetest.log("warning", "pos: "..dump(player_pos))
      
      -- change light intensity
      if (player_adaptation.max_sunlight < 1.0) then
        player:override_day_night_ratio(player_adaptation.max_sunlight);
      else
        player:override_day_night_ratio(nil)
      end
      
      -- if player is under sun and in windy location?
      
      local midnight_light = minetest.get_node_light(player_pos, 0.0);
      if (midnight_light==nil) then
        local vm = minetest.get_voxel_manip(player_pos, player_pos);
        midnight_light = minetest.get_node_light(player_pos, 0.0);
      end
      local midday_light = minetest.get_node_light(player_pos, 0.5);
      local wind_speed = math.sqrt(player_adaptation.wind.x^2 + player_adaptation.wind.z^2);
      if      (midnight_light<midday_light)
          and (wind_speed>0) then
       -- local hud_text = hud_screen_def.text .. "^[colorize:#" .. colorToText(player_adaptation.darken_color);
        --player:hud_change(player_adaptation.screen, "text", hud_text)
      end
      
      local darken_color = {r=255,g=255,b=255,a=0};
      
      for _,downfall in pairs(player_adaptation.downfalls) do
        --minetest.log("warning", "df: "..dump(downfall))
        downfall = table.copy(downfall); 
          
        -- apply player pos
        downfall.minpos = vector.add(downfall.minpos, player_pos);
        downfall.maxpos = vector.add(downfall.maxpos, player_pos);
        
        -- prevent falling from position above clouds
        local limit_fall_height = player_adaptation.clouds_height;
        if (downfall.minpos.y>limit_fall_height) then
          downfall.minpos.y = limit_fall_height;
        end
        if (downfall.maxpos.y>limit_fall_height) then
          downfall.maxpos.y = limit_fall_height;
        end
        
        -- spawn position change due to wind_pos
        local fall_speed = (downfall.minvel.y + dewnfall.maxvel.y)/2;
        local fall_height = limit_fall_height - player_pos.y;
        local wind_pos = vector.multiply(player_adaptation.wind,-fall_height/fall_speed);
        local fall_pos = vector.add(player_pos, wind_pos);
        
        local clear = minetest.line_of_sight(fall_pos, player_pos);
        if (clear==true) then
          players_adaptation[player_name].last_clear_pos = math.copy(player_pos);
        end
        
        -- posible multi position check
        if (0) then
          if (clear==false) then
            local pos_diff = {x=0,y=0,z=0};
            for x=downfall.minpos.x,downfall.maxpos.x,1 do
              pos_diff.x = x;
              for z=downfall.minpos.z,downfall.maxpos.z,1 do
                pos_diff.z = z;
                --local fall_pos = vector.add(fall_pos, pos_diff);
                local part_clear = minetest.line_of_sight(fall_pos, player_pos);
                if (part_clear==true) then
                  clear = true;
                  break;
                end
              end
              if (clear==true) then
                break;
              end
            end
          end
        end
          
        if (clear==true) then
          darken_color = colorMix(downfall.darken_color, darken_color);
          
          -- spawn position change due to wind_pos
          local fall_speed = (downfall.minvel.y + dewnfall.maxvel.y)/2;
          local fall_height = (downfall.minpos.y + dewnfall.maxpos.y)/2-player_pos.y;
          local wind_pos = vector.multiply(player_adaptation.wind,-fall_height/fall_speed);
          downfall.minpos = vector.add(downfall.minpos, wind_pos);
          downfall.maxpos = vector.add(downfall.maxpos, wind_pos);
          
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
      
      local hud_text = hud_screen_def.text .. "^[colorize:#" .. colorToText(darken_color);
      --minetest.log("warning", "hud: "..hud_text);
      player:hud_change(player_adaptation.screen, "text", hud_text)
    end
  end
end

local function weather_with_wind_joinplayer(player)
  local player_name = player:get_player_name();
  
  players_adaptation[player_name] = table.copy(clear_player_adaptation);
  players_adaptation[player_name].screen = player:hud_add(hud_screen_def);
  weather_with_wind_player_weather(player);
  -- do it wiht after, to make get_node_light and set_sky works.
  --minetest.after(0.1, weather_with_wind_player_weather, player);
end
local function weather_with_wind_leaveplayer()
  
end

minetest.register_globalstep(weather_with_wind_globalstep);
minetest.register_on_joinplayer(weather_with_wind_joinplayer);

minetest.register_on_shutdown( function()
    storage:set_int("weather_time_diff", weather_time_diff);
  end);

-- function for other mods
weather_with_wind.get_localized_weather = function(pos)
    local weather_localized = weather_with_wind.localized_weather(weather_actual, pos);
    return weather_localized;
  end
