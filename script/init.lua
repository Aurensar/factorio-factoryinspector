local logger = require "script.logger"

local function init()
    -- Reset the UI for all players
    storage.players = {}

    -- Reset the tracked entities
    storage.entity_count = 0
    storage.entities = {}
    storage.entities[1] = {}
    storage.entities_am = {}
    storage.entities_am[1] = {}
    storage.entities_md = {}
    storage.entities_md[1] = {}
    storage.entities_furnace = {}
    storage.entities_furnace[1] = {}
    storage.entities_lab = {}
    storage.entities_lab[1] = {}

    -- Reset the partition lookup tables
    storage.entities_partition_lookup = {}
    storage.entities_am_partition_lookup = {}
    storage.entities_md_partition_lookup = {}
    storage.entities_furnace_partition_lookup = {}
    storage.entities_lab_partition_lookup = {}

    -- Reset the tracked production/consumption calculations
    storage.consumers = {}
    storage.producers = {}

    -- Reset the production and consumption stats
    storage.results = {}

    -- Reset verification state
    storage.verification_snapshot = nil

    -- Load standard partition configuration
    -- TODO make partitioning/performance management configurable
    storage.global_partition_data = { current = 1, size = 0, max_size = 5}
    storage.am_partition_data = { current = 1, size = 0, max_size = 10}
    storage.md_partition_data = { current = 1, size = 0, max_size = 20}
    storage.furnace_partition_data = { current = 1, size = 0, max_size = 10}
    storage.lab_partition_data = { current = 1, size = 0, max_size = 10}

    -- Force-level research tracking
    storage.force_research_state = {}
    storage.force_lab_cache = {}

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