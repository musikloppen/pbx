# Use the official OpenResty image based on Debian Bookworm
FROM openresty/openresty:bookworm

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
	luarocks \
	git \
	build-essential \
	libssl-dev \
	&& rm -rf /var/lib/apt/lists/*

# Install lua dependencies
RUN luarocks install lua-resty-http
RUN luarocks install luafilesystem

# Copy nginx configuration and lua library scripts (Paths relative to ./openresty)
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua/access_control.lua /usr/local/openresty/lualib/access_control.lua
COPY lua/rate_limit.lua /usr/local/openresty/lualib/rate_limit.lua
COPY lua/dnsbl_check.lua /usr/local/openresty/lualib/dnsbl_check.lua

# Create html directory and whitelist directory
RUN mkdir -p /usr/local/openresty/html /usr/local/openresty/lualib/dnsbl_whitelist

# Copy custom status pages (If htdocs is inside openresty/)
COPY www/backend_down.html /usr/local/openresty/html/backend_down.html
COPY www/blocked_ip.html /usr/local/openresty/html/blocked_ip.html

# Set Lua search path
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;;"
ENV PATH="/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin:$PATH"

EXPOSE 80

CMD ["openresty", "-g", "daemon off;"]
