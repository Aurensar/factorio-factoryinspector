local logger = require "script.logger"

local productionBuffer = {}
local consumptionBuffer = {}

local function getAggregateConsumption(item, timePeriodInSeconds)
    if not timePeriodInSeconds then timePeriodInSeconds = 60 end
    local startTick = game.tick - (timePeriodInSeconds * 60)
    local entries = {}
    local total = { times = 0, amount = 0 }
    local grouped = {}

    for recipe, resultsDB in pairs(storage.results[item].consumed) do
        if recipe ~= "total" and #resultsDB > 0 then
            for i = #resultsDB, 1, -1 do
                if resultsDB[i].tick > startTick then
                    local si = resultsDB[i].surface_index or 0
                    local q = resultsDB[i].quality or "normal"
                    local key = recipe .. "\0" .. si .. "\0" .. q
                    if not grouped[key] then grouped[key] = { recipe = recipe, surface_index = si, quality = q, times = 0, amount = 0 } end
                    grouped[key].times = grouped[key].times + resultsDB[i].times
                    grouped[key].amount = grouped[key].amount + resultsDB[i].amount
                end
            end
        end
    end

    for _, entry in pairs(grouped) do
        entry.per_sec = entry.amount / timePeriodInSeconds
        entry.per_min = entry.per_sec * 60
        total.times = total.times + entry.times
        total.amount = total.amount + entry.amount
        table.insert(entries, entry)
    end

    if total.amount == 0 then return nil end
    total.per_sec = total.amount / timePeriodInSeconds
    total.per_min = total.per_sec * 60

    return { entries = entries, total = total }
end

local function getAggregateProduction(item, timePeriodInSeconds)
    if not timePeriodInSeconds then timePeriodInSeconds = 60 end
    local startTick = game.tick - (timePeriodInSeconds * 60)
    local entries = {}
    local total = { times = 0, amount = 0 }
    local grouped = {}

    for recipe, resultsDB in pairs(storage.results[item].produced) do
        if recipe ~= "total" and #resultsDB > 0 then
            for i = #resultsDB, 1, -1 do
                if resultsDB[i].tick > startTick then
                    local si = resultsDB[i].surface_index or 0
                    local q = resultsDB[i].quality or "normal"
                    local key = recipe .. "\0" .. si .. "\0" .. q
                    if not grouped[key] then grouped[key] = { recipe = recipe, surface_index = si, quality = q, times = 0, amount = 0 } end
                    grouped[key].times = grouped[key].times + resultsDB[i].times
                    grouped[key].amount = grouped[key].amount + resultsDB[i].amount
                end
            end
        end
    end

    for _, entry in pairs(grouped) do
        entry.per_sec = entry.amount / timePeriodInSeconds
        entry.per_min = entry.per_sec * 60
        total.times = total.times + entry.times
        total.amount = total.amount + entry.amount
        table.insert(entries, entry)
    end

    if total.amount == 0 then return nil end
    total.per_sec = total.amount / timePeriodInSeconds
    total.per_min = total.per_sec * 60

    return { entries = entries, total = total }
end

local function getOrderedItemList()
    local resultsToReturn = {}
    for item, _ in pairs(storage.results) do
        table.insert(resultsToReturn, item)
    end
    table.sort(resultsToReturn)
    return resultsToReturn
end

local function addConsumptionData(item, recipe, times, amount, surface_index, quality)
    quality = quality or "normal"
    if not consumptionBuffer[item] then consumptionBuffer[item] = {} end
    if not consumptionBuffer[item][recipe] then consumptionBuffer[item][recipe] = {} end
    if not consumptionBuffer[item].total then consumptionBuffer[item].total = {} end
    table.insert(consumptionBuffer[item][recipe], { tick = game.tick, times = times, amount = amount, surface_index = surface_index, quality = quality })
    table.insert(consumptionBuffer[item].total, { tick = game.tick, times = times, amount = amount, surface_index = surface_index, quality = quality })
end

local function addProductionData(item, recipe, times, amount, surface_index, quality)
    quality = quality or "normal"
    if not productionBuffer[item] then productionBuffer[item] = {} end
    if not productionBuffer[item][recipe] then productionBuffer[item][recipe] = {} end
    if not productionBuffer[item].total then productionBuffer[item].total = {} end
    table.insert(productionBuffer[item][recipe], { tick = game.tick, times = times, amount = amount, surface_index = surface_index, quality = quality })
    table.insert(productionBuffer[item].total, { tick = game.tick, times = times, amount = amount, surface_index = surface_index, quality = quality })
end

local function flushBuffer(buffer, getTargetDB)
    local recordsInBuffer, recordsCreated = 0, 0
    for item, itemDB in pairs(buffer) do
        for recipe, recipeDB in pairs(itemDB) do
            -- Group records by (surface_index, quality) before consolidating
            local byKey = {}
            for i, record in ipairs(recipeDB) do
                local si = record.surface_index
                local q = record.quality or "normal"
                local key = si .. "\0" .. q
                if not byKey[key] then byKey[key] = { times = 0, amount = 0, surface_index = si, quality = q } end
                byKey[key].times = byKey[key].times + record.times
                byKey[key].amount = byKey[key].amount + record.amount
                recordsInBuffer = recordsInBuffer + 1
            end
            local targetDB = getTargetDB(item, recipe)
            for _, consolidated in pairs(byKey) do
                recordsCreated = recordsCreated + 1
                table.insert(targetDB, { tick = game.tick, times = consolidated.times, amount = consolidated.amount, surface_index = consolidated.surface_index, quality = consolidated.quality })
            end
        end
    end
    return recordsInBuffer, recordsCreated
end

local function flushBuffers()
   local total, created = flushBuffer(consumptionBuffer, function(item, recipe) return storage.results[item].consumed[recipe] end)
   logger.log(string.format("Flushed consumption buffer of %d items, creating %d records", total, created))
   total, created = flushBuffer(productionBuffer, function(item, recipe) return storage.results[item].produced[recipe] end)
   logger.log(string.format("Flushed production buffer of %d items, creating %d records", total, created))
   productionBuffer = {}
   consumptionBuffer = {}
end

local function cleanupOldResults(timeInSeconds)
    if not timeInSeconds then timeInSeconds = 300 end
    local cleanupThresholdTick = game.tick - (timeInSeconds * 60) 
    local recordsCleaned, prodRecords, consRecords = 0, 0, 0

    for item, itemDB in pairs(storage.results) do
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

    logger.log("Cleaned up "..recordsCleaned.." records")
    logger.log(string.format("Database status: %d production records, %d consumption records, %d total records", prodRecords, consRecords, (prodRecords + consRecords)))
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