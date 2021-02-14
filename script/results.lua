local logger = require "script.logger"

local productionBuffer = {}
local consumptionBuffer = {}

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
    --table.insert(global.results[item].consumed[recipe], { tick = game.tick, times = times, amount = amount })
    --table.insert(global.results[item].consumed.total, { tick = game.tick, times = times, amount = amount })

    if not consumptionBuffer[item] then consumptionBuffer[item] = {} end
    if not consumptionBuffer[item][recipe] then consumptionBuffer[item][recipe] = {} end
    if not consumptionBuffer[item].total then consumptionBuffer[item].total = {} end
    table.insert(consumptionBuffer[item][recipe], { tick = game.tick, times = times, amount = amount })
    table.insert(consumptionBuffer[item].total, { tick = game.tick, times = times, amount = amount })
end

local function addProductionData(item, recipe, times, amount)
    --table.insert(global.results[item].produced[recipe], { tick = game.tick, times = times, amount = amount })
    --table.insert(global.results[item].produced.total, { tick = game.tick, times = times, amount = amount })

    if not productionBuffer[item] then productionBuffer[item] = {} end
    if not productionBuffer[item][recipe] then productionBuffer[item][recipe] = {} end
    if not productionBuffer[item].total then productionBuffer[item].total = {} end
    table.insert(productionBuffer[item][recipe], { tick = game.tick, times = times, amount = amount })
    table.insert(productionBuffer[item].total, { tick = game.tick, times = times, amount = amount })
end

local function flushBuffer(buffer, getTargetDB)
    local recordsInBuffer, recordsCreated = 0, 0
    for item, itemDB in pairs(buffer) do
        for recipe, recipeDB in pairs (itemDB) do
            local consolidatedRecord = { times = 0, amount = 0}
            for i, record in ipairs(recipeDB) do
                consolidatedRecord.times = consolidatedRecord.times + record.times
                consolidatedRecord.amount = consolidatedRecord.amount + record.amount
                recordsInBuffer = recordsInBuffer + 1
            end
            recordsCreated = recordsCreated + 1
            table.insert(getTargetDB(item, recipe), { tick = game.tick, times = consolidatedRecord.times, amount = consolidatedRecord.amount })
        end
    end
    return recordsInBuffer, recordsCreated
end

local function flushBuffers()
   local total, created = flushBuffer(consumptionBuffer, function(item, recipe) return global.results[item].consumed[recipe] end)
   logger.log(string.format("Flushed consumption buffer of %d items, creating %d records", total, created))
   total, created = flushBuffer(productionBuffer, function(item, recipe) return global.results[item].produced[recipe] end)
   logger.log(string.format("Flushed production buffer of %d items, creating %d records", total, created))
   productionBuffer = {}
   consumptionBuffer = {}
end

local function cleanupOldResults(timeInSeconds)
    if not timeInSeconds then timeInSeconds = 300 end
    local cleanupThresholdTick = game.tick - (timeInSeconds * 60) 
    local recordsCleaned, prodRecords, consRecords = 0, 0, 0

    for item, itemDB in pairs(global.results) do
        for recipe, recipeDB in pairs(itemDB.produced) do
            for i, entry in ipairs(recipeDB) do
                prodRecords = prodRecords + 1
                if entry.tick < cleanupThresholdTick then 
                    table.remove(recipeDB, i)
                    recordsCleaned = recordsCleaned + 1
                end
            end
        end
        for recipe, recipeDB in pairs(itemDB.consumed) do
            for i, entry in ipairs(recipeDB) do
                consRecords = consRecords + 1
                if entry.tick < cleanupThresholdTick then 
                    table.remove(recipeDB, i)
                    recordsCleaned = recordsCleaned + 1
                end
            end
        end
    end

    logger.log2("Cleaned up "..recordsCleaned.." records")
    logger.log2(string.format("Database status: %d production records, %d consumption records, %d total records", prodRecords, consRecords, (prodRecords + consRecords)))
end

return {
    addConsumptionData = addConsumptionData,
    addProductionData = addProductionData,
    getAggregateConsumption = getAggregateConsumption,
    getAggregateProduction = getAggregateProduction,
    getOrderedItemList = getOrderedItemList,
    cleanupOldResults = cleanupOldResults,
    flushBuffers = flushBuffers
}