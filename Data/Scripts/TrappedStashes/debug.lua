TrappedStashes = TrappedStashes or {}
TrappedStashes.Debug = TrappedStashes.Debug or {}

local Debug = TrappedStashes.Debug
local PREFIX = "[TrappedStashes]"

function Debug.Enabled()
    local config = TrappedStashes.Config or {}
    return config.debug ~= false
end

function Debug.Log(message)
    System.LogAlways(PREFIX .. " " .. tostring(message))
end

function Debug.Trace(message)
    if Debug.Enabled() then
        Debug.Log(message)
    end
end

function Debug.Handle(value)
    if value == nil then return "nil" end
    if type(value) ~= "table" then return tostring(value) end

    local rttrName = rawget(value, "__rttr_name")
    local cppName = rawget(value, "__cpp_name")
    local handle = rawget(value, "__rttr_handle")

    if rttrName ~= nil then
        return tostring(rttrName) .. "#" .. tostring(handle)
    end
    if cppName ~= nil then
        return tostring(cppName) .. "#" .. tostring(handle)
    end

    return tostring(value)
end

local function sortedKeys(value, maxKeys)
    local keys = {}

    if type(value) ~= "table" then return keys end

    for key in pairs(value) do
        keys[#keys + 1] = key
        if #keys >= maxKeys then
            break
        end
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function dumpValue(label, value, depth, maxKeys, maxLines, lines, seen)
    if #lines >= maxLines then return end

    local valueType = type(value)
    if valueType ~= "table" or depth <= 0 then
        lines[#lines + 1] = label .. " = " .. tostring(value) ..
            " type=" .. valueType
        return
    end

    if seen[value] then
        lines[#lines + 1] = label .. " = <cycle>"
        return
    end
    seen[value] = true

    lines[#lines + 1] = label .. " = " .. Debug.Handle(value) ..
        " type=table"

    for _, key in ipairs(sortedKeys(value, maxKeys)) do
        local ok, child = pcall(function()
            return value[key]
        end)

        if ok then
            dumpValue(label .. "." .. tostring(key), child, depth - 1,
                maxKeys, maxLines, lines, seen)
        else
            lines[#lines + 1] = label .. "." .. tostring(key) ..
                " = <read-error:" .. tostring(child) .. ">"
        end

        if #lines >= maxLines then
            break
        end
    end
end

function Debug.DumpBounded(label, value, depth, maxKeys, maxLines)
    depth = tonumber(depth) or 2
    maxKeys = tonumber(maxKeys) or 16
    maxLines = tonumber(maxLines) or 80

    local lines = {}
    dumpValue(label, value, depth, maxKeys, maxLines, lines, {})

    for _, line in ipairs(lines) do
        Debug.Log(line)
    end

    if #lines >= maxLines then
        Debug.Log(label .. " dump-truncated maxLines=" .. tostring(maxLines))
    end
end
