json = require "json"
local config_file = io.open("config", 'r')

local protocol = config_file:read("*line")
local server_hostname = "server"
local server;
local ping_protocol = "pingpong"

local uuid = config_file:read("*line")

local monitor;
local reactor;

local max_energy_stored_percentage = 80

local function colored_print(str, color)
    term.setTextColor(colors[color])
    print(str)
    term.setTextColor(colors.white)
end

function convert_rf_metrics(rf)
    local convertedRf
    local metrics

    rf = tonumber(rf)
    if(rf > 1000 and rf < 1000000) then
        convertedRf = string.format("%.2f", rf / 1000)
        metrics = 'KiRF'
    elseif(rf > 1000000) then
        convertedRf = string.format("%.2f", rf / 1000000)
        metrics = 'MeRf'
    else
        convertedRf = string.format("%.2f", rf)
        metrics = 'RF'
    end

    return convertedRf, metrics
end

function convert_B_metrics(milliBuckets)
    local convertedBuckets
    local metrics

    milliBuckets = tonumber(milliBuckets)
    if(milliBuckets > 1000) then
        convertedBuckets = string.format("%.2f", milliBuckets / 1000)
        metrics = 'B'
    else
        convertedBuckets = string.format("%.2f", milliBuckets)
        metrics = 'mB'
    end

    return convertedBuckets, metrics
end

local function init()
    -- Check if there is a wireless modem
    modem = peripheral.find("modem")
    if (modem == nil) then return ("Modem not found!") end
    colored_print("Modem found", 'blue')
    -- if (not modem.isWireless()) then return ("Modem is not wireless!") end

    -- Check for reactor
    reactor = peripheral.find("BigReactors-Reactor")
    if (reactor == nil) then return ("Couldn't find reactor connected to the computer!") end
    if (not reactor.getConnected()) then return ("Reactor must be fully assembled!") end

    -- Check for connected monitor
    monitor = peripheral.find("monitor")
    if (monitor == nil) then
        print("Monitor not found")
        print("Using terminal mode...")
    else
        print("Monitor found")
        x, y = monitor.getSize()
        if (x ~= 71 or y ~= 19) then
            print("Dimensions don't match")
            print("Using terminal mode...")
            monitor = nil
        else
            if (not monitor.isColor()) then
                print("Monitor doesn't support colors")
                monitor = nil
            end
            print("Using monitor mode...")
        end
    end

    -- Open the modem
    peripheral.find("modem", rednet.open)
    colored_print("Modem ready", 'green')
    
    -- Look for server
    server = rednet.lookup(protocol, server_hostname)
    if (server ~= nil) then
        -- Server found, but we still need to check if its active
        rednet.send(server, json.encode({message_type = "ping", uuid = uuid}), ping_protocol)
        id, msg = rednet.receive(ping_protocol, 1)
        
        -- The server is responding
        if (id ~= nil) then
            colored_print("Server found, id: " .. server, 'green')
            return true
        end
    end

    -- The server didn't respond
    server = nil
    colored_print("Server not found", 'red')

    return true
end

--- Reactor data and control ---
local is_active;
local control_rods;
local casing_temperature;
local fuel_temperature;
local fuel;
local fuel_amount_max;
local generated_rfs;
local fuel_consumption;
local energy_stored;
local energy_capacity;
local waste_amount;
local fuel_reactivity_percentage;

local energy_stored_percentage;
local fuel_percentage;
local rod_insertion;

function update_data()
    is_active = reactor.getActive()
    control_rods = reactor.getNumberOfControlRods()
    casing_temperature = reactor.getCasingTemperature()
    fuel_temperature = reactor.getFuelTemperature()
    fuel = reactor.getFuelAmount()
    fuel_amount_max = reactor.getFuelAmountMax()
    generated_rfs = reactor.getEnergyProducedLastTick()
    fuel_consumption = reactor.getFuelConsumedLastTick()
    energy_stored = reactor.getEnergyStored()
    energy_capacity = reactor.getEnergyCapacity()
    waste_amount = reactor.getWasteAmount()
    fuel_reactivity_percentage = reactor.getFuelReactivity()

    energy_stored_percentage = energy_stored / energy_capacity
    fuel_percentage = fuel / fuel_amount_max
    rod_insertion = get_rods_insertion()
end

function get_rods_insertion()
    local rods = reactor.getControlRodsLevels()
    local total = 0

    if reactor.getNumberOfControlRods() == 1 then return reactor.getControlRodLevel(0) end

    for i=0,#rods do
        total = total + rods[i]
    end

    return total / rods
end

---------

--- Rednet connection logic ---

--- Ping server every n seconds
local function rednet_ping()
    while true do
        if (server ~= nil) then
            rednet.send(server, json.encode({message_type = "ping", uuid = uuid}), ping_protocol)
            id, msg = rednet.receive(ping_protocol, 1)
            
            if (msg == nil) then
                -- Didn't receive a ping
                server = nil
                -- print("Disconnected from server")
            end
        end
        os.sleep(1)
    end
