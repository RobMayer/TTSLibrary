local const = { SPECTATOR = 1, PLAYER = 2, PROMOTED = 4, BLACK = 8, HOST = 16, ALL = 31, NOSPECTATOR = 30 }

config = {
    READONLY = false, --set to true to hide buttons (for use with the control panel)
    ACCESS = {const.PLAYER, const.HOST}, --who is allowed to play with things?
    UPPER_BOUNDS = 1.25, --how high off the origin of the miniture is the UI, in world units.
    UI_WIDTH = 1.25, --set the width of the UI in world units, minimum 1.0
    REFRESH_DELAY = 3, --number of frames to wait after rebuilding assets to rebuilding the UI. Increase this if you're finding that images aren't displaying right
    DEFAULT_STATE = { --if the HUD doesn't find anything in the save data, it will default to this
        bars = {
            {"Health", "#cc0000", 10, 10, true }, --1: Name, 2: color (must be valid hex color), 3: starting value, 4: maximum value, 5: is it an important (and thus slightly bigger) bar. defaults to false
        },
        markers = { --list of default markers. Use the format below
            --1:Name, 2: URL, 3: Color, 4:Count - how many times has this mini received this marker?
        },
    },
    PRELOADED_ASSETS = { --gets added to assets rebuild each and every time. Not well documented, sorry.

    },
    ARC = {
        MESH = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round6.obj", --which mesh?
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round6.obj is a rounded-perimiter with 6 arcs
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round4.obj rounded-peremiter with 4 arcs
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round12.obj rounded-peremiter with 12 arcs
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/hex6.obj hex-peremiter with 6 arcs
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/hex12.obj hex-peremiter with 12 arcs
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/hex0.obj hex-peremiter with no arc lines
            -- https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round0.obj round-peremiter with no arc lines
            -- if you want to use your own mesh, the system is designed to use 1-unit radius as a basis and scales the mesh up from there based on the current range value
        COLOR = "inherit", --what color will the arc indicator be. Use a hex color string such as ""#ffcc33" or the word "inherit" which means it will pull from the miniature's tint.
        SCALE = 1, --three options here - use 0 to make the mesh static/non-scalable. Use a number to have the ranges go up and down by that amount, or you can use a list-table to indicate what specific brackets you want, such as {1, 4, 7, 13}
        MAX_RANGE = 8, --if scale is non-zero number, what's the maximum range you want to be usable? ignored if SCALE is provided as a table
    }
}

local permit = function(player)
    local rights = bit32.bor(
    	(player.host and const.HOST or 0),
    	(player.color == "Black" and const.BLACK or 0),
    	((player.color ~= "Grey" and player.color ~= "Black") and const.PLAYER or 0),
    	(player.promoted and const.PROMOTED or 0),
    	(player.color == "Grey" and const.SPECTATOR or 0)
    )
    return bit32.band(bit32.bor(table.unpack(config.ACCESS)), rights) ~= 0
end

function onSave()
    local save = {}
    --add more hooks here if you need them, but leave this one here
    miniutilSave(save)
    return JSON.encode(save)
end

function onLoad(save)
    save = JSON.decode(save) or {}
    --add more hooks here if you need them, but leave this one here
    miniutilLoad(save)
end

-- DONT EDIT BELOW THIS LINE

TRH_Class = "mini" --leave this be. it's how tokens recognize this as a valid target
local state = {}
local uimode_settings = 0
local arclen = 1;
local arcobj;
local controllerObj;
local assetBuffer = {}

