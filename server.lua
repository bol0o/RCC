json = require "json"
local surface = dofile("surface")
local config_file = io.open("config", 'r')

------- Rednet -------
local monitor = false
local protocol = config_file:read("*line")
local hostname = "server"

local ping_protocol = "pingpong"

local clients = {}
local ping_times = {}

------- Websockets -------
local websocket_url = "ws://localhost:8080"
ws, err = http.websocket(websocket_url)

------- Other -------
local monitor;

------

local function colored_print(str, color)
    term.setTextColor(colors[color])
    print(str)
    term.setTextColor(colors.white)
end

local function dict_to_arr(t)
    local t_copy = {}
    for _, val in pairs(t) do
        table.insert(t_copy, val)
    end

    return t_copy
end

function convert_rf_metrics(rf)
    if (tonumber(rf) == nil) then
        return "-", ""
    end

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
    if (tonumber(milliBuckets) == nil) then
        return "-", ""
    end

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
    ------- Rednet -------
    -- Check if there is a wireless modem
    modem = peripheral.find("modem")
    if (modem == nil) then return ("Modem not found!") end
    colored_print("Modem found", 'blue')
    -- if (not modem.isWireless()) then return ("Modem is not wireless!") end

    -- Open the modem
    peripheral.find("modem", rednet.open)
    colored_print("Modem ready", 'green')
    
    -- Host protocol server
    rednet.host(protocol, hostname)
    colored_print(string.format("Hosting server on protocol '%s' with hostname '%s'", protocol, hostname), 'blue')

    ------- Websockets -------
    if ws then
        ws.send(json.encode{
            message_type = 'connection',
            client_type = 'MC',
            reactor_ids = clients,
        })

        print("Connected to websocket server")
    elseif err then
        print("Couldn't connect to websocket server (" .. err .. ")")
    end

    ------- Other -------
    -- Check for connected monitor
    monitor = peripheral.find("monitor")
    if (monitor == nil) then
        print("Monitor not found")
        print("Using terminal mode...")
    else
        print("Monitor found")
        x, y = monitor.getSize()
        if (x ~= 61 or y ~= 19) then
            print("Dimensions don't match")
            print("Using terminal mode...")
            monitor = nil
        else
            if (not monitor.isColor()) then
                print("Monitor doesn't support colors")
                monitor = nil
            else
                print("Using monitor mode...")
            end
        end
    end

    return true
end

--- UI logic ---
local selected_index = 1
local updated_data;

