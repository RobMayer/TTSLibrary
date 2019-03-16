API = function(baseUrl, defParameters)

    local _base = baseUrl or ""
    local _defparam = defParameters or {}

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
            jRes = JSON.decode(response.text)
            if (jRes.errors ~= nil) then
                return _onfailure(jRes.errors)
            end
            return _onsuccess(jRes.result or jRes or {})
        end

		this["param"] = function(key, value)
            _params[key] = value
            return this
		end
        this["resolve"] = function(callback)
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
        this["dispatch"] = function()
            if (_mode == "get") then
                for k,v in pairs(_defparam) do
                    _params[k] = v
                end
                local to = _base .. _url .. "?" .. querify(_params)
                WebRequest.get(to, _keep)
            elseif (_mode == "post") then
                for k,v in pairs(_defparam) do
                    _params[k] = v
                end
                local to = _base .. _url .. "?" .. querify(_params)
                WebRequest.post(to, _body, _keep)
            end
            return this
        end
        return this
    end


    local sys = {}
    sys["get"] = function(url, params)
        return promise("get", url, params or {})
    end
    sys["post"] = function(url, body, params)
        return promise("post", url, params or {}, body or {})
    end
    sys["base"] = function(url)
        _base = url
        return sys
    end
    sys["defparam"] = function(key, value)
        _defparam[key] = value
        return sys
    end
    return sys
end

--[[
    local MyApi = API("http://api.yoursite.com/")
    local request = MyApi.get("some/endpoint").resolve(function(result) log(res) end)

    request.dispatch()
    request.dispatch()

    local MyOtherApi = API("http://api.somesite.com/").get("endpoint").resolve(log).dispatch()
]]