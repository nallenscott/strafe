package = "strafe"
version = "1.0.0"
source = {
  url = "github.com/revcontent-production/strafe",
  tag = "1.0.0"
}
description = {
  summary = "A Lua library for distributed rate measurement using Nginx and Redis"
}
dependencies = {
  "lua-resty-redis",
  "lua-resty-lock"
  -- it also depends on resty-redis-cluster
  -- https://github.com/revcontent-production/strafe/blob/master/Dockerfile
}
build = {
  type = "builtin",
  modules = {
    ["resty.strafe"] = "src/resty/strafe.lua"
  }
}