package.path = package.path .. ";spec/?.lua"
-- Mon Aug 22 09:50:48 -04 2022
local FIXED_NOW = 1661176248
local ngx_now = FIXED_NOW
_G.ngx = {
  now=function()
    return ngx_now
  end,
  null="NULL"
}

local strafe = require "strafe"
local perf = require "resty.perf"

local key_prefix = "strafe"
local fake_redis
local expire_resp = "OK"
local get_resp = "0"
local incr_resp = "1"

before_each(function()
    fake_redis = {}
    stub(fake_redis, "init_pipeline")
    stub(fake_redis, "get")
    stub(fake_redis, "incr")
    stub(fake_redis, "expire")
    fake_redis.commit_pipeline = function(_)
      return {get_resp, incr_resp, expire_resp}, nil
    end
    ngx_now = FIXED_NOW
    expire_resp = "OK"
    get_resp = "0"
    incr_resp = "1"
end)

describe("Strafe", function()
  it("returns the rate", function()
    -- Mon Aug 22 09:50:48 -04 2022
    get_resp = "10" -- last minute rate was 10 (1 every 6 seconds)
    incr_resp = "5" -- current rate counter is 5

    local resp, err = strafe.measure(fake_redis, "key")

    assert.is_nil(err)
    assert.same(6, resp)
  end)

  describe("When there is no past counter", function()
    it("returns rate for ongoing current counter", function()
      get_resp = ngx.null
      incr_resp = "10" -- this is your 10th hit but your rate is 9

      local resp, err = strafe.measure(fake_redis, "key")

      assert.is_nil(err)
      assert.same(9, resp)
    end)

    it("returns rate for starting current counter", function()
      get_resp = ngx.null
      incr_resp = "1" -- this is your first hit but your rate is 0

      local resp, err = strafe.measure(fake_redis, "key")

      assert.is_nil(err)
      assert.same(0, resp)
    end)
  end)

  it("returns an error when redis unavailable", function()
    fake_redis.commit_pipeline = function(_)
      return nil, "error"
    end

    local resp, err = strafe.measure(fake_redis, "key")

    assert.is_nil(resp)
    assert.is_not_nil(err)
  end)

  describe("Expiration time", function()
    it("decreases ttl based on time has passed", function()
      -- ngx.now() is Aug 22 09:50:48 -04 2022 (1661176248)
      -- current second being 48 so we just subtract 48 seconds from 2 minutes
      local _ = strafe.measure(fake_redis, "key")

      assert.stub(fake_redis.expire).was_called_with(fake_redis, key_prefix .. "_{key}_50", 2 * 60 - 48)

      -- now we're simulating a second call after 10 seconds
      ngx_now = 1661176258

      _ = strafe.measure(fake_redis, "key")

      assert.stub(fake_redis.expire).was_called_with(fake_redis, key_prefix .. "_{key}_50", 2 * 60 - 58)
    end)

    it("works for the first second", function()
      -- $ date -r 1661176800
      -- Mon Aug 22 10:00:00 -04 2022
      ngx_now = 1661176800
      local _ = strafe.measure(fake_redis, "key")

      assert.stub(fake_redis.expire).was_called_with(fake_redis, key_prefix .. "_{key}_0", 2 * 60)
    end)

    it("works for the last second", function()
      -- $ date -r 1661176859
      -- Mon Aug 22 10:00:59 -04 2022
      ngx_now = 1661176859
      local _ = strafe.measure(fake_redis, "key")

      assert.stub(fake_redis.expire).was_called_with(fake_redis, key_prefix .. "_{key}_0", 2 * 60 - 59)
    end)
  end)

  it("works when minute wraps around", function()
    -- $ date -r 1661176800
      -- Mon Aug 22 10:00:00 -04 2022
    ngx_now = 1661176800

    local _ = strafe.measure(fake_redis, "key")

    assert.stub(fake_redis.get).was_called_with(fake_redis, key_prefix .. "_{key}_59")
  end)
end)

describe("Strafe", function()
  it("runs memory and throughput profiling", function()
    -- Mon Aug 22 09:50:48 -04 2022
    get_resp = "10" -- last minute rate was 10 (1 each 6 seconds)
    incr_resp = "5" -- current rate counter is 5

    local resp, err = strafe.measure(fake_redis, "key")
    local fn_bench = function()
      resp, err = strafe.measure(fake_redis, "key")
    end

    local cpu_bench_out = function(result)
      print("\nCPU: #measures runs at " .. result .. " seconds")
    end

    local mem_bench_out = function(result)
      print("\nMEM: #measures uses " .. result .. " kb")
    end

    perf.perf_time("rate#measure", fn_bench, cpu_bench_out, {N=1e3, now=function()return os.clock()end})
    perf.perf_mem("rate#measure", fn_bench, mem_bench_out, {N=1e3})

    assert.is_nil(err)
    assert.same(6, resp)
  end)
end)