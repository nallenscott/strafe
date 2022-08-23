local strafe = {}

local key_prefix = "strafe"
local math_floor = math.floor
local ngx_now = ngx.now
local ngx_null = ngx.null
local tonumber = tonumber

strafe.measure = function(r_client, key)
  local current_time = math_floor(ngx_now())
  local current_second = current_time % 60
  local current_minute = math_floor(current_time / 60) % 60
  local past_minute = (current_minute + 59) % 60
  local current_key = key_prefix .. "_{" .. key .. "}_" .. current_minute
  local past_key = key_prefix .. "_{" .. key .. "}_" .. past_minute

  r_client:init_pipeline()

  r_client:get(past_key)
  r_client:incr(current_key)
  r_client:expire(current_key, 2 * 60 - current_second)

  local res, err = r_client:commit_pipeline()
  if err then
    return nil, err
  end

  local first_res = res[1]
  if first_res == ngx_null then
    first_res = "0"
  end

  local past_counter = tonumber(first_res)
  local current_counter = tonumber(res[2]) - 1

  -- https://blog.cloudflare.com/counting-things-a-lot-of-different-things
  local current_rate = past_counter * ((60 - (current_time % 60)) / 60) + current_counter
  return current_rate, nil
end

return strafe