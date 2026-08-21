TrappedStashes = TrappedStashes or {}
TrappedStashes.TrapImpact = TrappedStashes.TrapImpact or {}

local TrapImpact = TrappedStashes.TrapImpact
local Debug = TrappedStashes.Debug

local RAGDOLL_HOTKEY_BUFF_ID = "95d93a84-c2c3-46dc-aaec-2c69e9986d4b"
local AUTHORED_RAGDOLL_BUFF_ID = "15875b20-6a75-47e2-89fc-5c5f2173a4a8"
local BLOOD_SCREEN_BUFF_ID = "25bb8ae5-4b2a-4d82-aeef-0309d885f147"

local ACTION_CANDIDATES = {
    "PlayerAnimationAction",
    "utils.player.PlayerAnimationAction",
    "wh::playermodule::PlayerAnimationAction",
    "wh::animationmodule::PlayerAnimationAction",
    "wh::entitymodule::PlayerAnimationAction",
}

local TRIGGER_CANDIDATES = {
    "startanimation",
    "StartAnimation",
    "startAnimation",
    "Start",
}

local ALIGN_ARRAY_TYPES = {
    "wh::rpgmodule::Souls",
    "wh::xgenaimodule::LinkableObjects",
    "wh::xgenaimodule::SmartObjects",
    "wh::entitymodule::Entities",
    "wh::entitymodule::EntityIds",
}

local function log(message)
    if Debug and type(Debug.Log) == "function" then
        Debug.Log(message)
    elseif System and type(System.LogAlways) == "function" then
        System.LogAlways("[TrappedStashes] " .. tostring(message))
    end
end

local function trim(value)
    local text = tostring(value or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, '^"(.*)"$', "%1")
    text = string.gsub(text, "^'(.*)'$", "%1")
    return text
end

local function countTable(value)
    if type(value) ~= "table" then return 0 end

    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end

    return count
end

