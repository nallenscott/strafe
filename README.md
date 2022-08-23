<h1 align="center">
  <img src="strafe.jpg" width=300 alt=""><br>
  strafe<br>
</h1>

<!--ts-->
<!--te-->

# Introduction

Strafe is a simple Lua library that provides rate measurement using Nginx and Redis. It uses a simplified sliding window approach proposed by [Cloudflare](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/).

# Algorithm

The sliding window algorithm is very easy to implement. You keep two counters, one for the last minute, and one for the current minute, and then you calculate the current rate by factoring the two counters as if they were in a perfectly constant rate.

Let's debug an example of this algorithm in action. Let's say our throttling system allows 10 requests per minute (rpm), and that our past minute counter for a user is (6), and that the current minute counter is (1), and that we are at the 10th second. In the example below, the current rate is 6 which is under 10 rpm.

```bash
# Formula
past_counter * ((60 - current_second) / 60) + current_counter

# Example
6 * ((60 - 10) / 60) + 1 = 6
```

# Storage

To store the counters we use three simple [O(1)](https://en.wikipedia.org/wiki/Time_complexity#Constant_time) Redis operations:

- [GET](https://redis.io/commands/get) to retrieve the last counter
- [INCR](https://redis.io/commands/incr) to count the current counter and retrieve its current value
- [EXPIRE](https://redis.io/commands/expire) to set an expiration for the current counter

We decided not to use MULTI, therefore in theory a tiny percentage of users could be wrongly allowed. One of the reasons to dismiss MULTI is because we use a Lua driver, [`resty-redis-cluster`](https://github.com/steve0511/resty-redis-cluster), that doesn't support it, but we also use [pipelining](https://redis.io/topics/pipelining) and [hash tags](https://redis.io/docs/reference/cluster-spec/#hash-tags) to save two extra round trips.

# Scenario

Nginx already has a rate limiting feature, but it's restricted to the local node. Once you have more than one server behind a load balancer this won't work as expected, so you can use Redis as a distributed storage to keep the rating data. The Nginx config below uses the argument token as the key, and if the rate is above 10 rpm we reply with a 429.

```nginx
http {
  server {
    listen 8080;

    location /content {
      default_type 'text/plain';

      access_by_lua_block {
        local client = cluster:new(config)

        -- let's use `?token={value}` as the key to rate limit
        local rate, err = strafe.measure(client, ngx.var.arg_token)

        if err then
          ngx.log(ngx.ERR, "err: ", err)
          ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        -- when the user exceeds 10 rpm we'll reply with a 429
        if rate > 10 then
          ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
        else
          ngx.say(rate)
        end

      }
    }
  }
}
```