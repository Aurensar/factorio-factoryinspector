local logger = require "script.logger"

local function init()
    -- Reset the UI for all players
    global.players = {}

    -- Reset the tracked entities
    global.entity_count = 0
    global.entities = {}
    global.entities[1] = {}
    global.entities_am = {}
    global.entities_am[1] = {}
    global.entities_md = {}
    global.entities_md[1] = {}
    global.entities_furnace = {}
    global.entities_furnace[1] = {}

    -- Reset the partition lookup tables
    global.entities_partition_lookup = {}
    global.entities_am_partition_lookup = {}
    global.entities_md_partition_lookup = {}
    global.entities_furnace_partition_lookup = {}

    -- Reset the tracked production/consumption calculations
    global.consumers = {}
    global.producers = {}

    -- Reset the production and consumption stats
    global.results = {}

    -- Load standard partition configuration
    -- TODO make partitioning/performance management configurable
    global.global_partition_data = { current = 1, size = 0, max_size = 5}
    global.am_partition_data = { current = 1, size = 0, max_size = 10}
    global.md_partition_data = { current = 1, size = 0, max_size = 20}
    global.furnace_partition_data = { current = 1, size = 0, max_size = 10}

    -- destroy old GUI
    for i, player in pairs(game.players) do
        for j, ui in pairs(player.gui.screen.children) do
            if ui.name == "fi_frame_main_dialog" then
                ui.destroy()
            end
        end
    end
end

local function onInit()
    logger.log2("OnInit detected - resetting all results, configuration and tracked entities")
    init()
end

local function onConfigChanged()
    logger.log2("Config change detected - resetting all results, configuration and tracked entities")
    init()
end

return {
    onInit = onInit,
    onConfigChanged = onConfigChanged
}