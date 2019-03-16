API = (function()

    local encode = function(str)
        str:gsub("([^A-Za-z0-9%_%.%-%~])", function(v)
    			return string.upper(string.format("%%%02x", string.byte(v)))
    	end)
        str:gsub('%%20', '+')
        return str
    end

    local querify = function(tab, sep, key)
        sep = sep or "&"
        local query = {}
    	local keys = {}
    	for k in pairs(tab) do
    		keys[#keys+1] = k
    	end
    	table.sort(keys)
    	for _,name in ipairs(keys) do
    		local value = tab[name]
    		name = encode(tostring(name))
    		if key then
    			name = string.format('%s[%s]', tostring(key), tostring(name))
    		end
    		if type(value) == 'table' then
    			query[#query+1] = querify(value, sep, name)
    		else
    			local value = encode(tostring(value))
    			if value ~= "" then
    				query[#query+1] = string.format('%s=%s', name, value)
    			else
    				query[#query+1] = name
    			end
    		end
    	end
    	return table.concat(query, sep)
    end


    local promise = function(mode, url, params, body)
        local _mode = mode
        local _url = url
        local _params = params or {}
        local _body = body or {}
        local _onsuccess = function(res) log(res) end
        local _onfailure = function(res) log(res) end
        local _onfault = function(res) log(res) end
        local this = {}

        local _keep = function(response)
            if (not response.is_done) then
                return _keep(response)
            end
            if (response.is_error) then
                return _onfault(response.error)
            end
            if (response.text.errors ~= nil) then
                return _onfailure(response.text.errors)
            end
            return _onsuccess(response.text.result or response.text or {})
        end

        this["try"] = function(callback)
            _onsuccess = callback
            return this
        end
        this["catch"] = function(callback)
            _onfailure = callback
            return this
        end
        this["fault"] = function(callback)
            _onfault = callback
            return this
        end
        this["resolve"] = function()
            if (_mode == "get") then
                local to = _url .. "?" .. querify(_params)
                WebRequest.get(to, _keep)
            elseif (_mode == "post") then
                local to = _url .. "?" .. querify(_params)
                WebRequest.post(to, _body, _keep)
            end
        end
        return this
    end

    local sys = {
        ["get"] = function(url, params)
            return promise("get", url, params or {})
        end,
        ["post"] = function(url, body, params)
            return promise("post", url, params or {}, body or {})
        end
    }
    return sys
end)()


--[[
	//Get
	API.get(url, {urlparams}).try(function(results) --will fire if it succeeds
		log(result) 
	end).catch(function(result) -- will fire if body result contains key "errors"
		log(result)
	end).fault(function(error) -- will fire if something went wrong in WebRequest
		log(error)
	end).resolve()
	
	//Post
	API.post(url, {body}, {urlparams}).try(function(results) --will fire if it succeeds
		log(result) 
	end).catch(function(result) -- will fire if body result contains key "errors"
		log(result)
	end).fault(function(error) -- will fire if something went wrong in WebRequest
		log(error)
	end).resolve()
	
]]