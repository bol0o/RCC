local random = math.random

local network_name;
local options = {'Client', 'Server'}

function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
            tbl[i], tbl[j] = tbl[j], tbl[i]
        end
    return tbl
end

function pc(ch, posx, posy, delay)
    os.sleep(delay)
    term.setCursorPos(posx, posy)
    write(ch)
end

local function intro()
    chars = {'_,15,1', '_,16,1', '_,17,1', '_,18,1', '_,19,1', '_,20,1', '_,23,1', '_,24,1', '_,25,1', '_,26,1', '_,27,1',
    '_,30,1', '_,31,1', '_,32,1', '_,33,1', '_,34,1', '|,15,2', '_,17,2', '_,18,2', '_,19,2', '\\,21,2', '/,22,2', '_,25,2',
    '_,26,2', '\\,28,2', '/,29,2', '_,32,2', '_,33,2', '\\,35,2', '|,15,3', '|,17,3', '_,18,3', '/,19,3', '/,21,3', '|,22,3',
    '/,24,3', '\\,27,3', '/,28,3', '|,29,3', '/,31,3', '\\,34,3', '/,35,3', '|,15,4', '/,20,4', '|,22,4', '|,24,4', '|,29,4',
    '|,31,4', '|,15,5', '|,17,5', '\\,18,5', '\\,20,5', '|,22,5', '\\,24,5', '_,25,5', '_,26,5', '/,27,5', '\\,28,5', '|,29,5',
    '\\,31,5', '_,32,5', '_,33,5', '/,34,5', '\\,35,5', '\\,15,6', '_,16,6', '|,17,6', '\\,19,6', '_,20,6', '|,21,6', '\\,23,6',
    '_,24,6', '_,25,6', '_,26,6', '_,27,6', '/,28,6', '\\,30,6', '_,31,6', '_,32,6', '_,33,6', '_,34,6', '/,35,6'}

    chars = shuffle(chars)
    
    for i=1, #chars do
        params = {}
        for param in string.gmatch(chars[i], '([^,]+)') do
            table.insert(params, param)
        end
    
        pc(params[1], tonumber(params[2]), tonumber(params[3]), 0.01)
    end
end

