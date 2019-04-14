TRH_Class = "mini" --leave this be. it's how tokens recognize this as a valid target
TRH_Version = "4.0"

local const = { SPECTATOR = 1, PLAYER = 2, PROMOTED = 4, BLACK = 8, HOST = 16, ALL = 31, NOSPECTATOR = 30, LARGEBAR = 30, SMALLBAR=15 }

config = {} --[[CONFIG GOES HERE]]

local preloaded_assets = {}

local state = {}
local uimode_settings = 0
local arclen = 1;
local arcobj;
local geoobj;
local controllerObj
local assetBuffer = {}
local flagOn = false

local move_speed
local move_cache
local move_store_pos
local move_store_rot
local isMoving = false
local move_obj

if (config.MODULE_MOVEMENT) then
	if (config.MOVEMENT.MODE == 1) then
		move_speed = {0}
	end
	if (config.MOVEMENT.MODE == 2) then
		move_speed = config.MOVEMENT.SPEEDMIN
	end
	if (config.MOVEMENT.MODE == 3) then
		move_speed = {0}
	end
	if (config.MOVEMENT.MODE == 4) then
		move_speed = 0
	end
end

function onUpdate()
	if (config.MODULE_MOVEMENT) then
		if (config.MOVEMENT.MODE == 2 and isMoving and not(self.resting)) then
			local p = self.getPosition()
			local t = {p[1] - move_cache[1], move_cache[2], p[3] - move_cache[3]}
			local m = math.pow(t[1], 2) + math.pow(t[3], 2)
			if (m > math.pow(move_speed, 2)) then
				local l = math.sqrt(m)
				self.setPosition({
					move_cache[1] + t[1] / l * move_speed,
					p[2],
					move_cache[3] + t[3] / l * move_speed,
				})
			end
		end
	end
end

function onDestroy()
	if (arcobj ~= nil) then
		arcobj.destruct()
	end
	if (config.MODULE_GEOMETRY) then
		if (geoobj ~= nil) then
			geoobj.destruct()
		end
	end
	if (config.MODULE_MOVEMENT) then
		if (move_obj ~= nil) then
			move_obj.destruct()
		end
	end
end

function onSave()
    local save = {}
	save.bars = state.bars
    save.markers = state.markers
    save.flag = state.flag
    if (controllerObj ~= nil) then
        save.controller = controllerObj.guid
    end

    return JSON.encode(save)
end

function onLoad(save)
    save = JSON.decode(save) or {}
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
	if (config.MODULE_GEOMETRY and (config.GEOMETRY.MESH ~= nil)) then
		spawnGeometry()
	end
    rebuildAssets()
    Wait.frames(rebuildUI, config.REFRESH or 3)
end



--MOVEMENT

function rotateVector(direction, yRotation)
    local radrotval = math.rad(yRotation)
    local xDistance = math.cos(radrotval) * direction[1] + math.sin(radrotval) * direction[2]
    local yDistance = math.sin(radrotval) * direction[1] * -1 + math.cos(radrotval) * direction[2]
    return {xDistance, yDistance, direction[3]}
end

function moveCommit()
	if (config.MOVEMENT.MODE == 1) then
		local pos = self.getPosition()
		local rot = self.getRotation()
		local moveTo = rotateVector(move_store_pos, rot[2])
		self.setPositionSmooth({pos[1] + moveTo[1]/100, pos[2], pos[3] + moveTo[2]/100}, false)
		self.setRotationSmooth({rot[1], rot[2] + move_store_rot, rot[3]}, false)
		move_store_pos = {0,0,0}
		move_store_rot = 0
		move_cache = {0,0,0}
	elseif (config.MOVEMENT.MODE == 2) then
		if (move_obj ~= nil) then move_obj.destruct() end
		move_cache = {0,0,0}
	elseif (config.MOVEMENT.MODE == 3) then
		local pos = self.getPosition()
		local rot = self.getRotation()
		local moveTo = rotateVector(move_store_pos, rot[2])
		self.setPositionSmooth({pos[1] + moveTo[1]/100, pos[2], pos[3] + moveTo[2]/100}, false)
		self.setRotationSmooth({rot[1], rot[2] + move_store_rot, rot[3]}, false)
		move_store_pos = {0,0,0}
		move_store_rot = 0
		move_cache = {0,0,0}
	elseif (config.MOVEMENT.MODE == 4) then
		local pos = self.getPosition()
		local rot = self.getRotation()
		if (move_speed > 0) then
			local curDef = config.MOVEMENT.DEFINITIONS[move_speed]
			local moveTo = rotateVector({curDef[5], curDef[6], 0}, rot[2])
			self.setPositionSmooth({pos[1] + moveTo[1], pos[2], pos[3] + moveTo[2]}, false)
			self.setRotationSmooth({rot[1], rot[2] + curDef[7], rot[3]}, false)
			move_speed = 0
		end
	end
	isMoving = false
	rebuildUI()
