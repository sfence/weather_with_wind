
local S = weather_with_wind.S;

-- weathers

-- weather
--
-- wind -> {x, y} 
-- temperature -> temeraturae change by weather, positive or negative
--             -> celsius degrees
-- humidity -> 0 - 100
--          -> when 50, original humadity is used
--          -> when 0, 0 humidity everywhere
--          -> when 100, 100 humidity everywhere
--          -> when other -> humidity is modificed by linear function
--
-- clouds -> like parameters for set_clouds function
--        -> only speed is used from wind
-- 
-- fallings -> table with falling textures and parameters for different temperatures
--          -> only one falling definition is expected in basic weather
--          -> precipitation -> intensity of falling
--          -> water_precipitation -> true if intensity depend on humanity and cloud density 
--          -> sound -> specify sound, if same should be play
--          -> sound_gain -> sound gain depends on precipitation
--          -> downfalls -> table of downfalls by temperature
--              -> minpos ->
--              -> maxpos ->
--              -> minvel ->
--              -> maxvel ->
--              -> minacc ->
--              -> maxacc ->
--              -> minexptime ->
--              -> maxexptime ->
--              -> minsize ->
--              -> maxsize ->
--              -> texture -> picture
--              -> animation ->
--              -> glow ->
--
-- lightning_density -> lighting density
--
-- update_interval -> seconds between weather updates
--
-- time_start
-- time_end

weather_with_wind.clear_weather = {
    wind = {x=0,z=2},
    temperature = 0,
    humidity = 50,
    clouds = {
      density = 0.4,
      color = {--#fff0f0e5
          r = 0xf0,
          g = 0xf0,
          b = 0xff,
          a = 0xe5,
        },
      ambient = {--#000000,
          r = 0x00,
          g = 0x00,
          b = 0x00,
          a = 0xff,
        },
      height = 120,
      thickness = 16,
    },
    fallings = {
      {
        precipitation = 0,
        water_precipitation = false,
        darken_color = {--#ffffff00
          r = 0xff,
          g = 0xff,
          b = 0xff,
          a = 0x00,
        },
        downfalls = {},
      },
    },
    
    lightning_density = 0,
    
    update_interval = 10,
    
    time_start = 0,
    time_end = 600,
    
    stable = true,
  };

weather_with_wind.actual_weather = function (weather_old, weather_new, time)
    if (time<weather_old.time_end) then
      return weather_old;
    end
    if (time<weather_new.time_start) then
      return weather_new;
    end
    
    local new_part = (time-weather_old.time_end)/(weather_new.time_start-weather_old.time_end);
    if (new_part>1) then
      new_part = 1;
    end
    if (new_part<0) then
      new_part = 0;
    end
    local old_part = 1-new_part;
    
    local actual_weather = {
        wind = {
            x = weather_old.wind.x*old_part + weather_new.wind.x*new_part,
            z = weather_old.wind.z*old_part + weather_new.wind.z*new_part,
          },
        temperature = weather_old.temperature*old_part + weather_new.temperature*new_part,
        humidity = weather_old.humidity*old_part + weather_new.humidity*new_part,
        clouds = {
          density = weather_old.clouds.density*old_part + weather_new.clouds.density*new_part,
          color = {
              r = math.floor(weather_old.clouds.color.r*old_part + weather_new.clouds.color.r*new_part),
              g = math.floor(weather_old.clouds.color.g*old_part + weather_new.clouds.color.g*new_part),
              b = math.floor(weather_old.clouds.color.b*old_part + weather_new.clouds.color.b*new_part),
              a = math.floor(weather_old.clouds.color.a*old_part + weather_new.clouds.color.a*new_part),
            },
          ambient = {
              r = math.floor(weather_old.clouds.ambient.r*old_part + weather_new.clouds.ambient.r*new_part),
              g = math.floor(weather_old.clouds.ambient.g*old_part + weather_new.clouds.ambient.g*new_part),
              b = math.floor(weather_old.clouds.ambient.b*old_part + weather_new.clouds.ambient.b*new_part),
              a = math.floor(weather_old.clouds.ambient.a*old_part + weather_new.clouds.ambient.a*new_part),
            },
          height = weather_old.clouds.height*old_part + weather_new.clouds.height*new_part,
          thickness = weather_old.clouds.thickness*old_part + weather_new.clouds.thickness*new_part,
        },
        fallings = {
          {
            precipitation = weather_old.fallings[1].precipitation*old_part,
            water_precipitation = weather_old.fallings[1].water_precipitation,
            darken_color = weather_old.fallings[1].darken_color,
            downfalls = weather_old.fallings.downfalls,
          },
          {
            precipitation = weather_new.fallings[1].precipitation*new_part,
            water_precipitation = weather_new.fallings[1].water_precipitation,
            darken_color = weather_new.fallings[1].darken_color,
            downfalls = weather_new.fallings.downfalls,
          },
        },
        
        lightning_density = weather_old.lightning_density*old_part + weather_new.lightning_density*new_part,
        
        update_interval = weather_old.update_interval*old_part + weather_new.update_interval*new_part,
        
        time_start = weather_old.time_end,
        time_end = weather_new.time_start,
        
        stable = false,
      };
    
    return actual_weather;
  end

