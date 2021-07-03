
local function log(string)
    if __DebugAdapter then
        __DebugAdapter.print("[FI] "..string)
    end
end

local function log2(string)
    if __DebugAdapter then
        __DebugAdapter.print("[FI] "..string)
    end
    --game.print("[FI] "..string)
end

local function error(string)
    if __DebugAdapter then
        __DebugAdapter.print("[FI Error] "..string)
    end
    game.print("[FI Error] "..string)
end



return {
    log = log,
    log2 = log2
  }  