end

function moveStart()
	if (config.MOVEMENT.MODE == 2) then
		local theScale = move_speed
		if (config.MOVEMENT.ORIGIN == "EDGE") then
			theScale = move_speed + ((config.BASE_LENGTH + config.BASE_WIDTH) / 4.0)
		end
		move_cache = self.getPosition()
		move_obj = spawnObject({
            type = "custom_model",
            position = self.getPosition(),
            rotation = self.getRotation(),
			scale = {theScale, 1, theScale},
            mass = 0,
            sound = false,
            snap_to_grid = false,
            callback_function = function(obj)
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
				obj.setLock(true)
            end,
        })
        move_obj.setCustomObject({
            mesh = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/components/arcs/round0.obj",
            collider = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/utility/null_COL.obj",
            material = 3,
            specularIntensity = 0,
            cast_shadows = false,
        })
	end
	isMoving = true
	rebuildUI()
end

function moveCancel()
	if (config.MOVEMENT.MODE == 1) then
		move_store_pos = {0,0,0}
		move_store_rot = 0
		move_cache = {0,0,0}
	elseif (config.MOVEMENT.MODE == 2) then
		self.setPositionSmooth(move_cache, false)
		if (move_obj ~= nil) then
			move_obj.destruct()
		end
		move_cache = {0,0,0}
	elseif (config.MOVEMENT.MODE == 3) then
		move_store_pos = {0,0,0}
		move_store_rot = 0
		move_cache = {0,0,0}
	end
	isMoving = false
	rebuildUI()
end

function ui_move_commit(player)
	moveCommit()
end


function ui_move_cancel(player)
	moveCancel()
end

function ui_move_select(player, value)
	if (config.MOVEMENT.MODE == 4) then
		move_speed = tonumber(value) or 0
		rebuildUI()
	end
end

function ui_move_faster(player)
	if (config.MOVEMENT.MODE == 1) then
		table.insert(move_speed, 0)
	elseif (config.MOVEMENT.MODE == 2) then
		move_speed = move_speed + 1
		local theScale = move_speed
		if (config.MOVEMENT.ORIGIN == "EDGE") then
			theScale = move_speed + ((config.BASE_LENGTH + config.BASE_WIDTH) / 4.0)
		end
		if (move_obj ~= nil) then
			move_obj.setScale({theScale, 1, theScale})
		end
	elseif (config.MOVEMENT.MODE == 3) then
		table.insert(move_speed, 0)
	end
    rebuildUI()
end

