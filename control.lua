local event_handlers = require "script.event-handlers"
local init = require "script.init"
require "ui.main"

script.on_init(init.onInit)
script.on_configuration_changed(init.onConfigChanged)
script.on_event(defines.events.on_tick, event_handlers.onGameTick)

script.on_event(defines.events.on_built_entity, event_handlers.onBuiltEntity,
  {{filter="type", type = "mining-drill"},
   {filter="type", type = "assembling-machine"}, 
   {filter="type", type = "furnace"}})
script.on_event(defines.events.on_robot_built_entity, event_handlers.onBuiltEntity,
   {{filter="type", type = "mining-drill"},
    {filter="type", type = "assembling-machine"}, 
    {filter="type", type = "furnace"}})
script.on_event(defines.events.script_raised_built, event_handlers.onBuiltEntity,
   {{filter="type", type = "mining-drill"},
    {filter="type", type = "assembling-machine"}, 
    {filter="type", type = "furnace"}})

script.on_event(defines.events.on_player_mined_entity, event_handlers.onRemovedEntity,
  {{filter="type", type = "mining-drill"},
   {filter="type", type = "assembling-machine"}, 
   {filter="type", type = "furnace"}})
script.on_event(defines.events.on_robot_mined_entity, event_handlers.onRemovedEntity,
   {{filter="type", type = "mining-drill"},
    {filter="type", type = "assembling-machine"}, 
    {filter="type", type = "furnace"}})
script.on_event(defines.events.script_raised_destroy, event_handlers.onRemovedEntity,
    {{filter="type", type = "mining-drill"},
     {filter="type", type = "assembling-machine"}, 
     {filter="type", type = "furnace"}})

script.on_event(defines.events.on_lua_shortcut, event_handlers.onLuaShortcut)
script.on_event(defines.events.on_gui_click, event_handlers.onGuiClick)
script.on_event(defines.events.on_gui_text_changed, event_handlers.onGuiTextChanged)
script.on_event(defines.events.on_gui_opened, event_handlers.onGuiOpened)
script.on_event(defines.events.on_gui_closed, event_handlers.onGuiClosed)
script.on_event(defines.events.on_runtime_mod_setting_changed, event_handlers.onRuntimeModSettingChanged)

local verification = require "script.verification"
commands.add_command("fi-verify-report", "Show the latest background verification report", function(command)
    local player = game.get_player(command.player_index)
    if player then verification.formatReport(player) end
end)
commands.add_command("fi-verify-now", "Force an immediate verification check", function(command)
    verification.runBackgroundCheck()
    local player = game.get_player(command.player_index)
    if player then verification.formatReport(player) end
end)