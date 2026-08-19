TrappedStashes = TrappedStashes or {}
TrappedStashes.GameOver = TrappedStashes.GameOver or {}

local GameOver = TrappedStashes.GameOver
local Debug = TrappedStashes.Debug

function GameOver.Trigger(reason)
    if type(reason) ~= "string" or reason == "" then
        Debug.Log("ERROR gameover invalid-reason")
        return nil, "invalid reason"
    end

    if type(wh) ~= "table" or type(wh.playermodule) ~= "table" or
            type(wh.playermodule.GameOver) ~= "function" then
        Debug.Log("ERROR gameover unavailable reason=" .. tostring(reason))
        return nil, "LuaUtils GameOver unavailable"
    end

    local ok, resultOrError, extra = pcall(wh.playermodule.GameOver, reason)
    if not ok then
        Debug.Log("ERROR gameover exception reason=" .. tostring(reason) ..
            " error=" .. tostring(resultOrError))
        return nil, resultOrError
    end

    if resultOrError then
        Debug.Log("gameover-triggered reason=" .. tostring(reason))
        return resultOrError, extra
    end

    Debug.Log("ERROR gameover failed reason=" .. tostring(reason) ..
        " error=" .. tostring(extra))
    return resultOrError, extra
end
