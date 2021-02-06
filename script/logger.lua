
local function log(string)
    if __DebugAdapter then
        __DebugAdapter.print(string)
    end
    --game.write_file("factoryinfo.log", string.."\n", true)
end

local function log2(string)
    if __DebugAdapter then
        __DebugAdapter.print(string)
    end
    game.print(string)
    --game.write_file("factoryinfo.log", string.."\n", true)
end


return {
    log = log,
    log2 = log2
  }  