function ui_move_slower(player)
	if (config.MOVEMENT.MODE == 1) then
	    tmp = {}
	    for i,k in pairs(move_speed) do
	        if (i < #move_speed) then
	            table.insert(tmp, k)
	        end
	    end
	    move_speed = tmp
	elseif (config.MOVEMENT.MODE == 2) then
		move_speed = move_speed - 1
		local theScale = move_speed
		if (config.MOVEMENT.ORIGIN == "EDGE") then
			theScale = move_speed + ((config.BASE_LENGTH + config.BASE_WIDTH) / 4.0)
		end
		if (move_obj ~= nil) then
			move_obj.setScale({theScale, 1, theScale})
		end
	elseif (config.MOVEMENT.MODE == 3) then
	    tmp = {}
	    for i,k in pairs(move_speed) do
	        if (i < #move_speed) then
	            table.insert(tmp, k)
	        end
	    end
	    move_speed = tmp
	end
    rebuildUI()
end

function ui_move_dec(player, index)
	if (config.MOVEMENT.MODE == 1) then
	    index = tonumber(index)
	    move_speed[index] = move_speed[index] - 1
	elseif (config.MOVEMENT.MODE == 3) then
	    index = tonumber(index)
	    move_speed[index] = move_speed[index] - 1
	end
    rebuildUI()
end

function ui_move_inc(player, index)
	if (config.MOVEMENT.MODE == 1) then
    	index = tonumber(index)
    	move_speed[index] = move_speed[index] + 1
	elseif (config.MOVEMENT.MODE == 3) then
    	index = tonumber(index)
    	move_speed[index] = move_speed[index] + 1
	end
    rebuildUI()
end

--Geometry

function spawnGeometry()
	if (geoobj ~= nil) then
		geoobj.destruct()
	end
	geoobj = spawnObject({
		type = "custom_model",
		position = self.getPosition(),
		rotation = self.getRotation(),
		scale = self.getScale(),
		mass = 0,
		sound = false,
		snap_to_grid = false,
		callback_function = function(obj)
			if (string.lower(config.GEOMETRY.COLOR or "INHERIT") == "inherit") then
				obj.setColorTint(self.getColorTint())
			else
				local clr = string.sub(config.GEOMETRY.COLOR, 2, 7) or "ffffff"
				if (string.len(clr) ~= 6) then clr = "ffffff" end
				obj.setColorTint({
					(tonumber(string.sub(clr, 1, 2),16) or 255) / 255,
					(tonumber(string.sub(clr, 3, 4),16) or 255) / 255,
					(tonumber(string.sub(clr, 5, 6),16) or 255) / 255,
				})
			end
			obj.setVar("parent", self)
			obj.setLuaScript("function onUpdate() if (parent ~= nil) then if (not parent.resting) then self.setPosition(parent.getPosition()) self.setRotation(parent.getRotation()) self.setScale(parent.getScale()) end else self.destruct() end end")
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
	geoobj.setCustomObject({
		mesh = config.GEOMETRY.MESH,
		diffuse = config.GEOMETRY.TEXTURE,
		normal = config.GEOMETRY.NORMAL,
		collider = "https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/utility/null_COL.obj",
		type = 0,
		material = 1,
	})
end

--Arc
function showArc()

	if (config.MODULE_ARC) then

		local theScale = config.ARCS.SCALE
		local theMesh = config.ARCS.MESH

		self.UI.hide("btn_show_arc")
        self.UI.show("btn_hide_arc")

		if (config.ARCS.MODE == 1) then -- Incremental
			self.UI.show("disp_arc_len")
            self.UI.show("btn_arc_sub")
            self.UI.show("btn_arc_add")
			theScale = config.ARCS.SCALE * (arclen + (config.ARCS.ZERO or 0))
		elseif (config.ARCS.MODE == 2) then --Static

		elseif (config.ARCS.MODE == 3) then --Brackets
			self.UI.show("disp_arc_len")
            self.UI.show("btn_arc_sub")
            self.UI.show("btn_arc_add")
			theScale = config.ARCS.SCALE * (config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0))
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

                if (string.lower(config.ARCS.COLOR or "INHERIT") == "inherit") then
                    obj.setColorTint(self.getColorTint())
                else
                    local clr = string.sub(config.ARCS.COLOR, 2, 7) or "ffffff"
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
		if (config.ARCS.MODE == 1) then --incremental
			arcobj.setScale({(arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE, 1, (arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCS.MODE == 3) then --brackets
			arcobj.setScale({(config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE, 1, (config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCS.BRACKETS[arclen])
		end
    end
end

function arcSub()
    if (arcobj ~= nil) then
        arclen = math.max(1, arclen - 1)
        if (config.ARCS.MODE == 1) then --incremental
			arcobj.setScale({(arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE, 1, (arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCS.MODE == 3) then --brackets
			arcobj.setScale({(config.ARCS.BRACKETS[arclen] + (config.ARCZERO or 0)) * config.ARCSCALE, 1, (config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCS.BRACKETS[arclen])
		end
    end
end

function arcAdd()
    if (arcobj ~= nil) then


		if (config.ARCS.MODE == 1) then --incremental
			arclen = math.min(config.ARCS.MAX, arclen + 1)
			arcobj.setScale({(arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE, 1, (arclen + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", arclen)
		elseif (config.ARCS.MODE == 3) then --brackets
			arclen = math.min(#(config.ARCS.BRACKETS), arclen + 1)
			arcobj.setScale({(config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE, 1, (config.ARCS.BRACKETS[arclen] + (config.ARCS.ZERO or 0)) * config.ARCS.SCALE})
            self.UI.setAttribute("disp_arc_len", "text", config.ARCS.BRACKETS[arclen])
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
        local hasText = false
        if (v[5] ~= nil) then
            hasText = v[5]
        end
        if (v[6] ~= nil) then
            isBig = v[6]
        end
        res[i] = {
            name = v[1],
            color = v[2],
            current = v[3],
            maximum = v[4],
            big = isBig,
            text = hasText
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
    local hasText = false
    if (bar[5] ~= nil) then
        isBig = bar[5]
    end
    if (data.big ~= nil) then
        isBig = data.big
    end
    if (bar[6] ~= nil) then
        hasText = bar[6]
    end
    if (data.text ~= nil) then
        hasText = data.text
    end

    local per = (max == 0) and 0 or cur / max * 100


    self.UI.setAttribute("inp_bar_"..index.."_name", "value", name)
    self.UI.setAttribute("inp_bar_"..index.."_color", "value", color)
    self.UI.setAttribute("inp_bar_"..index.."_current", "value", cur)
    self.UI.setAttribute("inp_bar_"..index.."_max", "value", max)
    self.UI.setAttribute("inp_bar_"..index.."_big", "isOn", isBig)
    self.UI.setAttribute("inp_bar_"..index.."_text", "isOn", hasText)

    self.UI.setAttribute("bar_"..index, "percentage", per)
    self.UI.setAttribute("bar_"..index, "fillImageColor", color)
    self.UI.setAttribute("bar_container_"..index, "minHeight", isBig and const.LARGEBAR or const.SMALLBAR)
    self.UI.setAttribute("bar_text_"..index, "active", hasText)
    self.UI.setAttribute("bar_text_"..index, "text", cur.." / "..max)

    state.bars[index][1] = name
    state.bars[index][2] = color
    state.bars[index][3] = cur
    state.bars[index][4] = max
    state.bars[index][5] = isBig
    state.bars[index][6] = hasText

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
    self.UI.setAttribute("bar_"..index.."_text", "text", cur.." / "..max)
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
    elseif (key == "text") then
        setBar({index=index, text=(val == "True")})
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
function ui_move(player)
	if (isMoving) then
		moveCancel()
	else
		moveStart()
	end
end



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
        {name="ui_arrow_l", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/arrow_l.png"},
        {name="ui_arrow_r", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/arrow_r.png"},
        {name="ui_arrow_u", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/arrow_u.png"},
        {name="ui_arrow_d", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/arrow_d.png"},
        {name="ui_check", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/check.png"},
        {name="ui_block", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/block.png"},
        {name="ui_splitpath", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/splitpath.png"},
        {name="movetool", url="https://raw.githubusercontent.com/RobMayer/TTSLibrary/master/ui/movetool.png"},
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
            assetBuffer[marker[2]] = self.guid.."_asset_"..bufLen
            table.insert(assets, {name=self.guid.."_asset_"..bufLen, url=marker[2]})
        end
    end
	if (config.MODULE_MOVEMENT) then
		if (config.MOVEMENT.MODE == 4) then
			for i,def in pairs(config.MOVEMENT.DEFINITIONS) do
				if (assetBuffer[def[2]] == nil) then
		            bufLen = bufLen + 1
		            assetBuffer[def[2]] = self.guid.."_asset_"..bufLen
		            table.insert(assets, {name=self.guid.."_asset_"..bufLen, url=def[2]})
		        end
		    end
		end
	end
    self.UI.setCustomAssets(assets)
end

function rebuildUI()

    local arcsActive = config.MODULE_ARC or false
    local flagActive = (state.flag.image ~= nil and state.flag.height ~= nil and state.flag.width ~= nil and state.flag.height > 0 and state.flag.width > 0);
	local moveActive = config.MODULE_MOVEMENT or false
    local arcsOn = arcobj ~= nil
    local arcsScalable = false
	if (arcsActive) then

		if (config.ARCS.MODE == 1) then --incremental
			arcsScalable = true
		end
		if (config.ARCS.MODE == 3) then --brackets
			arcsScalable = (#(config.ARCS.BRACKETS or {}) > 1)
		end
	end

	local w = math.max(100, (tonumber(config.OVERHEAD_WIDTH) or 1) / ((config.UI_SCALE or 1)) * 100)
	local orient = config.OVERHEAD_ORIENT or "VERTICAL"

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
                        attributes={columnWidths="0 100 60 60 30 30 30", childForceExpandHeight="false", cellBackgroundColor="transparent", autoCalculateHeight="true", padding="6 6 6 6"},
                        children={
                            {tag="Row", attributes={preferredHeight="30"}, children={
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Name"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Color"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Current"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Max"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Big"}}}},
                                {tag="Cell", children={{tag="Text", attributes={color="#cccccc", text="Text"}}}},
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
                    {tag="text", attributes={id="bar_"..i.."_text", text=cur.." / "..max, active=bar[6] or false, color="#ffffff", fontStyle="Bold", outline="#000000", outlineSize="1 1"}}
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
            {tag="Cell", children={{tag="Toggle", attributes={id="inp_bar_"..i.."_text", onValueChanged="ui_setBar", isOn=bar[6] or false}}}},
            {tag="Cell", children={{tag="Button", attributes={onClick="ui_removeBar("..i..")", image="ui_close", colors="#cccccc|#ffffff|#808080"}}}},
        }})
    end


    local ui_settings = {
        tag="panel",
        attributes={
            id="ui_settings",
            height="0",
            width=500,
            position="0 0 -"..(tonumber(config.OVERHEAD_HEIGHT) or 1.5) * 100,
            rotation=(orient == "HORIZONTAL" and "0 0 0" or "-90 0 0"),
            scale=(config.UI_SCALE or 1).." "..(config.UI_SCALE or 1).." "..(config.UI_SCALE or 1),
            active=(uimode_settings ~= 0),
            visibility=config.PERMEDIT
        },
        children={
            --{tag="button", attributes={id="btn_hide", height="20", width="20", rectAlignment="LowerCenter", image="ui_hide", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_bars", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)"}},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_stack", offsetXY="40 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(2)"}},
            config.MODULE_FLAG and {tag="button", attributes={height="40", width="40", rectAlignment="LowerLeft", image="ui_flag", offsetXY="80 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(3)"}} or {},
            {tag="button", attributes={height="40", width="40", rectAlignment="LowerCenter", image="ui_close", offsetXY="0 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(0)"}},
            ui_settings_bars,
            ui_settings_markers,
            ui_settings_flag,
        }
    }

    local mainButtons = {}
	local moduleX = 20
    if (config.MODULE_ARC) then
        table.insert(mainButtons, {tag="button", attributes={id="btn_show_arc", active=(arcsActive and not arcsOn), height="30", width="30", rectAlignment="MiddleLeft", image="ui_arcs", offsetXY=moduleX.." 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_showarc", visibility=config.PERMEDIT}})
        table.insert(mainButtons, {tag="button", attributes={id="btn_hide_arc", active=(arcsActive and arcsOn), height="30", width="30", rectAlignment="LowerLeft", image="ui_arcs", offsetXY=moduleX.." 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_hidearc", visibility=config.PERMEDIT}})
        table.insert(mainButtons, {tag="button", attributes={id="btn_arc_sub", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_minus", offsetXY="-70 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcsub", visibility=config.PERMEDIT}})
        table.insert(mainButtons, {tag="text", attributes={id="disp_arc_len", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", text=(((config.ARCS.MODE or 0) == 3) and config.ARCS.BRACKETS[arclen] or arclen), offsetXY="-40 0", color="#ffffff", fontSize="20", outline="#000000", visibility=config.PERMEDIT}})
        table.insert(mainButtons, {tag="button", attributes={id="btn_arc_add", active=(arcsActive and arcsOn and arcsScalable), height="30", width="30", rectAlignment="LowerLeft", image="ui_plus", offsetXY="-10 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_arcadd", visibility=config.PERMEDIT}})
		moduleX = moduleX + 30
    end

    if (config.MODULE_FLAG and flagActive) then
        table.insert(mainButtons, {tag="button", attributes={id="btn_flag_toggle", active=flagActive, height="30", width="30", rectAlignment="MiddleLeft", image="ui_flag", offsetXY=moduleX.." 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_flag", visibility=config.PERMEDIT}})
		moduleX = moduleX + 30
    end

	if (config.MODULE_MOVEMENT) then
        table.insert(mainButtons, {tag="button", attributes={id="btn_move_toggle", active=moveActive, height="30", width="30", rectAlignment="MiddleLeft", image="ui_splitpath", offsetXY=moduleX.." 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="ui_move", visibility=config.PERMEDIT}})
		moduleX = moduleX + 30
    end

    table.insert(mainButtons, {tag="button", attributes={height="30", width="30", rectAlignment="MiddleRight", image="ui_gear", offsetXY="-50 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="uimode(1)", visibility=config.PERMEDIT}})
    table.insert(mainButtons, {tag="button", attributes={height="30", width="30", rectAlignment="MiddleRight", image="ui_reload", offsetXY="-20 0", colors="#ccccccff|#ffffffff|#404040ff|#808080ff", onClick="rebuildUI", visibility=config.PERMVIEW}})

    local ui_main = {
        tag="Panel",
        attributes={
            childForceExpandHeight="false",
            visibility=config.PERMVIEW,
            position="0 0 -"..(tonumber(config.OVERHEAD_HEIGHT) or 1.5) * 100,
            rotation=(orient == "HORIZONTAL" and "0 0 0" or "-90 0 0"),
            active=(uimode_settings == 0),
            scale=(config.UI_SCALE or 1).." "..(config.UI_SCALE or 1).." "..(config.UI_SCALE or 1),
            height=0,
            color="red",
            width=w,
        },
        children={
            {tag="VerticalLayout", attributes={rectAlignment="LowerCenter", childAlignment="LowerCenter", childForceExpandHeight=false, childForceExpandWidth=true, height="5000", spacing="5"}, children={
				mainFlag,
                {tag="GridLayout", attributes={contentSizeFitter="vertical", childAlignment="LowerLeft", flexibleHeight="0", cellSize="70 70", padding="20 20 0 0"}, children=mainMarkerList},
                {tag="VerticalLayout", attributes={contentSizeFitter="vertical", childAlignment="LowerCenter", flexibleHeight="0"}, children=mainBarList},
                {tag="Panel", attributes={minHeight="30", flexibleHeight="0"}, children=mainButtons},
            }}
        }
    }

	local ui_movement = {}
	if (config.MODULE_MOVEMENT and isMoving) then
		if (config.MOVEMENT.MODE == 1) then
			local list = {}
			move_store_pos = {0,0,0}
			move_store_rot = 0
			local pos = {0,0,0}
			local rot = 0
			local displayPos = {0,0,0}

			for i,v in pairs(move_speed) do
				rot = rot + (v * config.MOVEMENT.TURNNOTCH)
				local tmp = {
					tag="Panel",
					attributes={color="transparent", rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.MOVEMENT.SPEEDDISTANCE * 100), position=table.concat(pos, " "), rotation="0 0 "..-rot},
					children={
						{tag="Image", attributes={color="#ffffff", image="movetool", width=(config.BASE_WIDTH * 25), height=(config.BASE_LENGTH * 25), rectAlignment="MiddleCenter"}},
						{tag="Button", attributes={image="ui_arrow_l", width=(20), height=(40), onClick="ui_move_dec("..i..")", active=(v > -config.MOVEMENT.TURNMAX), rectAlignment="MiddleLeft"}},
						{tag="Button", attributes={image="ui_arrow_r", width=(20), height=(40), onClick="ui_move_inc("..i..")", active=(v < config.MOVEMENT.TURNMAX), rectAlignment="MiddleRight"}},
					}
				}
				table.insert(list, tmp)
				move_store_pos = pos
				move_store_rot = rot
				displayPos = pos
				pos = rotateVector({pos[1], pos[2], pos[3]}, -rot)
				pos = rotateVector({pos[1], pos[2] + config.MOVEMENT.SPEEDDISTANCE * 100, pos[3]}, rot)
			end

			local commitcolor = "00ff00"
			if ((config.MOVEMENT.LANDSHOW or true) and (config.MOVEMENT.LANDTEST or true)) then
				local tpos = self.getPosition()
				local trot = self.getRotation()
				local t = rotateVector(move_store_pos, trot[2])
				local cast = Physics.cast({
					origin = {x=tpos[1] + t[1] / 100, y=tpos[2], z=tpos[3] + t[2] / 100},
					direction = {0,1,0},
					max_distance = 0.5,
					type = 3,
					size = {config.BASE_WIDTH, 0.25, config.BASE_LENGTH},
					orientation = {0, trot[2] + move_store_rot, 0},
				})
				for i,col in pairs(cast) do
					if (col.hit_object ~= self) then
						commitcolor = "ff0000"
					end
				end
			end

			ui_movement = {
				tag="Panel", attributes={position="0 0 -"..(config.MOVEMENT.UIHEIGHT * 100), rectAlignment="MiddleCenter"}, children={
					{tag="panel", attributes={rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position=table.concat(displayPos, " "), rotation="0 0 "..-rot}, children={
						{tag="panel", attributes={color="#"..commitcolor.."44", active=(config.MOVEMENT.LANDSHOW), rectAlignment="MiddleCenter", position="0 0 "..(config.MOVEMENT.UIHEIGHT * 100 - 1)}},
					}},
					{tag="panel", attributes={width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position="0 0 0", rotation="0 0 0"}, children={
						{tag="panel", attributes={rectAlignment="LowerCenter", width="120", height="80", offsetXY="0 -80"}, children={
							{tag="Button", attributes={image="ui_plus", width=(40), height=(40), onClick="ui_move_faster", active=(#move_speed < config.MOVEMENT.SPEEDMAX), rectAlignment="UpperCenter"}},
							{tag="Button", attributes={image="ui_minus", width=(40), height=(40), onClick="ui_move_slower", active=(#move_speed > 1), rectAlignment="LowerCenter"}},
							{tag="Button", attributes={image="ui_block", color="#ff0000", width=(40), height=(40), onClick="ui_move_cancel", rectAlignment="MiddleLeft"}},
							{tag="Button", attributes={image="ui_check", color="#00ff00", width=(40), height=(40), onClick="ui_move_commit", rectAlignment="MiddleRight"}},
						}},
					}},
					table.unpack(list)
				}
			}
		elseif (config.MOVEMENT.MODE == 2) then --Force Radius
			ui_movement = {
				tag="Panel", attributes={position="0 0 -"..(config.MOVEMENT.UIHEIGHT * 100), rectAlignment="MiddleCenter"}, children={
					{tag="panel", attributes={rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position="0 0 0", rotation="0 0 0"}, children={
						{tag="panel", attributes={rectAlignment="LowerCenter", width="120", height="80", offsetXY="0 -"..(config.BASE_LENGTH * 50)}, children={
							{tag="Button", attributes={image="ui_plus", width=(40), height=(40), onClick="ui_move_faster", active=(move_speed < config.MOVEMENT.SPEEDMAX), rectAlignment="UpperCenter"}},
							{tag="Button", attributes={image="ui_minus", width=(40), height=(40), onClick="ui_move_slower", active=(move_speed > config.MOVEMENT.SPEEDMIN), rectAlignment="LowerCenter"}},
							{tag="Button", attributes={image="ui_block", color="#ff0000", width=(40), height=(40), onClick="ui_move_cancel", rectAlignment="MiddleLeft"}},
							{tag="Button", attributes={image="ui_check", color="#00ff00", width=(40), height=(40), onClick="ui_move_commit", rectAlignment="MiddleRight"}},
						}},
					}},
				}
			}
		elseif (config.MOVEMENT.MODE == 3) then --Complex Brackets
			local list = {}
			move_store_pos = {0,0,0}
			move_store_rot = 0
			local pos = {0,0,0}
			local rot = 0
			local displayPos = {0,0,0}

			for i,v in pairs(move_speed) do
				local dist = config.MOVEMENT.SEGMENTS[i][1]
				angle = 0
				if (v ~= 0) then
					angle = config.MOVEMENT.SEGMENTS[i][2][math.abs(v)]
					if (v < 0) then
						angle = angle * -1
					end
				end

				pos = rotateVector({pos[1], pos[2], pos[3]}, -rot)
				pos = rotateVector({pos[1], pos[2] + dist * 100, pos[3]}, rot)
				rot = rot + (angle)

				local tmp = {
					tag="Panel",
					attributes={color="transparent", rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position=table.concat(pos, " "), rotation="0 0 "..-rot},
					children={
						{tag="Image", attributes={color="#ffffff", image="movetool", width=(config.BASE_WIDTH * 25), height=(config.BASE_LENGTH * 25), rectAlignment="MiddleCenter"}},
						{tag="Button", attributes={image="ui_arrow_l", width=(20), height=(40), onClick="ui_move_dec("..i..")", active=(v > -#config.MOVEMENT.SEGMENTS[i][2]), rectAlignment="MiddleLeft"}},
						{tag="Button", attributes={image="ui_arrow_r", width=(20), height=(40), onClick="ui_move_inc("..i..")", active=(v < #config.MOVEMENT.SEGMENTS[i][2]), rectAlignment="MiddleRight"}},
					}
				}
				table.insert(list, tmp)
				move_store_pos = pos
				move_store_rot = rot
				displayPos = pos


			end

			local commitcolor = "00ff00"
			if ((config.MOVEMENT.LANDSHOW or true) and (config.MOVEMENT.LANDTEST or true)) then
				local tpos = self.getPosition()
				local trot = self.getRotation()
				local t = rotateVector(move_store_pos, trot[2])
				local cast = Physics.cast({
					origin = {x=tpos[1] + t[1] / 100, y=tpos[2], z=tpos[3] + t[2] / 100},
					direction = {0,1,0},
					max_distance = 0.5,
					type = 3,
					size = {config.BASE_WIDTH, 0.25, config.BASE_LENGTH},
					orientation = {0, trot[2] + move_store_rot, 0},
				})
				for i,col in pairs(cast) do
					if (col.hit_object ~= self) then
						commitcolor = "ff0000"
					end
				end
			end
			ui_movement = {
				tag="Panel", attributes={position="0 0 -"..(config.MOVEMENT.UIHEIGHT * 100), rectAlignment="MiddleCenter"}, children={

					{tag="panel", attributes={rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position=table.concat(displayPos, " "), rotation="0 0 "..-rot}, children={
						{tag="panel", attributes={color="#"..commitcolor.."44", active=(config.MOVEMENT.LANDSHOW), rectAlignment="MiddleCenter", position="0 0 "..(config.MOVEMENT.UIHEIGHT * 100 - 1)}},
					}},
					{tag="panel", attributes={width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position="0 0 0", rotation="0 0 0"}, children={
						{tag="panel", attributes={rectAlignment="LowerCenter", width="120", height="80", offsetXY="0 -80"}, children={
							{tag="Button", attributes={image="ui_plus", width=(40), height=(40), onClick="ui_move_faster", active=(#move_speed < config.MOVEMENT.SPEEDMAX), rectAlignment="UpperCenter"}},
							{tag="Button", attributes={image="ui_minus", width=(40), height=(40), onClick="ui_move_slower", active=(#move_speed > 1), rectAlignment="LowerCenter"}},
							{tag="Button", attributes={image="ui_block", color="#ff0000", width=(40), height=(40), onClick="ui_move_cancel", rectAlignment="MiddleLeft"}},
							{tag="Button", attributes={image="ui_check", color="#00ff00", width=(40), height=(40), onClick="ui_move_commit", rectAlignment="MiddleRight"}},
						}},
					}},
					table.unpack(list)
				}
			}
		elseif (config.MOVEMENT.MODE == 4) then
			local list = {}

			for i,def in pairs(config.MOVEMENT.DEFINITIONS) do
				table.insert(list, {
					tag="Button",
					attributes={
						rectAlignment="UpperCenter",
						offsetXY = (def[3]*40).." "..(def[4]*40),
						image=assetBuffer[def[2]],
						color=def[8],
						width=40,
						height=40,
						onClick="ui_move_select("..i..")"
					}
				})
			end

			local commitcolor = "00ff00"
			local tmp = {tag="panel", attributes={color="#"..commitcolor.."44", active=(config.MOVEMENT.LANDSHOW), rectAlignment="MiddleCenter", position="0 0 "..(config.MOVEMENT.UIHEIGHT * 100 - 1)}}
			local mrk = {tag="Image", attributes={color="#ffffff", image="movetool", width=(config.BASE_WIDTH * 25), height=(config.BASE_LENGTH * 25), rectAlignment="MiddleCenter"}}
			if (move_speed ~= 0) then
				local curDef = config.MOVEMENT.DEFINITIONS[move_speed]

				if ((config.MOVEMENT.LANDSHOW or true) and (config.MOVEMENT.LANDTEST or true)) then
					local tpos = self.getPosition()
					local trot = self.getRotation()
					local t = rotateVector({curDef[5], curDef[6], 0}, trot[2])
					local cast = Physics.cast({
						origin = {x=tpos[1] + t[1], y=tpos[2], z=tpos[3] + t[2]},
						direction = {0,1,0},
						max_distance = 0.5,
						type = 3,
						size = {config.BASE_WIDTH, 0.25, config.BASE_LENGTH},
						orientation = {0, trot[2] + curDef[7], 0},
					})
					for i,col in pairs(cast) do
						if (col.hit_object ~= self) then
							commitcolor = "ff0000"
						end
					end
				end

				tmp = {tag="panel", attributes={color="#"..commitcolor.."44", active=(config.MOVEMENT.LANDSHOW), rectAlignment="MiddleCenter", position=(curDef[5]*100).." "..(curDef[6]*100).." "..(config.MOVEMENT.UIHEIGHT * 100 - 1), rotation="0 0 "..-curDef[7]}}
				mrk = {tag="Image", attributes={color="#ffffff", image="movetool", width=(config.BASE_WIDTH * 25), height=(config.BASE_LENGTH * 25), position=(curDef[5]*100).." "..(curDef[6]*100).." 0", rectAlignment="MiddleCenter", rotation="0 0 "..-curDef[7]}}
			end

			ui_movement = {
				tag="Panel", attributes={position="0 0 -"..(config.MOVEMENT.UIHEIGHT * 100), rectAlignment="MiddleCenter"}, children={
					{tag="panel", attributes={rectAlignment="MiddleCenter", width=(config.BASE_WIDTH * 100), height=(config.BASE_LENGTH * 100), position="0 0 0", rotation="0 0 0"}, children={
						{tag="panel", attributes={rectAlignment="LowerCenter", width="80", height="40", offsetXY="0 -40"}, children={
							{tag="Button", attributes={image="ui_block", color="#ff0000", width=(40), height=(40), onClick="ui_move_cancel", rectAlignment="MiddleLeft"}},
							{tag="Button", attributes={image="ui_check", color="#00ff00", width=(40), height=(40), onClick="ui_move_commit", rectAlignment="MiddleRight"}},
						}},
						{tag="Panel", attributes={rectAlignment="LowerCenter", width="0", height="0", color="red", offsetXY = "0 -40"}, children=list},
						tmp,
						mrk
					}},
				}
			}
		end
	end
    self.UI.setXmlTable({ui_main, ui_settings, ui_movement})
end