--Arc
function showArc()
    local arcsActive = config.ARC ~= nil and config.ARC ~= false and config.ARC.MESH ~= nil and config.ARC.MESH ~= ""
    if (arcsActive) then
        local arcsScalable = true
        if (type(config.ARC.SCALE or 1) == "table" and #(config.ARC.SCALE) == 1) then
            arcsScalable = false
        elseif (config.ARC.SCALE == 0) then
            arcsScalable = false
        end

        self.UI.hide("btn_show_arc")
        self.UI.show("btn_hide_arc")
        if (arcsScalable) then
            self.UI.show("disp_arc_len")
            self.UI.show("btn_arc_sub")
            self.UI.show("btn_arc_add")
        end
        arcobj = spawnObject({
            type = "custom_model",
            position = self.getPosition(),
            rotation = self.getRotation(),
            mass = 0,
            sound = false,
            snap_to_grid = false,
            callback_function = function(obj)
                if (type(config.ARC.SCALE or 1) == "table") then
                    obj.setScale({config.ARC.SCALE[arclen], 1, config.ARC.SCALE[arclen]})
                else
                    if (config.ARC.SCALE == 0) then
                        obj.setScale({1,1,1})
                    else
                        obj.setScale({(arclen or 1) * (config.ARC.SCALE or 1), 1, (arclen or 1) * (config.ARC.SCALE or 1)})
                    end
                end
                if (string.lower(config.ARC.COLOR or "INHERIT") == "inherit") then
                    obj.setColorTint(self.getColorTint())
                else
                    local clr = string.sub(config.ARC.COLOR, 2, 7) or "ffffff"
                    if (string.len(clr) ~= 6) then clr = "ffffff" end
                    obj.setColorTint({
                        (tonumber(string.sub(clr, 1, 2),16) or 255) / 255,
                        (tonumber(string.sub(clr, 3, 4),16) or 255) / 255,
                        (tonumber(string.sub(clr, 5, 6),16) or 255) / 255,
                    })
                end
                obj.setVar("parent", self)
                obj.setLuaScript([[
                    function onUpdate()
                        if (parent ~= nil) then
                            if (not parent.resting) then
                                self.setPosition(parent.getPosition())
                                self.setRotation(parent.getRotation())
                            end
                        else
                            self.destruct()
                        end
                    end
                ]])
                obj.getComponent("MeshRenderer").set("receiveShadows", false)
                obj.mass = 0
                obj.bounciness = 0
                obj.drag = 0
                obj.use_snap_points = false
                obj.use_grid = false
                obj.use_gravity = false
                obj.auto_raise = false
                obj.auto_raise = false
                obj.sticky = false
                obj.interactable = false
            end,
        })
        arcobj.setCustomObject({
            mesh = config.ARC.MESH,
            collider = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/utility/null_COL.obj",
            material = 3,
            specularIntensity = 0,
            cast_shadows = false,
        })
    end
end

function hideArc()
    local arcsActive = config.ARC ~= nil and config.ARC ~= false and config.ARC.MESH ~= nil and config.ARC.MESH ~= ""
    if (arcsActive) then
        local arcsScalable = true
        if (type(config.ARC.SCALE or 1) == "table" and #(config.ARC.SCALE) == 1) then
            arcsScalable = false
        elseif (config.ARC.SCALE == 0) then
            arcsScalable = false
        end
        arcobj.destruct()
        self.UI.show("btn_show_arc")
        self.UI.hide("btn_hide_arc")
        self.UI.hide("disp_arc_len")
        self.UI.hide("btn_arc_sub")
        self.UI.hide("btn_arc_add")
    end
end

function setArcValue(data)
    if (arcobj ~= nil) then
        arclen = tonumber(data.value) or arclen
        if (type(config.ARC.SCALE or 1) == "table") then
            arcobj.setScale({config.ARC.SCALE[arclen], 1, config.ARC.SCALE[arclen]})
            self.UI.setAttribute("disp_arc_len", "text", config.ARC.SCALE[arclen])
        else
            arcobj.setScale({arclen * (config.ARC.SCALE or 1), 1, arclen * (config.ARC.SCALE or 1)})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
        end
    end
end

function arcSub()
    if (arcobj ~= nil) then
        arclen = math.max(1, arclen - 1)
        if (type(config.ARC.SCALE or 1) == "table") then
            arcobj.setScale({config.ARC.SCALE[arclen], 1, config.ARC.SCALE[arclen]})
            self.UI.setAttribute("disp_arc_len", "text", config.ARC.SCALE[arclen])
        else
            arcobj.setScale({arclen * (config.ARC.SCALE or 1), 1, arclen * (config.ARC.SCALE or 1)})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
        end
    end
end

function arcAdd()
    if (arcobj ~= nil) then
        if (type(config.ARC.SCALE or 1) == "table") then
            arclen = math.min(#(config.ARC.SCALE), arclen + 1)
            arcobj.setScale({config.ARC.SCALE[arclen], 1, config.ARC.SCALE[arclen]})
            self.UI.setAttribute("disp_arc_len", "text", config.ARC.SCALE[arclen])
        else
            arclen = math.min(config.ARC.MAX_RANGE or 32, arclen + 1)
            arcobj.setScale({arclen * (config.ARC.SCALE or 1), 1, arclen * (config.ARC.SCALE or 1)})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
        end
    end
end

--Markers

function addMarker(data)
    local added = false
    local found = false
    local count = data.count or 1
    for i,each in pairs(state.markers) do
        if (each[1] == data.name) then
            found=true
            if (data.stacks or false) then
                cur = (state.markers[i][4] or 1) + count
                state.markers[i][4] = cur
                self.UI.setAttribute("counter_mk_"..i, "text", cur)
                self.UI.setAttribute("disp_mk_"..i, "text", cur > 1 and cur or "")
                if (controllerObj ~= nil) then controllerObj.call("alterMiniMarker", { guid = self.guid, index=i, count=cur }) end
                added = true
            end
            break
        end
    end
    if (found == false) then
        table.insert(state.markers, {data.name, data.url, data.color or "#ffffff", (data.stacks or false) and count or 1, data.stacks or false})
        rebuildAssets()
        Wait.frames(rebuildUI, config.REFRESH_DELAY or 3)
        if (controllerObj ~= nil) then controllerObj.call("updateMiniMarkers", {}) end
        added = true
    end
    return added
end

function getMarkers()
    res = {}
    for i,v in pairs(state.markers) do
        res[i] = {
            name = v[1],
            url = v[2],
            color = v[3],
            count = v[4] or 1,
            stacks = v[5] or false,
        }
    end
    return res
end

function popMarker(data)
    local i = tonumber(data.index)
    local cur = state.markers[i][4] or 1
    if (cur > 1) then
        cur = cur - (data.amount or 1)
        state.markers[i][4] = cur
        local display = ((cur > 1) and cur or "")
        self.UI.setAttribute("counter_mk_"..i, "text", display)
        self.UI.setAttribute("disp_mk_"..i, "text", display)
        if (controllerObj ~= nil) then controllerObj.call("alterMiniMarker", { guid = self.guid, index=i, count=cur }) end
    else
        table.remove(state.markers, i)
        if (controllerObj ~= nil) then controllerObj.call("updateMiniMarkers", {}) end
        rebuildUI()
    end
end

function removeMarker(data)
    table.remove(state.markers, data.index)
    rebuildUI()
end

function clearMarkers()
    state.markers={}
    rebuildUI()
end

--Bars
function addBar(data)
    table.insert(state.bars, {data.name or "Name", data.color or "#ffffff", data.current or 5, data.maximum or 10})
    rebuildUI()
    if (controllerObj ~= nil) then controllerObj.call("rebuildUI", {}) end
end

function getBars()
    res = {}
    for i,v in pairs(state.bars) do
        local isBig = false
        if (v[5] ~= nil) then
            isBig = v[5]
        end
        res[i] = {
            name = v[1],
            color = v[2],
            current = v[3],
            maximum = v[4],
            big = isBig,
        }
    end
    return res
end

function setBar(data)
    local index = tonumber(data.index)
    local bar = state.bars[index]
    local max = tonumber(data.maximum) or bar[4]
    local cur = math.min(max, tonumber(data.current) or bar[3])
    local name = data.name or bar[1]
    local color = data.color or bar[2]
    local isBig = false
    if (bar[5] ~= nil) then
        isBig = bar[5]
    end
    if (data.big ~= nil) then
        isBig = data.big
    end

    local per = (max == 0) and 0 or cur / max * 100


    self.UI.setAttribute("inp_bar_"..index.."_name", "value", name)
    self.UI.setAttribute("inp_bar_"..index.."_color", "value", color)
    self.UI.setAttribute("inp_bar_"..index.."_current", "value", cur)
    self.UI.setAttribute("inp_bar_"..index.."_max", "value", max)
    self.UI.setAttribute("inp_bar_"..index.."_big", "isOn", isBig)

    self.UI.setAttribute("bar_"..index, "percentage", per)
    self.UI.setAttribute("bar_"..index, "fillImageColor", color)
    self.UI.setAttribute("bar_"..index, "height", isBig and 20 or 16)

    state.bars[index][1] = name
    state.bars[index][2] = color
    state.bars[index][3] = cur
    state.bars[index][4] = max
    state.bars[index][5] = isBig

    if (controllerObj ~= nil) then controllerObj.call("updateMiniBars", { guid = self.guid }) end

end

function adjustBar(data)
    local index = tonumber(data.index)
    local val = data.amount or 0
    local bar = state.bars[index]
    local max = tonumber(bar[4]) or 0
    local cur = math.max(0, math.min(max, (tonumber(bar[3]) or 0) + val))
    local per = (max == 0) and 0 or cur / max * 100
    self.UI.setAttribute("bar_"..index, "percentage", per)
    self.UI.setAttribute("inp_bar_"..index.."_current", "text", cur)
    state.bars[index][3] = cur
    if (controllerObj ~= nil) then controllerObj.call("updateMiniBars", { guid = self.guid }) end
end

function removeBar(data)
    table.remove(state.bars, tonumber(data.index))
    rebuildUI()
    if (controllerObj ~= nil) then controllerObj.call("rebuildUI", {}) end
end

function clearBars()
    state.bars={}
    rebuildUI()
    if (controllerObj ~= nil) then controllerObj.call("rebuildUI", {}) end
end

--Utility
function setController(data)
    if (data.object == nil) then error("object required") end
    if (controllerObj ~= nil) then
        controllerObj.call("untrack", {guid=self.guid})
    end
    controllerObj = data.object
end

function unsetController()
    controllerObj = nil
end

--bars
function ui_addBar(player)
    if (permit(player)) then
        addBar({name="Name", color="#ffffff", current=5, maximum=10})
    end
end
function ui_removeBar(player, index)
    if (permit(player)) then
        removeBar({index=index})
    end
end
function ui_setBar(player, val, id)
    if (permit(player)) then
        local args = {}
        for a in string.gmatch(id, "([^%_]+)") do
            table.insert(args,a)
        end
        local index = tonumber(args[3])
        local key = args[4]
        if (key == "name") then
            setBar({index=index, name=val})
        elseif (key == "color") then
            setBar({index=index, color=val})
        elseif (key == "current") then
            setBar({index=index, current=val})
        elseif (key == "max") then
            setBar({index=index, maximum=val})
        elseif (key == "big") then
            setBar({index=index, big=(val == "True")})
        end
    end
end
function ui_adjBar(player, params)
    if (permit(player)) then
        local args = {}
        for a in string.gmatch(params, "([^%|]+)") do
            table.insert(args,a)
        end
        local index = tonumber(args[1]) or 1
        local amount = tonumber(args[2]) or 1
        adjustBar({index=index, amount=amount})
    end
end
function ui_clearBars(player)
    if (permit(player)) then
        clearBars()
    end
end

--Markers
function ui_popMarker(player, index)
    if (permit(player)) then
        popMarker({index=index})
    end
end

--Arcs
function ui_showarc(player) if (permit(player)) then showArc() end end
function ui_hidearc(player) if (permit(player)) then hideArc() end end
function ui_arcadd(player) if (permit(player)) then arcAdd() end end
function ui_arcsub(player) if (permit(player)) then arcSub() end end

--ui util functions
function uimode(player, mode)
    if (permit(player)) then
        mode = tonumber(mode) or 0
        uimode_settings = mode
        if (mode == 0) then
            rebuildAssets()
        end
        rebuildUI()
    end
end



function rebuildAssets()
    local assets = {
        {name="ui_gear", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/gear.png"},
        {name="ui_close", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/close.png"},
        {name="ui_plus", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/plus.png"},
        {name="ui_minus", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/minus.png"},
        {name="ui_hide", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/hide.png"},
        {name="ui_bars", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/bars.png"},
        {name="ui_stack", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/stack.png"},
        {name="ui_effects", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/effects.png"},
        {name="ui_reload", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/reload.png"},
        {name="ui_arcs", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/arcs.png"},
    }
    for theName,theUrl in pairs(config.PRELOADED_ASSETS) do
        table.insert(assets, {name=theName, url=theUrl})
    end
    local bufLen = 0
    assetBuffer = {}
    for i,marker in pairs(state.markers) do
        if (assetBuffer[marker[2]] == nil) then
            bufLen = bufLen + 1
            assetBuffer[marker[2]] = self.guid.."mk_"..bufLen
            table.insert(assets, {name=self.guid.."mk_"..bufLen, url=marker[2]})
        end
    end
    self.UI.setCustomAssets(assets)
end

function rebuildUI()

    local arcsActive = config.ARC ~= nil and config.ARC ~= false
    local arcsOn = arcobj ~= nil
    local arcsScalable = false
    if (arcsActive) then
        arcsScalable = true
        if (type(config.ARC.SCALE or 1) == "table" and #(config.ARC.SCALE) == 1) then
            arcsScalable = false
        elseif (config.ARC.SCALE == 0) then
            arcsScalable = false
        end
    end

    local w = math.max(200, (tonumber(config.UI_WIDTH) or 2) * 200)
    local ui_bars = {
        tag="panel",
        attributes={id="ui_bars", offsetXY="0 30", rectAlignment="LowerCenter"},
        children={}
    }
    local ui_markers = {
        tag="panel",
        attributes={id="ui_markers", offsetXY="0 "..(50 + (#(state.bars) * 20)), rectAlignment="LowerCenter"},
        children={}
    }
    local ui_overhead = {
        tag="panel",
        attributes={
            id="ui_overhead",
            height="0",
            width=w,
            position="0 0 -"..(tonumber(config.UPPER_BOUNDS) or 1.5) * 100,
            rotation="-90 0 0",
            active=(uimode_settings == 0),
            scale="0.5 0.5 0.5",
        },
        children={
            {tag="button", attributes={id="btn_show_arc", active=(arcsActive and not arcsOn), height="30", width="30", rectAlignment="LowerLeft", image="ui_arcs", offsetXY="20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_showarc"}},
            {tag="button", attributes={id="btn_hide_arc", active=(arcsActive and arcsOn), height="30", width="30", rectAlignment="LowerLeft", image="ui_arcs", offsetXY="20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_hidearc"}},
            {tag="button", attributes={id="btn_arc_sub", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_minus", offsetXY="-70 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcsub"}},
            {tag="text", attributes={id="disp_arc_len", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", text=(type(config.ARC.SCALE) == "table" and config.ARC.SCALE[arclen] or arclen), offsetXY="-40 0", color="#ffffff", fontSize="20", outline="#000000"}},
            {tag="button", attributes={id="btn_arc_add", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_plus", offsetXY="-10 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcadd"}},
            {tag="button", attributes={height="30", width="30", rectAlignment="LowerRight", image="ui_reload", offsetXY="-50 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="rebuildUI", active=((config.READONLY or false) == false)}},
            {tag="button", attributes={height="30", width="30", rectAlignment="LowerRight", image="ui_gear", offsetXY="-20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)", active=((config.READONLY or false) == false)}},
            ui_bars,
            ui_markers
        }
    }
    local ui_settings_bars = {
        tag="panel",
        attributes={id="ui_settings_bars", offsetXY="0 40", height="400", rectAlignment="LowerCenter", color="White", active=(uimode_settings == 1)},
        children={
            {
                tag="VerticalScrollView",
                attributes={
                    width=500,
                    height="340",
                    rotation="0.1 0 0",
                    rectAlignment="UpperCenter",
                    color="transparent",
                    offsetXY="0 -30",
                },
                children={
                    {
                        tag="TableLayout",
                        attributes={columnWidths="0 100 60 60 30 30", childForceExpandHeight="false", cellBackgroundColor="transparent", autoCalculateHeight="true", padding="6 6 6 6"},
                        children={
                            {tag="Row", attributes={preferredHeight="30"}, children={
                                {tag="Cell", children={{tag="Text", attributes={text="Name"}}}},
                                {tag="Cell", children={{tag="Text", attributes={text="Color"}}}},
                                {tag="Cell", children={{tag="Text", attributes={text="Current"}}}},
                                {tag="Cell", children={{tag="Text", attributes={text="Max"}}}},
                                {tag="Cell", children={{tag="Text", attributes={text="Big"}}}},
                            }}
                        }
                    }

                }
            },
            { tag="text", attributes={fontSize="24", height="30", text="BARS", rectAlignment="UpperLeft", alignment="MiddleCenter"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerLeft", text="Add Bar", onClick="ui_addBar"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerRight", text="Clear Bars", onClick="ui_clearBars"} },
        }
    }
    local ui_settings_markers = {
        tag="panel",
        attributes={id="ui_settings_markers", offsetXY="0 40", height="400", rectAlignment="LowerCenter", color="White", active=(uimode_settings == 2)},
        children={
            {
                tag="VerticalScrollView",
                attributes={
                    width=500,
                    height="340",
                    rotation="0.1 0 0",
                    rectAlignment="UpperCenter",
                    offsetXY="0 -30",
                    active=(uimode_settings == 2),
                    color="transparent"
                },
                children={
                    {
                        tag="GridLayout",
                        attributes={padding="6 6 6 6", cellSize="120 120", spacing="2 2", childForceExpandHeight="false", autoCalculateHeight="true"},
                        children={

                        }
                    }

                }
            },
            { tag="text", attributes={fontSize="24", height="30", text="MARKERS", rectAlignment="UpperLeft", alignment="MiddleCenter"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerRight", text="Clear Markers", onClick="ui_clearMarkers"} },
        }
    }
    local ui_settings = {
        tag="panel",
        attributes={
            id="ui_settings",
            height="0",
            width=500,
            position="0 0 -"..(tonumber(config.UPPER_BOUNDS) or 1.5) * 100,
            rotation="-90 0 0",
            scale="0.5 0.5 0.5",
            active=(uimode_settings ~= 0),
        },
        children={
            --{tag="button", attributes={id="btn_hide", height="20", width="20", rectAlignment="LowerCenter", image="ui_hide", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_bars", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_stack", offsetXY="40 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(2)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerCenter", image="ui_close", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(0)"}},
            ui_settings_bars,
            ui_settings_markers,
        }
    }

    for i,bar in pairs(state.bars) do
        local cur = tonumber(bar[3]) or 0
        local max = tonumber(bar[4]) or 0
        local per = (max == 0) and 0 or (cur / max * 100)
        local y = (#(state.bars)+1-i)*20
        table.insert(ui_bars.children, {
            tag="panel",
            attributes={rectAlignment="LowerCenter", offsetXY="0 "..y},
            children={
                {tag="button", attributes={width="20", height="20", rectAlignment="MiddleLeft", image="ui_minus", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_adjBar("..i.."|-1)", active=((config.READONLY or false)==false)}},
                {tag="progressbar", attributes={id="bar_"..i, height=bar[5] and 20 or 14, width=w-40, rectAlignment="MiddleCenter", color="#00000080", fillImageColor=bar[2], percentage=per, textColor="transparent"}},
                {tag="button", attributes={width="20", height="20", rectAlignment="MiddleRight", image="ui_plus", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_adjBar("..i.."|1)", active=((config.READONLY or false)==false)}},
            }
        })
        table.insert(ui_settings_bars.children[1].children[1].children, {tag="Row", attributes={preferredHeight="30"}, children={
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_name", onEndEdit="ui_setBar", text=bar[1] or ""}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_color", onEndEdit="ui_setBar", text=bar[2] or "#ffffff"}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_current", onEndEdit="ui_setBar", text=bar[3] or 10}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_max", onEndEdit="ui_setBar", text=bar[4] or 10}}}},
            {tag="Cell", children={{tag="Toggle", attributes={id="inp_bar_"..i.."_big", onValueChanged="ui_setBar", isOn=bar[5] or false}}}},
            {tag="Cell", children={{tag="Button", attributes={onClick="ui_removeBar("..i..")", image="ui_close", colors="black|#808080|#cccccc"}}}},
        }})
    end

    local sx = 0;
    local sy = 0;
    for i,marker in pairs(state.markers) do
        table.insert(ui_markers.children, {
            tag="image",
            attributes={
                width=50,
                height=50,
                image=assetBuffer[marker[2]],
                color=marker[3],
                rectAlignment="LowerLeft",
                offsetXY=(sx).." "..(sy)
            }
        })
        table.insert(ui_markers.children, {
            tag="text",
            attributes={
                id="counter_mk_"..i,
                width=50,
                height=50,
                rectAlignment="LowerLeft",
                offsetXY=(sx).." "..(sy+5),
                text=marker[4] > 1 and marker[4] or "",
                color="white",
                alignment="UpperLeft",
            },
        })
        table.insert(ui_settings_markers.children[1].children[1].children, {
            tag="panel",
            children={
                {tag="image", attributes={width=90, height=90, image=assetBuffer[marker[2]], color=marker[3], rectAlignment="MiddleCenter"}},
                {tag="text", attributes={id="disp_mk_"..i, width=30, height=30, fontSize=20, text=marker[4] > 1 and marker[4] or "", rectAlignment="UpperLeft", alignment="MiddleLeft", offsetXY="5 0"}},
                {tag="button", attributes={width=30, height=30, image="ui_close", rectAlignment="UpperRight", colors="black|#808080|#cccccc", alignment="UpperRight", onClick="ui_popMarker("..i..")"}},
                {tag="text", attributes={width=110, height=30, rectAlignment="LowerCenter", resizeTextMinSize=10, resizeTextMaxSize=14, resizeTextForBestFit=true, fontStyle="Bold", text=marker[1], color="Black", alignment="LowerCenter"}},
            }
        })
        sx = sx + 55;
        if (sx >= w-55) then
            sx = 0
            sy = sy + 55;
        end
    end
    self.UI.setXmlTable({ui_overhead, ui_settings})
end

function miniutilSave(save)
    save.bars = state.bars
    save.markers = state.markers
    if (controllerObj ~= nil) then
        save.controller = controllerObj.guid
    end
    return save
end

function miniutilLoad(save)
    state.bars = save.bars or config.DEFAULT_STATE.bars or {}
    state.markers = save.markers or config.DEFAULT_STATE.markers or {}
    if (save.controller ~= nil) then
        local theObj = getObjectFromGUID(save.controller)
        if (theObj ~= nil) then
            if (theObj.call("verify", {guid=self.guid})) then
                controllerObj = theObj
            end
        end
    end
    rebuildAssets()
    Wait.frames(rebuildUI, config.REFRESH_DELAY or 3)
end