weather_with_wind.localized_weather = function (weather_actual, pos)
    --minetest.log("warning", "act weather: "..dump(weather_actual))
    -- change local humadity by weather humadity
    local pos_humidity = weather_with_wind.callback_get_humidity(pos);
    local pos_temperature = weather_with_wind.callback_get_temperature(pos);
    
    local humidity_change = (weather_actual.humidity-50)/50;
    
    if (humidity_change>0) then
      pos_humidity = pos_humidity + (100-pos_humidity)*humidity_change;
    else
      pos_humidity = pos_humidity + pos_humidity*humidity_change;
    end
    
    pos_temperature = pos_temperature + weather_actual.temperature;
    
    pos_temperature, pos_humidity = weather_with_wind.callback_get_temperature_and_humidity_in_time(pos_temperature, pos_humidity);
    
    -- change cloud denstiy by local humadity
    local cloud_density = weather_actual.clouds.density;
    
    cloud_density = cloud_density * 0.1 + cloud_density * 0.9 * (pos_humidity/75);
    if (cloud_density>1) then
      cloud_density = 1;
    end
    
    local weather_on_pos = {
        wind = table.copy(weather_actual.wind),
        temperature = pos_temperature,
        humidity = pos_humidity,
        clouds = {
          density = cloud_density,
          color = table.copy(weather_actual.clouds.color),
          ambient = table.copy(weather_actual.clouds.ambient),
          height = weather_actual.clouds.height,
          thickness = weather_actual.clouds.thickness,
        },
        fallings = {},
        
        lightning_density = weather_actual.lightning_density*cloud_density,
        
        update_interval = weather_actual.update_interval,
        
        time_start = weather_actual.time_start,
        time_end = weather_actual.time_end,
      };
    
    for index, falling in ipairs(weather_actual.fallings) do
      local store_falling = {};
      store_falling.water_precipitation = falling.water_precipitation;
      store_falling.darken_color = table.copy(falling.darken_color);
      if (falling.water_precipitation==true) then
        store_falling.precipitation = falling.precipitation * cloud_density;
        store_falling.darken_color.a = math.floor(falling.darken_color.a * clouds_density+0.5);
      else
        store_falling.precipitation = falling.precipitation;
      end
      
      local key_now = -300; -- more then absolute zero
      local use_downfall = {};
      
      -- select rigth falling
      if      (falling.downfalls~=nil) 
          and (#falling.downfalls > 0) then
        for key, downfall in pairs(falling.downfalls) do
          if (    ((key_now<key) and (key_now<pos_temperature))
              or ((key<key_now) and (key>=pos_temperature) and (key_now>=pos_temperature))) then
            key_now = key;
            use_downfall = downfall;
          end
        end
      end
      
      store_falling.downfall = use_downfall;
      
      weather_on_pos.fallings[index] = store_falling;
    end
    
    return weather_on_pos;
  end

