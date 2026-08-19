local ok, err = pcall(function()
    Script.ReloadScript("Scripts/TrappedStashes/TrappedStashes.lua")
end)

local mod = rawget(_G, "TrappedStashes")

if not ok then
    System.LogAlways("[TrappedStashes] reload failed: " .. tostring(err))
elseif mod and type(mod.Bootstrap) == "function" then
    mod.Bootstrap()
else
    System.LogAlways("[TrappedStashes] bootstrap missing")
end

if mod and type(mod.BindLifecycleEvents) == "function" then
    mod.BindLifecycleEvents()
else
    System.LogAlways("[TrappedStashes] lifecycle binder missing")
end