--- Terminal
local function print_centered(str)
    width, height = term.getSize()
    ix, iy = term.getCursorPos()

    term.setCursorPos((width / 2) - (#str / 2), iy)
    print(str)
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

    write("Connected to WSS: ")
    if (ws ~= false) then 
        wss_conn = "Yes"
        term.setTextColor(colors.green)
    else 
        wss_conn = "No" 
        term.setTextColor(colors.red)
    end
    write(wss_conn)
    term.setTextColor(colors.white)

    write("                    ")

    local clients_copy = dict_to_arr(clients)
    print(string.format("%s / %s", selected_index, #clients_copy))

    print()

    write("Reactor UUID: ")
    print(updated_data['uuid'])

    write("Current reactor state: ")
    if (updated_data['is_active'] == true) then
        term.setTextColor(colors.green) 
        print("On")
    else
        if (updated_data['is_active'] == "-") then
            print("-")
        else
            term.setTextColor(colors.red) 
            print("Off")
        end
    end
    term.setTextColor(colors.white)

    local generated_rfs, metrics = convert_rf_metrics(updated_data['generated_rfs'])
    write("RF generated: ")
    print("         " .. generated_rfs .. " " .. metrics)

    write("Energy stored (%): ")
    if (updated_data['energy_stored_percentage'] ~= "-") then
        if (updated_data['energy_stored_percentage'] <= updated_data['max_energy_stored_percentage']) then term.setTextColor(colors.green) else term.setTextColor(colors.red) end
        print(string.format("    %.2f%%", updated_data['energy_stored_percentage']))
    else
        print("    " .. updated_data['energy_stored_percentage']) end
    term.setTextColor(colors.white)

    write("Fuel left (%): ")
    if (updated_data['fuel_percentage'] ~= "-") then
        if (updated_data['fuel_percentage']>= 50) then
            term.setTextColor(colors.green) 
        elseif (updated_data['fuel_percentage'] < 50 and updated_data['fuel_percentage'] > 10) then
            term.setTextColor(colors.orange)
        else
            term.setTextColor(colors.red)
        end
        print(string.format("        %.2f%%", updated_data['fuel_percentage']))
    else
        print("        " .. updated_data['fuel_percentage'])
    end
    term.setTextColor(colors.white)

    local fuel_consumption, metrics = convert_B_metrics(updated_data['fuel_consumption'])
    write("Fuel consumed: ")
    print("        " .. fuel_consumption .. " " .. metrics)

    write("Fuel reactivity (%): ")
    if (updated_data['fuel_reactivity_percentage'] ~= "-") then
        print("  " .. updated_data['fuel_reactivity_percentage'] .. "%")
    else
        print("  -")
    end

    local waste_amount, metrics = convert_B_metrics(updated_data['waste_amount'])
    write("Waste amount: ")
    print("         " .. updated_data['waste_amount'] .. " " .. metrics)

end

--- Monitor
local coords = {
    previous = {
        x = 50,
        y = 2,
        w = 3,
        h = 5
    },
    next = {
        x = 56,
        y = 2,
        w = 3,
        h = 5
    },
    change_state = {
        x = 49,
        y = 9,
        w = 11,
        h = 4
    },
    eject_waste = {
        x = 49,
        y = 14,
        w = 11,
        h = 4
    }
}

local function monitor_update()
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

    width, height = monitor.getSize()
    local surf = surface.create(width, height, colors.black)

    --- Outline
    surf:drawRect(0, 0, width, height, colors.white)
    surf:drawRect(1, 4, 48, 1, colors.white)
    surf:drawRect(48, 1, 1, 17, colors.white)
    surf:drawRect(48, 8, 12, 1, colors.white)
    surf:drawRect(48, 13, 12, 1, colors.white)

    --- Controls
    surf:drawTriangle(52, 2, 52, 6, 50, 4, colors.white)
    surf:drawTriangle(56, 2, 56, 6, 58, 4, colors.white)
    surf:drawPixel(51, 4, colors.white)
    surf:drawPixel(57, 4, colors.white)

    local eject_text1;
    local eject_text2;
    local eject_color;
    local eject_text1_x;
    if (updated_data['is_active'] == "-") then
        eject_text1 = "-"
        eject_text1_x = 53
        eject_text2 = ""
        eject_color = colors.gray
    else
        eject_text1 = "Eject"
        eject_text1_x = 52
        eject_text2 = "Waste"
        eject_color = colors.blue
    end
    surf:fillRect(49, 14, 11, 4, eject_color)
    surf:drawString(eject_text1, eject_text1_x, 15, eject_color, colors.white)
    surf:drawString(eject_text2, 52, 16, eject_color, colors.white)

    local state_text;
    local state_color;
    if (updated_data['is_active'] == true) then
        state_text = "On"
        state_color = colors.green
    else
        if (updated_data['is_active'] == "-") then
            state_text = "-"
            state_color = colors.gray
        else
            state_text = "Off"
            state_color = colors.red
        end
    end
    surf:fillRect(49, 9, 11, 4, state_color)
    surf:drawString(state_text, 53, 10, state_color, colors.white)

    --- Info
    local wss_conn_text;
    local wss_conn_color;
    if (ws ~= false) then 
        wss_conn_text = "Yes"
        wss_conn_color = colors.green
    else 
        wss_conn_text = "No"
        wss_conn_color = colors.red
    end
    surf:drawString("Connected to WSS: ", 2, 2, colors.black, colors.white)
    surf:drawString(wss_conn_text, 20, 2, colors.black, wss_conn_color)

    local clients_copy = dict_to_arr(clients)
    surf:drawString(string.format("%s / %s", selected_index, #clients_copy), 39, 2, colors.black, colors.white)

    surf:drawString("UUID: " .. updated_data['uuid'], 2, 6, colors.black, colors.white)

    surf:drawString("RF generated: ", 2, 7, colors.black, colors.white)
    local generated_rfs, metrics = convert_rf_metrics(updated_data['generated_rfs'])
    surf:drawString(generated_rfs .. " " .. metrics, 23, 7, colors.black, colors.white)

    local stored_text;
    local stored_color;
    if (updated_data['energy_stored_percentage'] ~= "-") then
        if (updated_data['energy_stored_percentage'] <= updated_data['max_energy_stored_percentage']) then 
            stored_color = colors.green 
        else 
            stored_color = colors.red
            end
        stored_text = string.format("%.2f%%", updated_data['energy_stored_percentage'])
    else
        stored_text = tostring(updated_data['energy_stored_percentage']) 
    end
    surf:drawString("Energy stored (%): ", 2, 8, colors.black, colors.white)
    surf:drawString(stored_text, 23, 8, colors.black, stored_color)

    local fuel_color;
    local fuel_text
    if (updated_data['fuel_percentage'] ~= "-") then
        if (updated_data['fuel_percentage']>= 50) then
            fuel_color = colors.green
        elseif (updated_data['fuel_percentage'] < 50 and updated_data['fuel_percentage'] > 10) then
            fuel_color = colors.orange
        else
            fuel_color = colors.red
        end
        fuel_text = string.format("%.2f%%", updated_data['fuel_percentage'])
    else
        fuel_text = tostring(updated_data['fuel_percentage'])
    end
    surf:drawString("Fuel left (%): ", 2, 9, colors.black, colors.white)
    surf:drawString(fuel_text, 23, 9, colors.black, fuel_color)

    surf:drawString("Fuel consumed: ", 2, 10, colors.black, colors.white)
    local fuel_consumption, metrics = convert_B_metrics(updated_data['fuel_consumption'])
    surf:drawString(fuel_consumption .. " " .. metrics, 23, 10, colors.black, colors.white)

    surf:drawString("Fuel reactivity: ", 2, 11, colors.black, colors.white)
    if (updated_data['fuel_reactivity_percentage'] == "-") then
        surf:drawString("-", 23, 11, colors.black, colors.white)
    else
        surf:drawString(tostring(updated_data['fuel_reactivity_percentage']) .. "%", 23, 11, colors.black, colors.white)
    end

    surf:drawString("Fuel temperature: ", 2, 12, colors.black, colors.white)
    if (updated_data['fuel_temperature'] == "-") then
        surf:drawString("-", 23, 12, colors.black, colors.white)
    else
        surf:drawString(tostring(updated_data['fuel_temperature']) .. "C", 23, 12, colors.black, colors.white)
    end

    surf:drawString("Waste amount: ", 2, 13, colors.black, colors.white)
    local waste_amount, metrics = convert_B_metrics(updated_data['waste_amount'])
    surf:drawString(waste_amount .. " " .. metrics, 23, 13, colors.black, colors.white)

    surf:drawString("Casing temperature: ", 2, 14, colors.black, colors.white)
    if (updated_data['casing_temperature'] == "-") then
        surf:drawString("-", 23, 14, colors.black, colors.white)
    else
        surf:drawString(tostring(updated_data['casing_temperature']) .. " C", 23, 14, colors.black, colors.white)
    end

    surf:drawString("Control rods: ", 2, 15, colors.black, colors.white)
    surf:drawString(tostring(updated_data['control_rods']), 23, 15, colors.black, colors.white)

    surf:drawString("Rod insertion: ", 2, 16, colors.black, colors.white)
    surf:drawString(tostring(updated_data['rod_insertion']), 23, 16, colors.black, colors.white)


    surf:output(monitor)
end

--- Listeners and other
function update()
    if (monitor ~= nil) then
        monitor_update()
    else
        terminal_update()
    end 
end

local function reset_data()
    updated_data = {
        uuid="-",
        is_active="-",
        control_rods="-",
        rod_insertion="-",
        fuel_percentage="-",
        fuel_consumption="-",
        generated_rfs="-",
        energy_stored_percentage="-",
        max_energy_stored_percentage="-",
        fuel_reactivity_percentage="-",
        fuel_temperature="-",
        waste_amount="-",
        casing_temperature="-"
    }
    
    update()
end
reset_data()

local function previous_client()
    local clients_copy = dict_to_arr(clients)
    if (selected_index - 1 < 1) then
        selected_index = #clients_copy
    else selected_index = selected_index - 1 end
    reset_data()
end

local function next_client()
    local clients_copy = dict_to_arr(clients)
    if (selected_index + 1 > #clients_copy) then
        selected_index = 1
    else selected_index = selected_index + 1 end
    reset_data()
end

local function send_command(command)
    for id, uuid in pairs(clients) do
        if (uuid == updated_data['uuid']) then
            rednet.send(id, json.encode({
                message_type="reactor command",
                reactor_uuid=uuid,
                command=command
            }), protocol)
        end
    end
end

local function touch_event(event_name)
    if (event_name == "previous") then
        local clients_copy = dict_to_arr(clients)
        if (#clients_copy > 1) then 
            previous_client()
        end
    elseif (event_name == "next") then
        local clients_copy = dict_to_arr(clients)
        if (#clients_copy > 1) then 
            next_client()
        end
    elseif (event_name == "change_state") then
        send_command("change_state")
    elseif (event_name == "eject_waste") then
        send_command("eject_waste")
    end
end

function keypress_listen()
    while true do
        local event, key = os.pullEventRaw("key")

        local clients_copy = dict_to_arr(clients)
        if (#clients_copy > 1) then 
            if (key == keys.a or key == keys.left) then
                previous_client()
            elseif (key == keys.d or key == keys.right) then
                next_client()
            end
        end
    end
end

function touch_listen()
    while true do
        local _, __, x, y = os.pullEvent("monitor_touch")
        for button, values in pairs(coords) do
            if(x > values['x'] and x <= values['x'] + values['w'] and y > values['y'] and y <= values['y'] + values['h']) then
                touch_event(button)
            end
        end
    end
end

function event_listen()
    if (monitor ~= nil) then
        touch_listen()
    else
        keypress_listen()
    end 
end

---------

--- Rednet connection logic ---

--- Function called when clients object is updated
local function clients_update()
    local clients_copy = dict_to_arr(clients)
    if (#clients_copy == 0) then
        reset_data()
    else
        update()
    end

    if (ws == false) then return end
    ws.send(json.encode{
        message_type = 'connection update',
        client_type = 'MC',
        reactor_ids = clients_copy
    })
end

--- Handles incoming pings from rednet clients
local function handle_rednet_ping()
    while true do
        id, msg = rednet.receive(ping_protocol)
        msg = json.decode(msg)
        
        rednet.send(id, "pong", ping_protocol)
        ping_times[id] = os.clock()

        if not clients[id] then
            -- print("New client with uuid " .. msg["uuid"] .. " connected")
            clients[id] = msg["uuid"]
            clients_update()
        end
    end
end

--- Checks time stored in 'ping_times' - disconnect client when there was no ping
local function check_rednet_disconnected()
    local check_every = 1

    while true do
        for key, val in pairs(ping_times) do
            if (os.clock() - val > check_every * 2) then
                ping_times[key] = nil
                clients[key] = nil
                clients_update()
            end
        end
        os.sleep(check_every)
    end
end
---------

--- Websocket connection logic ---

--- Function called when websocket variable is updated
local function websocket_update()
    update()
end

--- Listen to 'websocket_closed' event to change ws variable
local function websocket_closed()
    while true do
        os.pullEvent("websocket_closed")
        if (ws ~= false) then
            ws = false
            -- print("Websocket connection closed")
            websocket_update()
        end
    end
end

--- When user is not connected to WSS - retry every n second(s)
local function retry_websocket()
    while true do
        if (ws == false) then
            -- print("Reconnecting to websocket")
            ws, err = http.websocket(websocket_url)
            if ws then 
                local clients_copy = dict_to_arr(clients)

                ws.send(json.encode{
                    message_type = 'connection',
                    client_type = 'MC',
                    reactor_ids = clients_copy,
                })
                websocket_update()
                -- print("Reconnected to websocket")
            else 
                -- print("Attempt failed (" .. err .. ")") 
            end
        end
        os.sleep(1)
    end
end

--- Handle 'websocket_message' event - respond to server pings
local function handle_websocket_message()
    while true do
        event, url, message = os.pullEvent("websocket_message")
        message = json.decode(message)
        --- Handle ping
        if (message['message_type'] == "ping") then
            ws.send(json.encode({message_type = "pong"}))
        else
            --- Normal message received
            ---- Forward it to the reactor
            for key, value in pairs(clients) do
                if (value == message['reactor_uuid']) then
                    rednet.send(key, json.encode(message), protocol)
                end
            end
        end
    end
end
---------

local function receive_reactor_updates()
    while true do
        id, msg = rednet.receive(protocol)

        incoming_data = json.decode(msg)
        if (incoming_data['uuid'] == dict_to_arr(clients)[selected_index]) then
            updated_data = incoming_data

            update()
        end

        if (ws ~= false) then
            if (ws ~= false) then
                incoming_data['message_type'] = "reactor update"
                ws.send(json.encode(incoming_data))
            end
        end
    end
end

term.clear()

i = init()
if (i ~= true) then
    print(i)
else
    os.sleep(3)
    update()
    parallel.waitForAny(handle_rednet_ping,
                        check_rednet_disconnected,
                        receive_reactor_updates,
                        websocket_closed,
                        retry_websocket,
                        handle_websocket_message,
                        event_listen)
end