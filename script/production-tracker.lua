local logger = require "script.logger"
local results = require "script.results"

local current_am_partition = 1
local current_furnace_partition = 1
local current_md_partition = 1

local am_start_tick = 1
local furnace_start_tick = 1
local md_start_tick = 1

local function updateResults(item, recipe, amount, seconds, diff)
    global.results[item].consumed[recipe].times = global.results[item].consumed[recipe].times + diff
    global.results[item].consumed[recipe].amount = global.results[item].consumed[recipe].amount + (amount*diff)
    global.results[item].consumed[recipe].amount_per_sec = global.results[item].consumed[recipe].amount / seconds
    global.results[item].consumed[recipe].amount_per_min = global.results[item].consumed[recipe].amount_per_sec * 60

    global.results[item].consumed.summary.times = global.results[item].consumed.summary.times + diff
    global.results[item].consumed.summary.amount = global.results[item].consumed.summary.amount + (amount*diff)
    global.results[item].consumed.summary.amount_per_sec = global.results[item].consumed.summary.amount / seconds
    global.results[item].consumed.summary.amount_per_min = global.results[item].consumed.summary.amount_per_sec * 60
end

local function updateProductionAndConsumptionStatsAM()
    for unit_number, data in pairs(global.entities_am[current_am_partition]) do
        if data.previous_count and data.entity.products_finished and data.entity.products_finished > data.previous_count then
            local diff = data.entity.products_finished - data.previous_count
            for i, producer in ipairs(global.producers[unit_number]) do
                results.addProductionData(producer.item, producer.recipe, diff, diff*producer.amount)
            end
            for j, consumer in ipairs(global.consumers[unit_number]) do
                results.addConsumptionData(consumer.item, consumer.recipe, diff, diff*consumer.amount)
            end
        end
        data.previous_count = data.entity.products_finished
    end

    current_am_partition = current_am_partition + 1
    if current_am_partition > global.am_partition_data.current then
        current_am_partition = 1
        logger.log(string.format("Finished updating %d assembling machine partitions in %d ticks", global.am_partition_data.current, (game.tick - am_start_tick)))
        am_start_tick = game.tick
    end
end

local function updateProductionAndConsumptionStatsFurnace()
    for unit_number, data in pairs(global.entities_furnace[current_furnace_partition]) do
        if data.previous_count and data.entity.products_finished and data.entity.products_finished > data.previous_count then
            local diff = data.entity.products_finished - data.previous_count
            for i, producer in ipairs(global.producers[unit_number]) do
                results.addProductionData(producer.item, producer.recipe, diff, diff*producer.amount)
            end
            for j, consumer in ipairs(global.consumers[unit_number]) do
                results.addConsumptionData(consumer.item, consumer.recipe, diff, diff*consumer.amount)
            end
        end
        data.previous_count = data.entity.products_finished
    end

    current_furnace_partition = current_furnace_partition + 1
    if current_furnace_partition > global.furnace_partition_data.current then
        current_furnace_partition = 1
        logger.log(string.format("Finished updating %d furnace partitions in %d ticks", global.furnace_partition_data.current, (game.tick - furnace_start_tick)))
        furnace_start_tick = game.tick
    end
end

local function updateProductionAndConsumptionStatsMD()
    for unit_number, data in pairs(global.entities_md[current_md_partition]) do
        if data.previous_progress and data.entity.mining_progress and data.entity.mining_progress < data.previous_progress then
            for i, producer in ipairs(global.producers[unit_number]) do
                results.addProductionData(producer.item, producer.recipe, 1, producer.amount)
            end
            for j, consumer in ipairs(global.consumers[unit_number]) do
                results.addConsumptionData(consumer.item, consumer.recipe, 1, consumer.amount)
            end
        end
        data.previous_progress = data.entity.mining_progress
    end

    current_md_partition = current_md_partition + 1
    if current_md_partition > global.md_partition_data.current then
        current_md_partition = 1
        logger.log(string.format("Finished updating %d mining drill partitions in %d ticks", global.md_partition_data.current, (game.tick - md_start_tick)))
        md_start_tick = game.tick
    end
end

return {
    updateProductionAndConsumptionStatsAM = updateProductionAndConsumptionStatsAM,
    updateProductionAndConsumptionStatsMD = updateProductionAndConsumptionStatsMD,
    updateProductionAndConsumptionStatsFurnace = updateProductionAndConsumptionStatsFurnace
}