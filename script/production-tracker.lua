local logger = require "script.logger"
local results = require "script.results"

local current_am_partition = 1
local current_furnace_partition = 1

local am_start_tick = 1
local furnace_start_tick = 1

local function updateResults(item, recipe, amount, seconds, diff)
    storage.results[item].consumed[recipe].times = storage.results[item].consumed[recipe].times + diff
    storage.results[item].consumed[recipe].amount = storage.results[item].consumed[recipe].amount + (amount*diff)
    storage.results[item].consumed[recipe].amount_per_sec = storage.results[item].consumed[recipe].amount / seconds
    storage.results[item].consumed[recipe].amount_per_min = storage.results[item].consumed[recipe].amount_per_sec * 60

    storage.results[item].consumed.summary.times = storage.results[item].consumed.summary.times + diff
    storage.results[item].consumed.summary.amount = storage.results[item].consumed.summary.amount + (amount*diff)
    storage.results[item].consumed.summary.amount_per_sec = storage.results[item].consumed.summary.amount / seconds
    storage.results[item].consumed.summary.amount_per_min = storage.results[item].consumed.summary.amount_per_sec * 60
end

local function updateProductionAndConsumptionStatsAM()
    for unit_number, data in pairs(storage.entities_am[current_am_partition]) do
        if data.entity.valid and data.previous_count and data.entity.products_finished and data.entity.products_finished > data.previous_count then
            local diff = data.entity.products_finished - data.previous_count
            local surface_index = data.entity.surface_index
            local result_quality = data.entity.result_quality
            local production_quality = result_quality and result_quality.name or nil
            for i, producer in ipairs(storage.producers[unit_number] or {}) do
                results.addProductionData(producer.item, producer.recipe, diff, diff*producer.amount, surface_index, production_quality or producer.quality)
            end
            local consumption_diff = diff / (1 + data.entity.productivity_bonus)
            for j, consumer in ipairs(storage.consumers[unit_number] or {}) do
                results.addConsumptionData(consumer.item, consumer.recipe, consumption_diff, consumption_diff*consumer.amount, surface_index, consumer.quality)
            end
        end

        if not data.entity.valid then
            logger.error(string.format("Assembling machine (unit number %d) has become invalid. Please report this error to the mod author", unit_number))
        else
            data.previous_count = data.entity.products_finished
        end
    end

    current_am_partition = current_am_partition + 1
    if current_am_partition > storage.am_partition_data.current then
        current_am_partition = 1
        --logger.log(string.format("Finished updating %d assembling machine partitions in %d ticks", storage.am_partition_data.current, (game.tick - am_start_tick)))
        am_start_tick = game.tick
    end
end

local function updateProductionAndConsumptionStatsFurnace()
    for unit_number, data in pairs(storage.entities_furnace[current_furnace_partition]) do
        if data.entity.valid and data.previous_count and data.entity.products_finished and data.entity.products_finished > data.previous_count then
            local diff = data.entity.products_finished - data.previous_count
            local surface_index = data.entity.surface_index
            local result_quality = data.entity.result_quality
            local production_quality = result_quality and result_quality.name or nil
            for i, producer in ipairs(storage.producers[unit_number] or {}) do
                results.addProductionData(producer.item, producer.recipe, diff, diff*producer.amount, surface_index, production_quality or producer.quality)
            end
            local consumption_diff = diff / (1 + data.entity.productivity_bonus)
            for j, consumer in ipairs(storage.consumers[unit_number] or {}) do
                results.addConsumptionData(consumer.item, consumer.recipe, consumption_diff, consumption_diff*consumer.amount, surface_index, consumer.quality)
            end
        end
        if not data.entity.valid then
            logger.error(string.format("Furnace (unit number %d) has become invalid. Please report this error to the mod author", unit_number))
        else
            data.previous_count = data.entity.products_finished
        end
    end

    current_furnace_partition = current_furnace_partition + 1
    if current_furnace_partition > storage.furnace_partition_data.current then
        current_furnace_partition = 1
        furnace_start_tick = game.tick
    end
end

local function updateProductionAndConsumptionStatsMD()
    for partition = 1, storage.md_partition_data.current do
        for unit_number, data in pairs(storage.entities_md[partition]) do
            if data.entity.valid and data.previous_progress and data.entity.mining_progress and data.entity.mining_progress < data.previous_progress then
                local surface_index = data.entity.surface_index
                local productivity_multiplier = 1 + data.entity.productivity_bonus
                local mining_target = data.entity.mining_target
                local yield_multiplier = 1
                if mining_target and mining_target.valid and mining_target.prototype.infinite_resource then
                    yield_multiplier = mining_target.amount / mining_target.prototype.normal_resource_amount
                end
                for i, producer in ipairs(storage.producers[unit_number] or {}) do
                    results.addProductionData(producer.item, producer.recipe, 1, producer.amount * productivity_multiplier * yield_multiplier, surface_index, producer.quality)
                end
                for j, consumer in ipairs(storage.consumers[unit_number] or {}) do
                    results.addConsumptionData(consumer.item, consumer.recipe, 1, consumer.amount, surface_index, consumer.quality)
                end
            end
            if data.entity.valid then data.previous_progress = data.entity.mining_progress end
        end
    end
end

local function updateResearchConsumption()
    for force_index, state in pairs(storage.force_research_state) do
        local force = game.forces[force_index]
        if not force or not force.valid then
            storage.force_research_state[force_index] = nil
        else
            local tech = force.current_research
            if tech and state.tech_name == tech.name then
                local progress = force.research_progress
                if progress > state.previous_progress then
                    local delta = progress - state.previous_progress
                    local recipe_name = "research-"..tech.name
                    local unit_count = tech.research_unit_count
                    local cache = storage.force_lab_cache[force_index]
                    if cache and #cache.labs > 0 then
                        for _, lab_info in ipairs(cache.labs) do
                            local fractional_units = delta * unit_count * lab_info.speed_fraction
                            for _, ingredient in ipairs(tech.research_unit_ingredients) do
                                local amount = fractional_units * ingredient.amount / (1 + lab_info.productivity_bonus)
                                results.addConsumptionData(ingredient.name, recipe_name, fractional_units, amount, lab_info.surface_index, "normal")
                            end
                        end
                    end
                end
                state.previous_progress = force.research_progress
            end
        end
    end
end

return {
    updateProductionAndConsumptionStatsAM = updateProductionAndConsumptionStatsAM,
    updateProductionAndConsumptionStatsMD = updateProductionAndConsumptionStatsMD,
    updateProductionAndConsumptionStatsFurnace = updateProductionAndConsumptionStatsFurnace,
    updateResearchConsumption = updateResearchConsumption
}