FROM openresty/openresty:xenial

RUN apt-get update \
    && apt-get install -y \
       git \
    && mkdir /src \
    && cd /src \
    && git config --global url."https://".insteadOf git:// \
    && luarocks install lua-resty-redis \
    && luarocks install lua-resty-lock \
    && git clone https://github.com/nallenscott/resty-redis-cluster.git \
    && cp resty-redis-cluster/lib/resty/rediscluster.lua /usr/local/openresty/lualib/resty/ \
    && cp resty-redis-cluster/lib/resty/xmodem.lua /usr/local/openresty/lualib/resty/ \
    && rm -rf /src