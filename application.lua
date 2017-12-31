-- file : application.lua
local module = {}
m = nil
local pin = 7            --  GPIO13
local status = gpio.LOW
gpio.mode(pin, gpio.OUTPUT)
gpio.write(pin, status)

-- Sends a simple ping to the broker
local function send_ping()
    print("PING")
    ping = {}
    ping.device = config.ID
    ping.health = "ALIVE"
    if(status == gpio.LOW) then
        ping.state = "off"
    else
        ping.state = "on"
    end
    message = sjson.encoder(ping)
    m:publish(config.ENDPOINT .. "ping",message:read(),0,0)
end

-- Sends my id to the broker for registration
local function register_myself()
    m:subscribe(config.ENDPOINT .. config.ID,0,function(conn)
        print("Successfully subscribed to: " .. config.ENDPOINT .. config.ID)
    end)
end

local function handle_connection(con)
    register_myself()
    -- And then pings each 1000 milliseconds
    tmr.stop(6)
    tmr.alarm(6, 10000, 1, send_ping)
end

local function handle_error(client, reason)
    print("failed reason: " .. reason)
    -- tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, mqtt_start)
end

local function connect_mqtt()
    m:connect(config.HOST, config.PORT, 0, handle_connection, handle_error)
end

local function mqtt_start()
    m = mqtt.Client(config.ID, 120, config.USER, config.PASS)
    -- register message callback beforehand
    m:on("message", function(conn, topic, data) 
      if data ~= nil then
        print(topic .. ": " .. data)
        t = sjson.decode(data)
        if t["device"] == config.ID then
            if t["state"] == "on" then
                status = gpio.HIGH
            elseif t["state"] == "off" then
                status = gpio.LOW
            end
            gpio.write(pin, status)
        end
      end
    end)
    m:on("connect", function(client) print ("connected") end)
    m:on("offline", function(client) print ("offline") end)
    -- Connect to broker
    connect_mqtt()
    m:close();
end

function module.start()
  mqtt_start()
end

return module
