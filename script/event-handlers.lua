local logger = require "script.logger"
local entity_tracker = require "script.entity-tracker"
local production_tracker = require "script.production-tracker"
local results = require "script.results"

local function onBuiltEntity(event)
    local entity
    if event.created_entity and event.created_entity.valid then
        entity = event.created_entity
    elseif event.entity and event.entity.valid then
        entity = event.entity
    end
    logger.log2("Entity created: "..entity.unit_number)
    entity_tracker.enrolNewEntity(entity)
end

local function onRemovedEntity(event)
    entity_tracker.removeEntity(event.entity)
end

local function onGameTick(event)
    --[[
        This mod is computationally intensive. Every tick, it needs to:
        - check if any entity has changed activity, including but not limited to: had its recipe changed, switched to a different fuel, run out of minable resources, etc.
        - check if any entity has produced something, and update internal records.

        Updating 1000+ assembling machines per tick is too expensive, so the approach taken is to update a batch of
        X entities per tick to spread the processing load.
        Higher batch size = higher processing load (TODO: Make batch size configurable)
        
        Global entity collection (governs activity changes) = low batch size (it doesn't really matter if the mod fails to detect an activity change for 10-20s)

        Assembling machine and furnace results recording (medium batch size) - 
            AMs have products_finished so it doesn't matter if we "miss" a craft, but if it takes 10s+ to analyse the entire factory, the mod loses accuracy and becomes less useful.

        Mining drills results recording (large batch size)
            Mining drills don't have products_finished so mining drills that cycle very fast will cause the mod to "miss" crafts
            We really need to get through all of the base's mining drills every second (60 ticks)
            It's likely that even this won't be enough for modded games or games with very fast mining speed. 
            To be clear: the mod will not accurately track produced or consumed resources from mining drills if the mining cycle time is less than 0.5 seconds.

        To add a final layer of computational expense, the mod also needs to periodically check for new entities being added that did not fire an onBuiltEntity event.
        This typically happens when other mods create entities via script.
        Some common mods do not fire https://lua-api.factorio.com/latest/events.html#script_raised_built which would prevent the need for this additional check.
    ]]
    entity_tracker.checkEntityBatchForRecipeChanges()
    if game.tick % 3600 == 0 then
        entity_tracker.checkMissingEntities()
    end
    
    production_tracker.updateProductionAndConsumptionStatsAM()
    production_tracker.updateProductionAndConsumptionStatsFurnace()
    production_tracker.updateProductionAndConsumptionStatsMD()

    if game.tick % 60 == 0 then
        for playerIndex, data in pairs(global.players) do
            if data.ui and data.ui.mainFrame and data.ui.mainFrame.visible then
                local player = game.get_player(playerIndex)
                productionTables.refresh(player)
                itemList.refresh(player)
            end
        end
    end

    if game.tick % 3600 == 0 then
        results.cleanupOldResults()
    end

    if game.tick % 300 == 0 then
        results.flushBuffers()
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

    if tonumber(event.text) then
        local number = tonumber(event.text)
        if not global.entities_partition_lookup[number] then return end
        local partition = global.entities_partition_lookup[number]
        local entity = global.entities[partition][number]
        logger.log2(string.format("DEBUG ENTITY %d Found entity in partition %d",number, partition))
        logger.log2(string.format("DEBUG ENTITY %d Recipe is %s",number, entity.recipe))

        for i, consumer in ipairs(global.consumers[number]) do
            logger.log2(string.format("DEBUG ENTITY %d Consumes %d: item=%s amount=%.1f recipe=%s",number, i, consumer.item, consumer.amount, consumer.recipe))
        end
        for i, producer in ipairs(global.producers[number]) do
            logger.log2(string.format("DEBUG ENTITY %d Produces %d: item=%s amount=%.1f recipe=%s",number, i, producer.item, producer.amount, producer.recipe))
        end
        return
    end

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