local function print_centered(str)
    width, height = term.getSize()
    ix, iy = term.getCursorPos()

    term.setCursorPos((width / 2) - (#str / 2), iy)
    print(str)
end

local function update(text)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1, 9)
	term.clearLine()
	term.setCursorPos(math.floor(51/2 - string.len(text)/2), 9)
	write(text)
end

local function bar(ratio)
	term.setBackgroundColor(colors.gray)
	term.setTextColor(colors.lime)
	term.setCursorPos(1, 11)
	term.clearLine()

	for i = 1, 51 do
		if (i/51 < ratio) then
			write("]")
		else
			write(" ")
		end
	end
end

local function error_message(msg)
    cx, cy = term.getCursorPos()
    term.setCursorPos(1, 18)
    term.setTextColor(colors.red)
    write(msg)
    term.setTextColor(colors.white)
    term.setCursorPos(cx, cy)
end

local function generate_uuid()
    local template ='xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxx'
    s, _ = string.gsub(template, 'x', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
    return s
end

local function download_file(url, file_name)
    local rawData = http.get(url)
    local data = rawData.readAll()
    local file = fs.open(file_name, "w")
    file.write(data)
    file.close()
end

local function download_server_files()
    term.clear()
    term.setCursorPos(0, 1)

    term.setTextColor(colors.blue)
    print_centered("______  _____  _____ ")
    print_centered("| ___ \\/  __ \\/  __ \\")
    print_centered("| |_/ /| /  \\/| /  \\/")
    print_centered("|    / | |    | |    ")
    print_centered("| |\\ \\ | \\__/\\| \\__/\\")
    print_centered("\\_| \\_| \\____/ \\____/")
    term.setTextColor(colors.white)

    s = "Server"
    width, height = term.getSize()
    term.setCursorPos((width / 2) - (#s / 2), 14)
    write(s)

    bar(0)

    update('Creating config file')

    file = io.open('config', 'w')
    file:write(network_name .. "\n")
    file:write(generate_uuid())
    file:close()

    bar(0.15)
    os.sleep(0.4)

    update('Downloading json.lua')
    download_file("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua", 'json')
    bar(0.3)
    os.sleep(0.4)

    update('Downloading surface.lua')
    download_file("https://pastebin.com/raw/UxweEuqf", 'surface')
    bar(0.5)
    os.sleep(0.4)

    update('Downloading server.lua')
    download_file("https://raw.githubusercontent.com/bol0o/RCC/main/server.lua", 'server')
    bar(0.65)
    os.sleep(0.4)

    update('Removing downloader.lua')
    -- fs.delete("downloader")
    bar(0.85)
    os.sleep(0.4)

    update('Restarting...')
    os.sleep(0.4)
    bar(1)
    os.reboot()
end

local function download_client_files()
    term.clear()
    term.setCursorPos(0, 1)

    term.setTextColor(colors.blue)
    print_centered("______  _____  _____ ")
    print_centered("| ___ \\/  __ \\/  __ \\")
    print_centered("| |_/ /| /  \\/| /  \\/")
    print_centered("|    / | |    | |    ")
    print_centered("| |\\ \\ | \\__/\\| \\__/\\")
    print_centered("\\_| \\_| \\____/ \\____/")
    term.setTextColor(colors.white)

    s = "Client"
    width, height = term.getSize()
    term.setCursorPos((width / 2) - (#s / 2), 14)
    write(s)

    bar(0)

    update('Creating config file')

    file = io.open('config', 'w')
    file:write(network_name .. "\n")
    file:write(generate_uuid())
    file:close()

    os.sleep(0.4)
    bar(0.15)

    update('Downloading json.lua')
    download_file("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua", 'json')
    os.sleep(0.4)
    bar(0.3)

    update('Downloading client.lua')
    download_file("https://raw.githubusercontent.com/bol0o/RCC/main/client.lua", 'client')
    os.sleep(0.4)
    bar(0.65)

    update('Removing downloader.lua')
    -- fs.delete("downloader")
    os.sleep(0.4)
    bar(0.85)

    update('Restarting...')
    os.sleep(0.4)
    bar(1)
    os.reboot()
end

local function render_main_menu()
    term.clear()
    term.setCursorPos(0, 1)
    local selected = 1

    term.setTextColor(colors.blue)
    intro()
    term.setTextColor(colors.white)
    term.setCursorPos(0, 7)
    print("\n")
    print_centered("What do you want to install?")
    print("\n")

    print_centered("Client")
    print_centered("Server")

    term.setTextColor(colors.yellow)
    while true do
        term.setCursorPos(20, 12)
        if (selected == 1) then
            write(">")
        else
            write(" ")
        end
        term.setCursorPos(20, 13)
        if (selected == 2) then
            write(">")
        else
            write(" ")
        end

        local event, key = os.pullEventRaw("key")
		if (key == keys.w or key == keys.up or key == keys.s or key == keys.down) then
            if (selected == 1) then selected = 2
            else selected = 1 end
		elseif (key == keys.space or key == keys.enter) then
            break
        end
    end

    while true do
        term.setTextColor(colors.yellow)
        term.setCursorPos(1, 15)
        term.clearLine()
        write("Enter your network name: ")
        term.setTextColor(colors.white)
        network_name = read()
        if (#network_name > 10) then 
            error_message("Name is too long ")
        elseif (#network_name < 3) then
            error_message("Name is too short")
        else
            break
        end
    end

    if (selected == 1) then
        download_client_files()
    else
        download_server_files()
    end
end

render_main_menu()

--- Add error messages