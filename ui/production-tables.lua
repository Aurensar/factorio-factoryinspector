local results = require "script.results"
local logger = require "script.logger"

productionTables = {}

function productionTables.create(player)
    local ui_state = ui.ui_state(player)

    ui_state.right_column.add{type="label", caption={"ui.production-stats"}, style="heading_3_label", ignored_by_interaction=true}

    local prod_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    prod_table_frame.style.vertically_stretchable = true

    ui_state.prod_table_holder = prod_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.prod_table_holder.style.horizontally_stretchable = true
    ui_state.prod_table_holder.style.vertically_stretchable = true    
    ui_state.prod_table_holder.style.padding = { 10,10 }

    ui_state.prod_table = ui_state.prod_table_holder.add { type = "table", column_count = 8, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.prod_table.style.horizontal_spacing = 16

    ui_state.right_column.add{type="label", caption={"ui.consumption-stats"}, style="heading_3_label", ignored_by_interaction=true}

    local cons_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    cons_table_frame.style.vertically_stretchable = true

    ui_state.cons_table_holder = cons_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.cons_table_holder.style.horizontally_stretchable = true
    ui_state.cons_table_holder.style.vertically_stretchable = true
    ui_state.cons_table_holder.style.padding = { 10,10 }

    ui_state.cons_table = ui_state.cons_table_holder.add { type = "table", column_count = 8, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.cons_table.style.horizontal_spacing = 16

    productionTables.refreshConsumption(player)
    productionTables.refreshProduction(player)
end

function productionTables.refresh(player)
    productionTables.refreshConsumption(player)
    productionTables.refreshProduction(player)
end

local function getDisplayNameAndSpriteForDynamicRecipe(dynamicRecipe)
    if not global.fakeRecipeLookup[dynamicRecipe] then
        logger.error("Lookup system can't find a match for dynamic recipe "..dynamicRecipe..", please report a bug")
        return "Unknown", "item/iron-plate"
    end

    local lookup = global.fakeRecipeLookup[dynamicRecipe]
    local prototypeName
    local sprite = "item/iron-plate"
    if lookup.prototypeType == "recipe" then 
        prototypeName = game.recipe_prototypes[lookup.prototype].localised_name 
        sprite = "recipe/"..lookup.prototype
    end
    if lookup.prototypeType == "resource" then 
        prototypeName = game.entity_prototypes[lookup.prototype].localised_name 
        sprite = "entity/"..lookup.prototype
    end
    return {lookup.formatString, prototypeName}, sprite
end

function productionTables.refreshConsumption(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.cons_table
    local selected_item = ui_state.selected_item
    table.clear()

    if not selected_item then
        return
    end

    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.recipe-name-internal"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.times-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    local results = results.getAggregateConsumption(selected_item, 120)
    if not results or not results.total then return end

    for recipe, data in pairs(results) do
        if recipe ~= "total" and data.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(recipe)
            table.add { type = "sprite", sprite = sprite }
            table.add { type = "label", caption = name, style="fi_table_text" }
            table.add { type = "label", caption = recipe, style="fi_table_text" }
            table.add { type = "label", caption = string.format("%d", data.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", data.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", data.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", data.per_min), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", (data.amount / results.total.amount * 100)), style="fi_table_number" }
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", results.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.per_min), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", 100), style="fi_table_number_heading" }
end

function productionTables.refreshProduction(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.prod_table
    local selected_item = ui_state.selected_item
    table.clear()

    if not selected_item then
        return
    end

    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.recipe-name-internal"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.times-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    local results = results.getAggregateProduction(selected_item, 120)
    if not results or not results.total then return end

    for recipe, data in pairs(results) do
        if recipe ~= "total" and data.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(recipe)
            table.add { type = "sprite", sprite = sprite }
            table.add { type = "label", caption = name, style="fi_table_text" }
            table.add { type = "label", caption = recipe, style="fi_table_text" }
            table.add { type = "label", caption = string.format("%d", data.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", data.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", data.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", data.per_min), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", (data.amount / results.total.amount * 100)), style="fi_table_number" }
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", results.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", results.total.per_min), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", 100), style="fi_table_number_heading" }
end
