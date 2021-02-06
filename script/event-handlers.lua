local logger = require "script.logger"
local entity_tracker = require "script.entity-tracker"
local production_tracker = require "script.production-tracker"

local function onBuiltEntity(event)
    logger.log("Entity created"..event.created_entity.unit_number)
    entity_tracker.enrolNewEntity(event.created_entity)
end

local function onRemovedEntity(event)
    entity_tracker.removeEntity(event.entity)
end

local function onGameTick(event)
    --[[
        This mod is computationally intensive. Every tick, it needs to:
        - check if any entity has changed recipe (due to lack of an on recipe changed event)
        - check if any entity has produced something, and update internal recordkeeping

        Updating 1000+ assembling machines per tick is not feasible, so the approach taken is to update a batch of
        X entities per tick to spread the processing load.
        Higher batch size = higher processing load (TODO: Make batch size configurable)
        
        Global entity collection (governs recipe changes) = low batch size (it doesn't really matter if the mod fails to detect a recipe change for 10-20s)

        Assembling machine and furnace results recording (medium batch size) - 
            AMs have products_finished so it doesn't matter if we "miss" a craft, but if it takes 10s+ to analyse the entire factory, the mod loses accuracy

        Mining drills results recording (large batch size)
            Mining drills don't have products_finished so mining drills that cycle very fast will cause the mod to "miss" crafts
            We really need to get through all of the base's mining drills every second (60 ticks)
            It's likely that even this won't be enough for modded games or games with very fast mining speed 
    ]]
    entity_tracker.checkEntityBatchForRecipeChanges()
    
    production_tracker.updateProductionAndConsumptionStatsAM()
    production_tracker.updateProductionAndConsumptionStatsFurnace()
    production_tracker.updateProductionAndConsumptionStatsMD()

    if game.tick % 60 == 0 then
        for playerIndex, data in pairs(global.players) do
            if data.ui and data.ui.mainFrame and data.ui.mainFrame.visible then
                local player = game.get_player(playerIndex)
                productionTables.refresh(player)
            end
        end
    end
end

local function onGuiClick(event)
    if string.find(event.element.name, "fi_title_bar_close_interface") then
        local player = game.get_player(event.player_index)
        fiMainFrame.toggle(player)
    end
    if not string.find(event.element.name, "fi_item_button_") then return end
    local player = game.get_player(event.player_index)
    local ui_state = ui.ui_state(player)
    local item = string.gsub(event.element.name, "fi_item_button_", "")
    ui_state.selected_item = item
    itemList.refresh(player)
    productionTables.refresh(player)
end

local function onGuiTextChanged(event)
    if not string.find(event.element.name, "fi_textbox_search_items") then return end
    local player = game.get_player(event.player_index)
    local ui_state = ui.ui_state(player)
    ui_state.item_filter = event.text
    itemList.refresh(player)
end

local function onLuaShortcut(event)
    if event.prototype_name == "fi_open_interface" then
        local player = game.get_player(event.player_index)
        fiMainFrame.toggle(player)
    end
end

return {
    onGameTick = onGameTick,
    onBuiltEntity = onBuiltEntity,
    onRemovedEntity = onRemovedEntity,
    onGuiClick = onGuiClick,
    onGuiTextChanged = onGuiTextChanged,
    onLuaShortcut = onLuaShortcut
  }  