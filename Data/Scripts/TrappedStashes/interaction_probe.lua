TrappedStashes = TrappedStashes or {}
TrappedStashes.InteractionProbe = TrappedStashes.InteractionProbe or {}

local Probe = TrappedStashes.InteractionProbe
local Debug = TrappedStashes.Debug

Probe._nodes = Probe._nodes or {}
Probe._connections = Probe._connections or {}
Probe._holders = Probe._holders or {}
Probe._eventCount = tonumber(Probe._eventCount) or 0

local function cfg()
    return (TrappedStashes.Config and TrappedStashes.Config.diagnostics) or {}
end

local function requireSkald()
    if type(wh) ~= "table" or type(wh.entitymodule) ~= "table" then
        Debug.Log("ERROR interaction-probe wh.entitymodule unavailable")
        return false
    end

    if type(Skald) ~= "table" or type(SKALD) ~= "table" then
        Debug.Log("ERROR interaction-probe SKALD helpers unavailable")
        return false
    end

    return true
end

local function bindTrigger(node, outputName, callback)
    local ok, connectionOrError, err = pcall(function()
        return node:BindOutput(outputName, callback)
    end)

    if not ok then
        err = connectionOrError
        connectionOrError = nil
    end

    if connectionOrError == nil then
        Debug.Log("ERROR interaction-probe bind-failed output=" ..
            tostring(outputName) .. " error=" .. tostring(err))
        return nil
    end

    Probe._connections[#Probe._connections + 1] = connectionOrError
    return connectionOrError
end

local function bindData(node, outputName)
    local ok, holderOrError, err = pcall(function()
        return node:BindOutput(outputName)
    end)

    if not ok then
        err = holderOrError
        holderOrError = nil
    end

    if holderOrError == nil then
        Debug.Log("ERROR interaction-probe data-bind-failed output=" ..
            tostring(outputName) .. " error=" .. tostring(err))
        return nil
    end

    Probe._holders[#Probe._holders + 1] = holderOrError
    return holderOrError
end

local function createNode()
    local classTable = wh.entitymodule and wh.entitymodule.InteractionTriggerNode
    if type(classTable) ~= "table" or type(classTable.Create) ~= "function" then
        Debug.Log("ERROR interaction-probe missing InteractionTriggerNode class")
        return nil
    end

    local ok, nodeOrError, err = pcall(function()
        return classTable.Create({
            IsActive = true,
        })
    end)

    if not ok then
        err = nodeOrError
        nodeOrError = nil
    end

    if nodeOrError == nil then
        Debug.Log("ERROR interaction-probe create-failed error=" ..
            tostring(err))
        return nil
    end

    Probe._nodes[#Probe._nodes + 1] = nodeOrError
    return nodeOrError
end

local function activateNode(node)
    local okCall, ok, err = pcall(function()
        return node:Activate()
    end)

    if not okCall then
        err = ok
        ok = nil
    end

    if ok then
        Debug.Log("interaction-probe activated config=broad IsActive=true")
        return true
    end

    Debug.Log("ERROR interaction-probe activate-failed error=" .. tostring(err))
    return false
end

local function safeCall(object, methodName)
    if type(object) ~= "table" then return nil, "not-table" end

    local okMethod, method = pcall(function()
        return object[methodName]
    end)
    if not okMethod then return nil, method end
    if type(method) ~= "function" then return nil, "missing-method" end

    local ok, valueOrError = pcall(method, object)
    if ok then return valueOrError, nil end
    return nil, valueOrError
end

local function safeField(object, fieldName)
    if type(object) ~= "table" then return nil end

    local ok, value = pcall(function()
        return object[fieldName]
    end)

    if ok then return value end
    return nil
end

local function valueText(value)
    if value == nil then return "nil" end
    if type(value) == "table" then return Debug.Handle(value) end
    return tostring(value)
end

local function dataHolderText(holder)
    if holder == nil then return "nil" end

    local ok, value = pcall(function()
        return holder.value
    end)

    if ok then
        return valueText(value), value
    end

    return "error:" .. tostring(value), nil
end

local function describeNodePort(node, methodName)
    local value, err = safeCall(node, methodName)
    if err ~= nil then
        return "error:" .. tostring(err), nil
    end
    return valueText(value), value
end

local function firstReadable(object, names)
    for _, name in ipairs(names) do
        local value = safeField(object, name)
        if value ~= nil then
            return value, "." .. name
        end

        value = safeCall(object, name)
        if value ~= nil then
            return value, ":" .. name .. "()"
        end
    end

    return nil, nil
end

local function logInteractorDetails(eventId, interactor)
    local idValue, idSource = firstReadable(interactor, {
        "id",
        "Id",
        "entityId",
        "EntityId",
        "cryEntityId",
        "CryEntityId",
        "GetId",
        "GetEntityId",
    })
    local nameValue, nameSource = firstReadable(interactor, {
        "name",
        "Name",
        "entityName",
        "EntityName",
        "GetName",
        "GetEntityName",
    })
    local classValue, classSource = firstReadable(interactor, {
        "class",
        "Class",
        "entityClass",
        "EntityClass",
        "GetClass",
        "GetEntityClass",
    })

    Debug.Log("interaction-probe interactor-summary event=" ..
        tostring(eventId) ..
        " handle=" .. Debug.Handle(interactor) ..
        " type=" .. type(interactor) ..
        " rttr=" .. tostring(type(interactor) == "table" and
            rawget(interactor, "__rttr_name") or nil) ..
        " cpp=" .. tostring(type(interactor) == "table" and
            rawget(interactor, "__cpp_name") or nil) ..
        " id=" .. tostring(idValue) ..
        " idSource=" .. tostring(idSource) ..
        " name=" .. tostring(nameValue) ..
        " nameSource=" .. tostring(nameSource) ..
        " class=" .. tostring(classValue) ..
        " classSource=" .. tostring(classSource))

    Debug.DumpBounded("interaction-probe.interactor[" .. tostring(eventId) ..
        "]", interactor, cfg().interactionDumpDepth,
        cfg().interactionDumpKeys, cfg().interactionDumpLines)
    Debug.DumpBounded("interaction-probe.interactorMeta[" ..
        tostring(eventId) .. "]", getmetatable(interactor),
        cfg().interactionDumpDepth, cfg().interactionDumpKeys,
        cfg().interactionDumpLines)
end

function Probe.Reset(reason)
    for _, connection in ipairs(Probe._connections or {}) do
        if connection and type(connection.Disconnect) == "function" then
            pcall(connection.Disconnect, connection)
        end
    end

    for _, holder in ipairs(Probe._holders or {}) do
        if holder and type(holder.Release) == "function" then
            pcall(holder.Release, holder)
        end
    end

    for _, node in ipairs(Probe._nodes or {}) do
        if node then
            if type(node.Deactivate) == "function" then
                pcall(node.Deactivate, node)
            end
            if type(node.Destroy) == "function" then
                pcall(node.Destroy, node)
            elseif type(node.Release) == "function" then
                pcall(node.Release, node)
            end
        end
    end

    Probe._nodes = {}
    Probe._connections = {}
    Probe._holders = {}
    Debug.Trace("interaction-probe reset reason=" .. tostring(reason))
end

function Probe.Register()
    if cfg().interactionProbe ~= true then
        Debug.Trace("interaction-probe disabled")
        return false
    end
    if not requireSkald() then
        return false
    end

    local node = createNode()
    if not node then return false end

    local interactorHolder = bindData(node, "Interactor")
    bindTrigger(node, "OnInteraction", function(...)
        Probe._eventCount = Probe._eventCount + 1
        local eventId = Probe._eventCount
        local holderText, interactor = dataHolderText(interactorHolder)
        local typeText, typePort = describeNodePort(node, "Type")
        local interactorsText, interactorsPort =
            describeNodePort(node, "Interactors")

        Debug.Log("interaction-probe event=" .. tostring(eventId) ..
            " args=" .. tostring(select("#", ...)) ..
            " holder=" .. tostring(holderText) ..
            " nodeType=" .. tostring(typeText) ..
            " nodeInteractors=" .. tostring(interactorsText))

        logInteractorDetails(eventId, interactor)
        Debug.DumpBounded("interaction-probe.type[" .. tostring(eventId) ..
            "]", typePort, cfg().interactionDumpDepth,
            cfg().interactionDumpKeys, cfg().interactionDumpLines)
        Debug.DumpBounded("interaction-probe.interactors[" ..
            tostring(eventId) .. "]", interactorsPort,
            cfg().interactionDumpDepth, cfg().interactionDumpKeys,
            cfg().interactionDumpLines)
    end)

    if not activateNode(node) then
        return false
    end

    Debug.Log("interaction-probe-bound outputs=OnInteraction,Interactor")
    return true
end
