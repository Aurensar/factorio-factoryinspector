local logger = require "script.logger"

local function getAggregateConsumption(item, timePeriodInSeconds)
    if not timePeriodInSeconds then timePeriodInSeconds = 60 end
    local startTick = game.tick - (timePeriodInSeconds * 60) 
    local resultsToReturn = {}

    for recipe, resultsDB in pairs(global.results[item].consumed) do
        if #resultsDB > 0 then
            resultsToReturn[recipe] = { times = 0, amount = 0}
            for i = #resultsDB, 1, -1 do
                if resultsDB[i].tick > startTick then
                    resultsToReturn[recipe].times = resultsToReturn[recipe].times + resultsDB[i].times
                    resultsToReturn[recipe].amount = resultsToReturn[recipe].amount + resultsDB[i].amount
                end
            end
            resultsToReturn[recipe].per_sec = resultsToReturn[recipe].amount / timePeriodInSeconds
            resultsToReturn[recipe].per_min = resultsToReturn[recipe].per_sec * 60
        end
    end

    return resultsToReturn
end

local function getAggregateProduction(item, timePeriodInSeconds)
    if not timePeriodInSeconds then timePeriodInSeconds = 60 end
    local startTick = game.tick - (timePeriodInSeconds * 60) 
    local resultsToReturn = {}

    for recipe, resultsDB in pairs(global.results[item].produced) do
        if #resultsDB > 0 then
            resultsToReturn[recipe] = { times = 0, amount = 0}
            for i = #resultsDB, 1, -1 do
                if resultsDB[i].tick > startTick then
                    resultsToReturn[recipe].times = resultsToReturn[recipe].times + resultsDB[i].times
                    resultsToReturn[recipe].amount = resultsToReturn[recipe].amount + resultsDB[i].amount
                end
            end
            resultsToReturn[recipe].per_sec = resultsToReturn[recipe].amount / timePeriodInSeconds
            resultsToReturn[recipe].per_min = resultsToReturn[recipe].per_sec * 60
        end
    end

    return resultsToReturn
end

local function getOrderedItemList()
    local resultsToReturn = {}
    for item, _ in pairs(global.results) do
        table.insert(resultsToReturn, item)
    end
    return resultsToReturn
end

local function addConsumptionData(item, recipe, times, amount)
    table.insert(global.results[item].consumed[recipe], { tick = game.tick, times = times, amount = amount })
    table.insert(global.results[item].consumed.total, { tick = game.tick, times = times, amount = amount })
    if #global.results[item].consumed.total % 1000 == 0 then
        -- local r = getAggregateConsumption(item, 60)
        -- logger.log(string.format("Results collection for %s now contains %d items", item, #global.results[item].consumed.total))
        -- logger.log(string.format("Production stats for %s: times crafted %d, amount %d, per sec %.2f, per min %.2f", item, r.total.times, r.total.amount, r.total.per_sec, r.total.per_min))
    end
end

local function addProductionData(item, recipe, times, amount)
    table.insert(global.results[item].produced[recipe], { tick = game.tick, times = times, amount = amount })
    table.insert(global.results[item].produced.total, { tick = game.tick, times = times, amount = amount })
end

return {
    addConsumptionData = addConsumptionData,
    addProductionData = addProductionData,
    getAggregateConsumption = getAggregateConsumption,
    getAggregateProduction = getAggregateProduction,
    getOrderedItemList = getOrderedItemList
}