local function valueSummary(value)
    if type(value) ~= "table" then
        return tostring(value)
    end

    local parts = {}
    local limit = 0
    for key, child in pairs(value) do
        limit = limit + 1
        parts[#parts + 1] = tostring(key) .. "=" .. tostring(child)
        if limit >= 8 then
            parts[#parts + 1] = "..."
            break
        end
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

local function getPlayerSoul()
    local user = rawget(_G, "player")
    if type(user) == "table" and type(user.soul) == "table" then
        return user.soul
    end

    return nil
end

local function getPlayerEntity()
    local user = rawget(_G, "player")
    if type(user) == "table" then
        return user
    end

    return nil
end

local function alignValues()
    local values = {}
    local user = rawget(_G, "player")

    if type(user) == "table" then
        values[#values + 1] = { label = "player", value = user }
        if user.this ~= nil then
            values[#values + 1] = { label = "player.this", value = user.this }
        end
        if user.id ~= nil then
            values[#values + 1] = { label = "player.id", value = user.id }
        end
        if type(user.soul) == "table" then
            values[#values + 1] = { label = "player.soul", value = user.soul }
        end
    end

    values[#values + 1] = { label = "alias-player", value = "player" }
    return values
end

local function baseAnimationArgs(tags)
    return {
        fragment = "HitDeath",
        tags = tags,
        savelock = false,
        allowtorch = false,
        disablefocuscamera = true,
    }
end

local function animationArgVariants(tags)
    local variants = {}
    local entity = getPlayerEntity()

    local noAlign = baseAnimationArgs(tags)
    variants[#variants + 1] = {
        label = "no-align",
        args = noAlign,
    }

    if entity ~= nil then
        local scalar = baseAnimationArgs(tags)
        scalar.alignobject = entity
        variants[#variants + 1] = {
            label = "scalar-player",
            args = scalar,
        }
    end

    for _, alignValue in ipairs(alignValues()) do
        for _, arrayType in ipairs(ALIGN_ARRAY_TYPES) do
            local args = baseAnimationArgs(tags)
            args.alignobject = {
                __array_type = arrayType,
                alignValue.value,
            }
            variants[#variants + 1] = {
                label = alignValue.label .. ":" .. arrayType,
                args = args,
            }
        end
    end

    return variants
end

local function applyBuff(buffId)
    local soul = getPlayerSoul()
    if soul == nil or type(soul.AddBuff) ~= "function" then
        return false, "player-soul-addbuff-unavailable"
    end

    local ok, result = pcall(function()
        return soul:AddBuff(buffId)
    end)

    if not ok then
        return false, result
    end

    return true, result
end

local function probeFactory(factory)
    local native = rawget(_G, "SKALD")
    if type(native) ~= "table" or type(native.GetPortDefinitions) ~= "function" then
        log("impact-probe factory=" .. tostring(factory) ..
            " result=false error=SKALD.GetPortDefinitions-unavailable")
        return false
    end

    local ok, definitions = pcall(native.GetPortDefinitions, factory)
    if not ok then
        log("impact-probe factory=" .. tostring(factory) ..
            " result=false error=" .. tostring(definitions))
        return false
    end

    log("impact-probe factory=" .. tostring(factory) ..
        " result=true count=" .. tostring(countTable(definitions)) ..
        " ports=" .. valueSummary(definitions))
    return true
end

function TrapImpact.Reset(reason)
    log("impact reset reason=" .. tostring(reason or "unknown"))
end

function TrapImpact.Probe()
    log("impact-probe start")

    local supported = 0
    for _, factory in ipairs(ACTION_CANDIDATES) do
        if probeFactory(factory) then
            supported = supported + 1
        end
    end

    log("impact-probe done supported=" .. tostring(supported))
    return supported > 0
end

function TrapImpact.TestBuff(line)
    local buffId = trim(line)
    if buffId == "" or buffId == "buff" then
        buffId = RAGDOLL_HOTKEY_BUFF_ID
    end

    local ok, result = applyBuff(buffId)
    log("impact-test mode=buff buff=" .. tostring(buffId) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

function TrapImpact.TestAuthoredRagdoll()
    local ok, result = applyBuff(AUTHORED_RAGDOLL_BUFF_ID)
    log("ragdoll-authored buff=" .. tostring(AUTHORED_RAGDOLL_BUFF_ID) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

function TrapImpact.TestBloodScreen()
    local ok, result = applyBuff(BLOOD_SCREEN_BUFF_ID)
    log("blood-screen-test buff=" .. tostring(BLOOD_SCREEN_BUFF_ID) ..
        " attempted=true result=" .. tostring(ok) ..
        " detail=" .. tostring(result))
    return ok
end

local function tryRawAnimation(factory, tags)
    local native = rawget(_G, "SKALD")
    if type(native) ~= "table" or type(native.CreateNode) ~= "function" then
        return false, "SKALD.CreateNode-unavailable"
    end

    local lastDetail = "unattempted"

    for _, variant in ipairs(animationArgVariants(tags)) do
        local okCreate, skaldHandle, rttrOrError = pcall(
            native.CreateNode,
            factory,
            variant.args
        )
        if not okCreate then
            lastDetail = variant.label .. " create-error=" .. tostring(skaldHandle)
        elseif skaldHandle == nil then
            lastDetail = variant.label .. " create-failed=" .. tostring(rttrOrError)
        else
            local applyUpdates = Skald and Skald.__applyUpdates or nil
            for _, triggerName in ipairs(TRIGGER_CANDIDATES) do
                local okTrigger, updatesOrResult, errorOrNil = pcall(
                    native.TriggerInput,
                    skaldHandle,
                    triggerName
                )
                if okTrigger and updatesOrResult ~= nil then
                    if type(applyUpdates) == "function" then
                        pcall(applyUpdates, updatesOrResult)
                    end

                    if type(native.QueueDestroy) == "function" then
                        pcall(native.QueueDestroy, skaldHandle)
                    elseif type(native.DestroyNode) == "function" then
                        pcall(native.DestroyNode, skaldHandle)
                    end

                    return true, "factory=" .. tostring(factory) ..
                        " variant=" .. tostring(variant.label) ..
                        " trigger=" .. tostring(triggerName) ..
                        " result=" .. tostring(errorOrNil)
                elseif okTrigger then
                    lastDetail = variant.label .. " trigger=" ..
                        tostring(triggerName) .. " failed=" ..
                        tostring(errorOrNil or updatesOrResult)
                else
                    lastDetail = variant.label .. " trigger=" ..
                        tostring(triggerName) .. " error=" ..
                        tostring(updatesOrResult)
                end
            end

            if type(native.DestroyNode) == "function" then
                pcall(native.DestroyNode, skaldHandle)
            end
        end
    end

    return false, "factory=" .. tostring(factory) .. " " .. tostring(lastDetail)
end

function TrapImpact.TestDirect(line)
    local tags = trim(line)
    if tags == "" or tags == "direct" or tags == "skald" then
        tags = "so_back+minor_hit"
    end

    log("impact-test mode=direct tags=" .. tostring(tags) .. " attempted=true")

    for _, factory in ipairs(ACTION_CANDIDATES) do
        local ok, detail = tryRawAnimation(factory, tags)
        log("impact-test mode=direct factory=" .. tostring(factory) ..
            " result=" .. tostring(ok) .. " detail=" .. tostring(detail))
        if ok then
            return true
        end
    end

    return false
end

function TrapImpact.Test(line)
    local argument = trim(line)
    if argument == "" or argument == "buff" or
            string.sub(argument, 1, 4) == "95d9" then
        return TrapImpact.TestBuff(argument)
    end

    if argument == "direct" or argument == "skald" or
            string.find(argument, "hit", 1, true) ~= nil or
            string.find(argument, "ragdoll", 1, true) ~= nil or
            string.find(argument, "minor", 1, true) ~= nil or
            string.find(argument, "major", 1, true) ~= nil then
        return TrapImpact.TestDirect(argument)
    end

    log("impact-test mode=unknown argument=" .. tostring(argument) ..
        " result=false hint=use-buff-or-direct")
    return false
end
