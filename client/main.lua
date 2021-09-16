local socket = require("socket.core")

host = "localhost"
port = 6969

startState = savestate.object(1)
savestate.save(startState)

function connect(address, port, laddress, lport)
    local sock, err = socket.tcp()
    if not sock then return nil, err end
    if laddress then
        local res, err = sock:bind(laddress, lport, -1)
        if not res then return nil, err end
    end
    local res, err = sock:connect(address, port)
    if not res then return nil, err end
    return sock
end

local c = connect(host, port)
local try = socket.newtry(function() c:close() end)

--Memory Addresses
MemPlayerX = 0x86
MemPlayerY = 0x3B8
MemPlayerScreenX = 0x6D



local function get_gamestate()
    local state = {}
    state["score"] = memory.readbyterange(0x07DE, 6)
    state["time"] = memory.readbyterange(0x07F8, 3)

    return state
end

local function send_state(gamestate, playerstate)

    local function str_tobyte(str)
        return str:gsub(".",function(c) return string.byte(c) end)
    end

    local serialized_state = {
        str_tobyte(gamestate.score),
        str_tobyte(gamestate.time),
        playerstate.x
    }

    try(c:send(table.concat(serialized_state)))
end

local function receive_input()
    local response = try(c:receive(1))
    if response == nil then return nil end;

    response = string.byte( response ) -- converteer de string terug naar een byte (int)

    local controls = {}
    controls["left"] = AND(response, 1) > 0
    controls["right"] = AND(response, 2) > 0
    controls["up"] = AND(response, 4) > 0
    controls["down"] = AND(response, 8) > 0
    controls["A"] = AND(response, 16) > 0
    controls["B"] = AND(response, 32) > 0
    print(controls)

    return controls
end

local function get_view_data(player, tileMap)

    local pageSize = 16 --tiles
    local ViewRadiusX = 10
    local ViewRadiusY = 12

    local AIView = {}
    for x = 1, ViewRadiusX do
        AIView[x] = {}
        for y = 1, ViewRadiusY do
            AIView[x][y] = 0
        end
    end

    for viewX = 1, ViewRadiusX do
        for viewY = 1, ViewRadiusY do

            local x = player.MapX+viewX-5
		    local y = viewY-1

            local page = math.floor( x / pageSize)

            local xAddress = x - 16*page+1
            local yAddress = y + 13*(page%2)
            if xAddress >= 1 and xAddress < 32 and yAddress >= 1 and yAddress <= 25 then
                AIView[viewX][viewY] = tileMap[xAddress + 16*yAddress]
            else
                AIView[viewX][viewY] = 0
            end
        end
    end

    return AIView
end

local function get_playerstate()
    local player = {}
    player.x = memory.readbyte(MemPlayerX) + memory.readbyte(MemPlayerScreenX)*0x100 + 4
	player.y = memory.readbyte(MemPlayerY) + 16
	player.RoomX = math.floor(player.x/8)+1
	player.RoomY = math.floor(player.y/7.5)-7
	player.MapX = math.floor((player.x%512)/16)+1
	player.MapY = math.floor((player.y-32)/16)+1
    return player
end

function set_map_data()

    local TileDataTotal = 208

    local tileMap = {}
    for i = 1, 2 * TileDataTotal do
	    tileMap[i] = 0
    end

	for i = 1, 2 * TileDataTotal do
		if memory.readbyte(0x500 + i-1) ~= 0 then
			tileMap[i] = 1
		else
			tileMap[i] = 0
		end
	end

    return tileMap
end

local function draw_controls(controls)

    local function get_color(control)
        if control then return "white" else return "black" end;
    end

    gui.box(180, 40, 185, 50, get_color(controls['up']))
    gui.box(180, 57, 185, 67, get_color(controls['down']))
    gui.box(169, 51, 179, 56, get_color(controls['left']))
    gui.box(186, 51, 196, 56, get_color(controls['right']))

    gui.box(210, 55, 218, 63, get_color(controls['B']))
    gui.box(225, 55, 233, 63, get_color(controls['A']))
end

local function draw_ai_view(AIView)

    local function get_color(value)
        if value==1 then return "white" else return "black" end;
    end

    local startX = 50
    local startY = 50
    local tileSize = 4

    for x = 1, #AIView do
        for y = 1, #AIView[x] do
            local currentX = startX + x * tileSize
            local currentY = startY + y * tileSize
            gui.box(
                currentX, 
                currentY, 
                currentX + tileSize, 
                currentY + tileSize, 
                get_color(AIView[x][y])
            )
        end
    end
end


while true do

    local playerstate = get_playerstate()
    local mapdata = set_map_data()
    local view = get_view_data(playerstate, mapdata)

    local gamestate = get_gamestate()
    send_state(gamestate, playerstate)

    local controls = receive_input()
    joypad.write(1, controls)

    draw_controls(controls)
    draw_ai_view(view)

    emu:frameadvance()
end