end

--- When server == nil - searches for new one
local function search_for_server()
    while true do
        if (server == nil) then
            -- print("Searching for server")
            s = rednet.lookup(protocol, server_hostname)

            if (s ~= nil) then
                -- Ping server to check if it is operating
                rednet.send(s, json.encode({message_type = "ping", uuid = uuid}), ping_protocol)

                id, msg = rednet.receive(ping_protocol, 1)

                if (msg == "pong") then
                    -- print("Connected to server")
                    server = s
                end
            end
        end
        os.sleep(1)
    end
end

---------

--- UI logic ---
local function print_centered(str)
    width, height = term.getSize()
    ix, iy = term.getCursorPos()

    term.setCursorPos((width / 2) - (#str / 2), iy)
    print(str)
end

local function monitor_print_centered(str)
    width, height = monitor.getSize()
    ix, iy = monitor.getCursorPos()

    monitor.setCursorPos((width / 2) - (#str / 2), iy)
    monitor.write(str)

    monitor.setCursorPos(1, iy + 1)
end

function terminal_update()
    term.clear()
    term.setCursorPos(1, 1)

    term.setTextColor(colors.blue)
    print_centered("______  _____  _____ ")
    print_centered("| ___ \\/  __ \\/  __ \\")
    print_centered("| |_/ /| /  \\/| /  \\/")
    print_centered("|    / | |    | |    ")
    print_centered("| |\\ \\ | \\__/\\| \\__/\\")
    print_centered("\\_| \\_| \\____/ \\____/")
    term.setTextColor(colors.white)

    print()

    write("Current reactor state: ")
    if (is_active == true) then
        term.setTextColor(colors.green) 
        print("On")
    else 
        term.setTextColor(colors.red) 
        print("Off")
    end
    term.setTextColor(colors.white)

    local generated_rfs, metrics = convert_rf_metrics(generated_rfs)
    write("RF generated: ")
    print("         " .. generated_rfs .. " " .. metrics)

    write("Energy stored (%): ")
    if (energy_stored_percentage <= max_energy_stored_percentage / 100) then term.setTextColor(colors.green) else term.setTextColor(colors.red) end
    print(string.format("    %.2f%%", energy_stored_percentage * 100))
    term.setTextColor(colors.white)

    local waste_amount, metrics = convert_B_metrics(waste_amount)
    write("Waste amount: ")
    print("         " .. waste_amount .. " " .. metrics)

    local fuel_consumption, metrics = convert_B_metrics(fuel_consumption)
    write("Fuel consumed: ")
    print("        " .. fuel_consumption .. " " .. metrics)

    write("Fuel left (%): ")
    if (fuel_percentage >= 0.50) then
        term.setTextColor(colors.green) 
    elseif (fuel_percentage < 0.50 and fuel_percentage > 0.10) then
        term.setTextColor(colors.orange)
    else
        term.setTextColor(colors.red)
    end
    print(string.format("        %.2f%%", fuel_percentage * 100))
    term.setTextColor(colors.white)

    -- Round this
    write("Fuel temperature: ")
    print("     " .. fuel_temperature .. " C")

    write("Fuel reactivity (%): ")
    print("  " .. fuel_reactivity_percentage .. "%")

    write("Average rod insertion: ")
    print(rod_insertion)

    write("Network protocol: ")
    print("     " .. protocol)

    write("Connected to server: ")
    local connected_to_server;
    if (server ~= nil) then 
        term.setTextColor(colors.green)
        connected_to_server = "Yes"
    else 
        term.setTextColor(colors.red) 
        connected_to_server = "No"
        end
    print("  " .. connected_to_server)
    term.setTextColor(colors.white)  
end

function screen_update()
    term.clear()

    term.setTextColor(colors.blue)
    term.setCursorPos(15, 6)
    write("______  _____  _____ ")
    term.setCursorPos(15, 7)
    write("| ___ \\/  __ \\/  __ \\")
    term.setCursorPos(15, 8)
    write("| |_/ /| /  \\/| /  \\/")
    term.setCursorPos(15, 9)
    write("|    / | |    | |    ")
    term.setCursorPos(15, 10)
    write("| |\\ \\ | \\__/\\| \\__/\\")
    term.setCursorPos(15, 11)
    write("\\_| \\_| \\____/ \\____/")
    term.setTextColor(colors.white)

    monitor.clear()
    monitor.setCursorPos(1, 1)

    monitor.setTextColor(colors.blue)
    monitor_print_centered("______  _____  _____ ")
    monitor_print_centered("| ___ \\/  __ \\/  __ \\")
    monitor_print_centered("| |_/ /| /  \\/| /  \\/")
    monitor_print_centered("|    / | |    | |    ")
    monitor_print_centered("| |\\ \\ | \\__/\\| \\__/\\")
    monitor_print_centered("\\_| \\_| \\____/ \\____/")
    monitor.setTextColor(colors.white)

    monitor.setCursorPos(2, 8)
    monitor.write("Current reactor state: ")
    monitor.setCursorPos(25, 8)
    if (is_active == true) then
        monitor.setTextColor(colors.green) 
        monitor.write("On")
    else 
        monitor.setTextColor(colors.red) 
        monitor.write("Off")
    end
    monitor.setTextColor(colors.white)

    monitor.setCursorPos(2, 10)
    monitor.write("RF generated: ")
    monitor.setCursorPos(25, 10)
    local generated_rfs, metrics = convert_rf_metrics(generated_rfs)
    monitor.write(generated_rfs .. " " .. metrics)
    
    monitor.setCursorPos(2, 12)
    monitor.write("Energy stored (%): ")
    if (energy_stored_percentage<= max_energy_stored_percentage / 100) then monitor.setTextColor(colors.green) else monitor.setTextColor(colors.red) end
    monitor.setCursorPos(25, 12)
    monitor.write(string.format("%.2f%%", energy_stored_percentage * 100))
    monitor.setTextColor(colors.white)
    
    monitor.setCursorPos(2, 14)
    monitor.write("Waste amount: ")
    monitor.setCursorPos(25, 14)
    local waste_amount, metrics = convert_B_metrics(waste_amount)
    monitor.write(waste_amount .. " " .. metrics)

    monitor.setCursorPos(2, 16)
    monitor.write("Fuel consumed: ")
    monitor.setCursorPos(25, 16)
    local fuel_consumption, metrics = convert_B_metrics(fuel_consumption)
    monitor.write(fuel_consumption .. " " .. metrics)

    monitor.setCursorPos(41, 8)
    monitor.write("Fuel left (%): ")
    if (fuel_percentage >= 0.50) then
        monitor.setTextColor(colors.green) 
    elseif (fuel_percentage < 0.50 and fuel_percentage > 0.10) then
        monitor.setTextColor(colors.orange)
    else
        monitor.setTextColor(colors.red)
    end
    monitor.setCursorPos(62, 8)
    monitor.write(string.format("%.2f%%", fuel_percentage * 100))
    monitor.setTextColor(colors.white)

    monitor.setCursorPos(41, 10)
    monitor.write("Fuel temperature: ")
    monitor.setCursorPos(62, 10)
    monitor.write(fuel_temperature .. " C")

    monitor.setCursorPos(41, 12)
    monitor.write("Fuel reactivity (%): ")
    monitor.setCursorPos(62, 12)
    monitor.write(fuel_reactivity_percentage .. "%")

    monitor.setCursorPos(41, 14)
    monitor.write("rod insertion: ")
    monitor.setCursorPos(62, 14)
    monitor.write(rod_insertion)

    monitor.setCursorPos(41, 16)
    monitor.write("Connected to server: ")
    monitor.setCursorPos(62, 16)
    if (server ~= nil) then 
        monitor.setTextColor(colors.green) 
        monitor.write("Yes")
    else 
        monitor.setTextColor(colors.red) 
        monitor.write("No")
    end
    monitor.setTextColor(colors.white)

end

---------

--- Updates reactor data, shows it, then sends rednet update
local function update()
    while true do
        update_data()
        if (monitor ~= nil) then
            screen_update()
        else
            terminal_update()
        end

        if (server ~= nil) then
            rednet.send(server, json.encode({
                uuid=uuid,
                is_active=is_active,
                control_rods=control_rods,
                rod_insertion=rod_insertion,
                casing_temperature=casing_temperature,
                fuel_temperature=fuel_temperature,
                fuel_percentage=fuel_percentage * 100,
                generated_rfs=generated_rfs,
                fuel_consumption=fuel_consumption,
                energy_stored=energy_stored,
                energy_capacity=energy_capacity,
                energy_stored_percentage=energy_stored_percentage * 100,
                waste_amount=waste_amount,
                max_energy_stored_percentage=max_energy_stored_percentage,
                fuel_reactivity_percentage=fuel_reactivity_percentage
            }), protocol)
        end

        os.sleep(1)
    end
end

local function receive_commands()
    while true do 
        id, msg = rednet.receive(protocol)
        local json_msg = json.decode(msg)

        if (json_msg["command"] == "change_state") then
            reactor.setActive(not reactor.getActive())
            
        elseif (json_msg["command"] == "eject_waste") then
            reactor.doEjectWaste()
        end
    end
end

term.clear()

i = init()
if (i ~= true) then
    print(i)
else
    os.sleep(3)
    parallel.waitForAny(rednet_ping, search_for_server, receive_commands, update)
end
-- Test if multiple networks work
-- mount /ext/ /Users/pawel/Documents/Programowanie/JavaScript/RCC