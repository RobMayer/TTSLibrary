TRH_Class = "mini" --leave this be. it's how tokens recognize this as a valid target
TRH_Version = "2.4"

local const = { SPECTATOR = 1, PLAYER = 2, PROMOTED = 4, BLACK = 8, HOST = 16, ALL = 31, NOSPECTATOR = 30, LARGEBAR = 30, SMALLBAR=15 }

config = {} --[[CONFIG GOES HERE]]

local preloaded_assets = {}

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

local state = {}
local uimode_settings = 0
local arclen = 1;
local arcobj;
local controllerObj
local assetBuffer = {}
local flagOn = false

--Arc
function showArc()


	if (config.ARCMODE ~= 0) then
		local theScale = config.ARCSCALE
		local theMesh = config.ARCMESH

		self.UI.hide("btn_show_arc")
        self.UI.show("btn_hide_arc")

		if (config.ARCMODE == 1) then -- Incremental
			self.UI.show("disp_arc_len")
            self.UI.show("btn_arc_sub")
            self.UI.show("btn_arc_add")
			theScale = config.ARCSCALE * (arclen + (config.ARCZERO or 0))
		elseif (config.ARCMODE == 2) then --Static

		elseif (config.ARCMODE == 3) then --Brackets
			self.UI.show("disp_arc_len")
            self.UI.show("btn_arc_sub")
            self.UI.show("btn_arc_add")
			theScale = config.ARCSCALE * (config.ARCBRACKETS[arclen] + (config.ARCZERO or 0))
		end

		arcobj = spawnObject({
            type = "custom_model",
            position = self.getPosition(),
            rotation = self.getRotation(),
			scale = {theScale, 1, theScale},
            mass = 0,
            sound = false,
            snap_to_grid = false,
            callback_function = function(obj)

                if (string.lower(config.ARCCOLOR or "INHERIT") == "inherit") then
                    obj.setColorTint(self.getColorTint())
                else
                    local clr = string.sub(config.ARCCOLOR, 2, 7) or "ffffff"
                    if (string.len(clr) ~= 6) then clr = "ffffff" end
                    obj.setColorTint({
                        (tonumber(string.sub(clr, 1, 2),16) or 255) / 255,
                        (tonumber(string.sub(clr, 3, 4),16) or 255) / 255,
                        (tonumber(string.sub(clr, 5, 6),16) or 255) / 255,
                    })
                end
                obj.setVar("parent", self)
                obj.setLuaScript("function onUpdate() if (parent ~= nil) then if (not parent.resting) then self.setPosition(parent.getPosition()) self.setRotation(parent.getRotation()) end else self.destruct() end end")
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
            mesh = theMesh,
            collider = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/utility/null_COL.obj",
            material = 3,
            specularIntensity = 0,
            cast_shadows = false,
        })

	end
end

function hideArc()
	if (arcobj ~= nil) then
		arcobj.destruct()
	end
	if (config.ARCMODE ~= 0) then
		self.UI.show("btn_show_arc")
	end
	self.UI.hide("btn_hide_arc")
	self.UI.hide("disp_arc_len")
	self.UI.hide("btn_arc_sub")
	self.UI.hide("btn_arc_add")
end

function setArcValue(data)
    if (arcobj ~= nil) then
        arclen = tonumber(data.value) or arclen
		if (config.ARCMODE == 1) then --incremental
			arcobj.setScale({(arclen + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (arclen + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCMODE == 3) then --brackets
			arcobj.setScale({(config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCBRACKETS[arclen])
		end
    end
end

function arcSub()
    if (arcobj ~= nil) then
        arclen = math.max(1, arclen - 1)
        if (config.ARCMODE == 1) then --incremental
			arcobj.setScale({(arclen + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (arclen + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCMODE == 3) then --brackets
			arcobj.setScale({(config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCBRACKETS[arclen])
		end
    end
end

function arcAdd()
    if (arcobj ~= nil) then


		if (config.ARCMODE == 1) then --incremental
			arclen = math.min(config.ARCMAX, arclen + 1)
			arcobj.setScale({(arclen + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (arclen + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCMODE == 3) then --brackets
			arclen = math.min(#(config.ARCBRACKETS), arclen + 1)
			arcobj.setScale({(config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (config.ARCBRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCBRACKETS[arclen])
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
        Wait.frames(rebuildUI, config.REFRESH or 3)
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
    self.UI.setAttribute("bar_container_"..index, "minHeight", isBig and const.LARGEBAR or const.SMALLBAR)

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

--Flags

function toggleFlag()
    flagOn = not(flagOn)
    if (flagOn) then
        self.UI.show("flag_container")
    else
        self.UI.hide("flag_container")
    end
end

function setFlag(data)

    if (data.image ~= nil) then
        if (data.image ~= "") then
            state.flag.image = data.image
        end
        self.UI.setAttribute("inp_flag_image", "value", data.image)
    end
    if (data.width ~= nil) then
        local n = tonumber(data.width)
        if (n ~= nil) then
            state.flag.width = n
        end
        self.UI.setAttribute("inp_flag_width", "value", data.width)
    end
    if (data.height ~= nil) then
        local n = tonumber(data.height)
        if (n ~= nil) then
            state.flag.height = n
        end
        self.UI.setAttribute("inp_flag_height", "value", data.height)
    end
    if (data.color ~= nil) then
        if (string.len(data.color) == 7 and string.sub(data.color, 1, 1) == "#") then
            state.flag.color = data.color
        end
        self.UI.setAttribute("inp_flag_color", "value", data.color)
    end
    if (data.automode ~= nil) then
        state.flag.automode = data.automode
        self.UI.setAttribute("inp_flag_automode", "isOn", data.automode)
        flagOn = data.automode
    end

end

function clearFlag()
	state.flag.image = ""
	self.UI.setAttribute("inp_flag_image", "value", "")
	state.flag.width = 0
	self.UI.setAttribute("inp_flag_width", "value", 0)
	state.flag.height = 0
	self.UI.setAttribute("inp_flag_height", "value", 0)
	state.flag.color = "#ffffff"
	self.UI.setAttribute("inp_flag_color", "value", "#ffffff")
	state.flag.automode = false
	self.UI.setAttribute("inp_flag_automode", "isOn", false)
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

function unsubscribe()
    if (controllerObj ~= nil) then
        controllerObj.call("untrack", {guid=self.guid})
    end
	if (arcObj ~= nil) then
        arcObj.destruct()
    end
end


--[[
UI functions - don't use these - use the original hooks above
]]

--bars
function ui_addBar(player)
    addBar({name="Name", color="#ffffff", current=5, maximum=10})
end
function ui_removeBar(player, index)
    removeBar({index=index})
end
function ui_setBar(player, val, id)
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
function ui_adjBar(player, params)
    local args = {}
    for a in string.gmatch(params, "([^%|]+)") do
        table.insert(args,a)
    end
    local index = tonumber(args[1]) or 1
    local amount = tonumber(args[2]) or 1
    adjustBar({index=index, amount=amount})
end
function ui_clearBars(player)
    clearBars()
end

--Markers
function ui_popMarker(player, index)
    popMarker({index=index})
end

--Flag
function ui_setflag(player, val, id)
    local args = {}
    for a in string.gmatch(id, "([^%_]+)") do
        table.insert(args,a)
    end
    local key = args[3]
    if (key == "image") then
        setFlag({image=val})
    elseif (key == "color") then
        setFlag({color=val})
    elseif (key == "width") then
        setFlag({width=val})
    elseif (key == "height") then
        setFlag({height=val})
    elseif (key == "automode") then
        setFlag({automode=(val == "True")})
    end
end
function ui_clearflag(player)
	clearFlag()
end


--Arcs
function ui_showarc(player) showArc() end
function ui_hidearc(player) hideArc() end
function ui_arcadd(player) arcAdd() end
function ui_arcsub(player) arcSub() end

function ui_flag(player) toggleFlag() end



--ui util functions
function uimode(player, mode)
    mode = tonumber(mode) or 0
    uimode_settings = mode
    if (mode == 0) then
        rebuildAssets()
        Wait.frames(rebuildUI, config.REFRESH or 3)
    else
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
        {name="ui_flag", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/flag.png"},
    }
    for theName,theUrl in pairs(preloaded_assets) do
        table.insert(assets, {name=theName, url=theUrl})
    end
    if (state.flag.image ~= nil and state.flag.width ~= nil and state.flag.height ~= nil) then
        table.insert(assets, {name="fl_image", url=state.flag.image})
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

    local arcsActive = config.ARCMODE ~= 0
    local flagActive = (state.flag.image ~= nil and state.flag.height ~= nil and state.flag.width ~= nil and state.flag.height > 0 and state.flag.width > 0);
    local arcsOn = arcobj ~= nil
    local arcsScalable = false
    if (config.ARCMODE == 1) then --incremental
        arcsScalable = true
    end
    if (config.ARCMODE == 3) then --brackets
        arcsScalable = (#(config.ARCBRACKETS or {}) > 1)
    end

	local w = math.max(200, (tonumber(config.UI_WIDTH) or 1) / ((config.UI_SCALE or 1)) * 200)
	local orient = config.UI_ORIENT or "VERTICAL"
	
    local mainBarList = {}
    local mainMarkerList = {}
	local mainFlag = flagActive and ({tag="Panel", attributes={ id="flag_container", minHeight=(state.flag.height) * 100, active=(flagOn == true) }, children={ {tag="image", attributes={image="fl_image", width=((state.flag.width) * 100), color=state.flag.color or "#ffffff"}} } }) or {}


    local ui_settings_bars = {
        tag="panel",
        attributes={id="ui_settings_bars", offsetXY="0 40", height="400", rectAlignment="LowerCenter", color="black", active=(uimode_settings == 1)},
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
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Name"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Color"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Current"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Max"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Big"}}}},
                            }}
                        }
                    }

                }
            },
            { tag="text", attributes={fontSize="24", height="30", text="BARS", color="#cccccc", rectAlignment="UpperLeft", alignment="MiddleCenter"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerLeft", text="Add Bar", onClick="ui_addBar"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerRight", text="Clear Bars", onClick="ui_clearBars"} },
        }
    }
    local ui_settings_markers = {
        tag="panel",
        attributes={id="ui_settings_markers", offsetXY="0 40", height="400", rectAlignment="LowerCenter", color="black", active=(uimode_settings == 2)},
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
            { tag="text", attributes={fontSize="24", height="30", text="MARKERS", color="#cccccc", rectAlignment="UpperLeft", alignment="MiddleCenter"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerRight", text="Clear Markers", onClick="ui_clearMarkers"} },
        }
    }
    local ui_settings_flag = {
        tag="panel",
        attributes={id="ui_settings_flag", offsetXY="0 40", height="400", rectAlignment="LowerCenter", color="black", active=(uimode_settings == 3)},
        children={
            {tag="VerticalLayout", attributes = {width=500, height="340", spacing="5", rectAlignment="UpperCenter", offsetXY="0 -30", childForceExpandHeight=false, padding="5 5 5 5"}, children={
                {tag="Text", attributes={text="URL", color="#ffffff", alignment="MiddleLeft", minHeight="20"}},
                {tag="InputField", attributes={id="inp_flag_image", text=(state.flag.image), onEndEdit="ui_setflag", minheight="30"}},
                {tag="HorizontalLayout", attributes={childForceExpandHeight=false, spacing="5"}, children={
                    {tag="Text", attributes={text="Width", color="#ffffff", alignment="MiddleLeft", minheight="30", preferredWidth="50"}},
                    {tag="InputField", attributes={id="inp_flag_width", text=(state.flag.width), onEndEdit="ui_setflag", minheight="30", preferredWidth="50"}},
                    {tag="Text", attributes={text="Height", color="#ffffff", alignment="MiddleLeft", minheight="30", preferredWidth="50", preferredWidth="50"}},
                    {tag="InputField", attributes={id="inp_flag_height", text=(state.flag.height), onEndEdit="ui_setflag", minheight="30", preferredWidth="50"}},
                }},
                {tag="HorizontalLayout", attributes={childForceExpandHeight=false, spacing="5"}, children={
                    {tag="Text", attributes={text="Color", color="#ffffff", alignment="MiddleLeft", minheight="30", preferredWidth="50", preferredWidth="50"}},
                    {tag="InputField", attributes={id="inp_flag_color", text=(state.flag.color), onEndEdit="ui_setflag", minheight="30", preferredWidth="50"}},
                    {tag="Text", attributes={text="Auto-On", color="#ffffff", alignment="MiddleLeft", minheight="30", preferredWidth="50", preferredWidth="50"}},
                    {tag="Toggle", attributes={id="inp_flag_automode", onValueChanged="ui_setflag", minheight="30", isOn=(state.flag.automode), preferredWidth="50"}},
                }},
            }},
            { tag="text", attributes={fontSize="24", height="30", text="FLAG", color="#cccccc", rectAlignment="UpperLeft", alignment="MiddleCenter"} },
            { tag="Button", attributes={width="150", height="30", rectAlignment="LowerRight", text="Remove Flag", onClick="ui_clearflag"} },
        }
    }

    for i,marker in pairs(state.markers) do
        table.insert(mainMarkerList, {
            tag="panel", attributes={}, children={
                {tag="image", attributes={
                    image=assetBuffer[marker[2]],
                    color=marker[3],
                    rectAlignment="LowerLeft",
                    width="60",
                    height="60"
                }},
                {tag="text", attributes={
                    id="counter_mk_"..i,
                    text=marker[4] > 1 and marker[4] or "",
                    color="#ffffff",
                    rectAlignment="UpperRight",
                    width="20",
                    height="20"
                }},
            }
        })
        table.insert(ui_settings_markers.children[1].children[1].children, {
            tag="panel",
            attributes={color="#cccccc"},
            children={
                {tag="image", attributes={width=90, height=90, image=assetBuffer[marker[2]], color=marker[3], rectAlignment="MiddleCenter"}},
                {tag="text", attributes={id="disp_mk_"..i, width=30, height=30, fontSize=20, text=marker[4] > 1 and marker[4] or "", rectAlignment="UpperLeft", alignment="MiddleLeft", offsetXY="5 0"}},
                {tag="button", attributes={width=30, height=30, image="ui_close", rectAlignment="UpperRight", colors="black|#808080|#cccccc", alignment="UpperRight", onClick="ui_popMarker("..i..")"}},
                {tag="text", attributes={width=110, height=30, rectAlignment="LowerCenter", resizeTextMinSize=10, resizeTextMaxSize=14, resizeTextForBestFit=true, fontStyle="Bold", text=marker[1], color="Black", alignment="LowerCenter"}},
            }
        })
    end

    for i,bar in pairs(state.bars) do
        local cur = tonumber(bar[3]) or 0
        local max = tonumber(bar[4]) or 0
        local per = (max == 0) and 0 or (cur / max * 100)
        local y = (#(state.bars)+1-i)*20
        table.insert(mainBarList, {
            tag="horizontallayout",
            attributes={id="bar_container_"..i, minHeight=(bar[5] and const.LARGEBAR or const.SMALLBAR), childForceExpandWidth=false, childForceExpandHeight=false, childAlignment="MiddleCenter"},
            children={
                {tag="button", attributes={preferredHeight="20", preferredWidth="20", flexibleWidth="0", image="ui_minus", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_adjBar("..i.."|-1)", visibility=config.PERMEDIT}},
                {tag="panel", attributes={flexibleWidth="1", flexibleHeight="1"}, children={
                    {tag="progressbar", attributes={width="100%", height="100%", id="bar_"..i, color="#00000080", fillImageColor=bar[2], percentage=per, textColor="transparent"}},
                }},
                {tag="button", attributes={preferredHeight="20", preferredWidth="20", flexibleWidth="0", image="ui_plus", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_adjBar("..i.."|1)", visibility=config.PERMEDIT}},
            }
        })
        table.insert(ui_settings_bars.children[1].children[1].children, {tag="Row", attributes={preferredHeight="30"}, children={
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_name", onEndEdit="ui_setBar", text=bar[1] or ""}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_color", onEndEdit="ui_setBar", text=bar[2] or "#ffffff"}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_current", onEndEdit="ui_setBar", text=bar[3] or 10}}}},
            {tag="Cell", children={{tag="InputField", attributes={id="inp_bar_"..i.."_max", onEndEdit="ui_setBar", text=bar[4] or 10}}}},
            {tag="Cell", children={{tag="Toggle", attributes={id="inp_bar_"..i.."_big", onValueChanged="ui_setBar", isOn=bar[5] or false}}}},
            {tag="Cell", children={{tag="Button", attributes={onClick="ui_removeBar("..i..")", image="ui_close", colors="#cccccc|#ffffff|#808080"}}}},
        }})
    end

    local ui_settings = {
        tag="panel",
        attributes={
            id="ui_settings",
            height="0",
            width=500,
            position="0 0 -"..(tonumber(config.UI_HEIGHT) or 1.5) * 100,
            rotation=(orient == "HORIZONTAL" and "0 0 0" or "-90 0 0"),
            scale=((config.UI_SCALE or 1) / 2.0).." "..((config.UI_SCALE or 1) / 2.0).." "..((config.UI_SCALE or 1) / 2.0),
            active=(uimode_settings ~= 0),
            visibility=config.PERMEDIT
        },
        children={
            --{tag="button", attributes={id="btn_hide", height="20", width="20", rectAlignment="LowerCenter", image="ui_hide", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_bars", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_stack", offsetXY="40 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(2)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_flag", offsetXY="80 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(3)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerCenter", image="ui_close", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(0)"}},
            ui_settings_bars,
            ui_settings_markers,
            ui_settings_flag,
        }
    }

    local ui_main = {
        tag="Panel",
        attributes={
            childForceExpandHeight="false",
            visibility=config.PERMVIEW,
            position="0 0 -"..(tonumber(config.UI_HEIGHT) or 1.5) * 100,
            rotation=(orient == "HORIZONTAL" and "0 0 0" or "-90 0 0"),
            active=(uimode_settings == 0),
            scale=((config.UI_SCALE or 1) / 2.0).." "..((config.UI_SCALE or 1) / 2.0).." "..((config.UI_SCALE or 1) / 2.0),
            height=0,
            color="red",
            width=w,
        },
        children={
            {tag="VerticalLayout", attributes={rectAlignment="LowerCenter", childAlignment="LowerCenter", childForceExpandHeight=false, childForceExpandWidth=true, height="5000", spacing="5"}, children={
				mainFlag,
                {tag="GridLayout", attributes={contentSizeFitter="vertical", childAlignment="LowerLeft", flexibleHeight="0", cellSize="70 70", padding="20 20 0 0"}, children=mainMarkerList},
                {tag="VerticalLayout", attributes={contentSizeFitter="vertical", childAlignment="LowerCenter", flexibleHeight="0"}, children=mainBarList},
                {tag="Panel", attributes={minHeight="30", flexibleHeight="0"}, children={
                    {tag="button", attributes={id="btn_show_arc", active=(arcsActive and not arcsOn), height="30", width="30", rectAlignment="MiddleLeft", image="ui_arcs", offsetXY="20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_showarc", visibility=config.PERMEDIT}},
                    {tag="button", attributes={id="btn_hide_arc", active=(arcsActive and arcsOn), height="30", width="30", rectAlignment="LowerLeft", image="ui_arcs", offsetXY="20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_hidearc", visibility=config.PERMEDIT}},
                    {tag="button", attributes={id="btn_arc_sub", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_minus", offsetXY="-70 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcsub", visibility=config.PERMEDIT}},
                    {tag="text", attributes={id="disp_arc_len", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", text=((config.ARCMODE == 3) and config.ARCBRACKETS[arclen] or arclen), offsetXY="-40 0", color="#ffffff", fontSize="20", outline="#000000", visibility=config.PERMEDIT}},
                    {tag="button", attributes={id="btn_arc_add", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_plus", offsetXY="-10 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcadd", visibility=config.PERMEDIT}},
                    {tag="button", attributes={id="btn_flag_toggle", active=flagActive, height="30", width="30", rectAlignment="LowerRight", image="ui_flag", offsetXY="-80 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_flag", visibility=config.PERMEDIT}},
                    {tag="button", attributes={height="30", width="30", rectAlignment="LowerRight", image="ui_gear", offsetXY="-50 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)", visibility=config.PERMEDIT}},
                    {tag="button", attributes={height="30", width="30", rectAlignment="LowerRight", image="ui_reload", offsetXY="-20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="rebuildUI", visibility=config.PERMVIEW}},
                }},
            }}
        }
    }
    self.UI.setXmlTable({ui_main, ui_settings})
end

function miniutilSave(save)
    save.bars = state.bars
    save.markers = state.markers
    save.flag = state.flag
    if (controllerObj ~= nil) then
        save.controller = controllerObj.guid
    end
    return save
end

function miniutilLoad(save)
    state.bars = save.bars or {}
    state.markers = save.markers or {}
    state.flag = save.flag or {}
    flagOn = state.flag.automode or false
    if (save.controller ~= nil) then
        local theObj = getObjectFromGUID(save.controller)
        if (theObj ~= nil) then
            if (theObj.call("verify", {guid=self.guid})) then
                controllerObj = theObj
            end
        end
    end
    rebuildAssets()
    Wait.frames(rebuildUI, config.REFRESH or 3)
end