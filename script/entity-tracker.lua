local input_output_calculator = require "script.input-output-calculator"
local recipe_functions = require "script.recipe"
local logger = require "script.logger"

local partition_being_checked = 1

local update_timer = 0


-- Bypasses the partition lookup table and scans the whole database for an id. Shouldn't be needed...
local function deepRemoveEntity(number_to_delete, inner_database)
    local count, am_count, furnace_count, md_count = 0, 0, 0, 0

    for partition,data in pairs(global.entities) do
        for unit_number, innerData in pairs(data) do
            if unit_number == number_to_delete then
                logger.log("[Deep scan] Found entity to remove in global partition "..partition)
                count = count + 1
                global.entities[partition][unit_number] = nil
            end
        end
    end

    for partition,data in pairs(global.entities_am) do
        for unit_number, innerData in pairs(data) do
            if unit_number == number_to_delete then
                logger.log("[Deep scan] Found entity to remove in AM partition "..partition)
                am_count = am_count + 1
                global.entities_am[partition][unit_number] = nil
            end
        end
    end

    for partition,data in pairs(global.entities_md) do
        for unit_number, innerData in pairs(data) do
            if unit_number == number_to_delete then
                logger.log("[Deep scan] Found entity to remove in MD partition "..partition)
                md_count = md_count + 1
                global.entities_md[partition][unit_number] = nil
            end
        end
    end

    for partition,data in pairs(global.entities_furnace) do
        for unit_number, innerData in pairs(data) do
            if unit_number == number_to_delete then
                logger.log("[Deep scan] Found entity to remove in F partition "..partition)
                furnace_count = furnace_count + 1
                global.entities_furnace[partition][unit_number] = nil
            end
        end
    end

    logger.log(string.format("[Deep Remove %d] Occurrences: G=%d AM=%d MD=%d F=%d", number_to_delete, count, am_count, md_count, furnace_count))

    if count > 1 or am_count > 1 or md_count > 1 or furnace_count > 1 then
        logger.error(string.format("[Deep Remove %d] Occurrences: G=%d AM=%d MD=%d F=%d", number_to_delete, count, am_count, md_count, furnace_count))
    end
end

local function removeEntityByNumber(number)
    logger.log("Starting to remove entity "..number)
    local partition = global.entities_partition_lookup[number]

    if not partition then
        logger.error("Unit "..number.." not found in entity tracker. Please report this error to the mod author.")
        deepRemoveEntity(number)
        return
    end

    logger.log("Found entity to remove in global partition "..partition)
    global.entities[partition][number] = nil
    global.entities_partition_lookup[number] = nil

    if global.entities_am_partition_lookup[number] then
        partition = global.entities_am_partition_lookup[number]
        logger.log("Found entity to remove in assembling machine partition "..partition)
        global.entities_am[partition][number] = nil
        global.entities_am_partition_lookup[number] = nil
    end
    if global.entities_md_partition_lookup[number] then
        partition = global.entities_md_partition_lookup[number]
        logger.log("Found entity to remove in mining drill partition "..partition)
        global.entities_md[partition][number] = nil
        global.entities_md_partition_lookup[number] = nil
    end
    if global.entities_furnace_partition_lookup[number] then
        partition = global.entities_furnace_partition_lookup[number]
        logger.log("Found entity to remove in furnace partition "..partition)
        global.entities_furnace[partition][number] = nil
        global.entities_furnace_partition_lookup[number] = nil
    end

    global.consumers[number] = {}
    global.producers[number] = {}
    logger.log("Entity removed "..number)
end


local function removeEntity(entity)
    removeEntityByNumber(entity.unit_number)
end

local function updateConsumersAndProducers(entity)
    global.consumers[entity.unit_number] = {}
    global.producers[entity.unit_number] = {}

    local recipe = recipe_functions.getRecipe(entity)
    -- consumption
    if recipe then 
        input_output_calculator.enrolConsumedRecipeIngredients(entity, recipe) 
        input_output_calculator.enrolConsumedSolidFuel(entity, recipe)
        input_output_calculator.enrolConsumedFluidFuel(entity, recipe)
        end
    if entity.type == "mining-drill" then input_output_calculator.enrolConsumedMiningFluid(entity) end

    -- production
    if entity.type == "mining-drill" then input_output_calculator.enrolProducedMiningOutputs(entity) end
    if recipe then input_output_calculator.enrolProducedRecipeOutputs(entity, recipe) end

    -- for i, consumer in ipairs(global.consumers[entity.unit_number]) do
    --      logger.log(string.format("Entity %d %s uses %.2f %s per craft on recipe %s",
    --                          entity.unit_number, entity.name, consumer.amount, consumer.item, consumer.recipe))
    -- end
end

local function addEntityToPartition(database, partition_data, entity, cache, entityDataToSave)
    if not database[partition_data.current] then database[partition_data.current] = {} end
    database[partition_data.current][entity.unit_number] = entityDataToSave(entity)
    cache[entity.unit_number] = partition_data.current
    partition_data.size = partition_data.size + 1
    -- logger.log(string.format("Registering new entity %d %s in partition %d, %d in partition so far",
    --             entity.unit_number, entity.name, partition_data.current, partition_data.size))

    if partition_data.size >= partition_data.max_size then
        partition_data.current = partition_data.current + 1
        database[partition_data.current] = {}
        partition_data.size = 0
        -- logger.log(string.format("Starting new partition %d", partition_data.current))
    end
end

local function checkExistingEntityForChanges(entity, partition)
    local recipeName = recipe_functions.getRecipeName(entity)
    if global.entities[partition][entity.unit_number].recipe == recipeName then return end

    logger.log(string.format("Recipe change for %d %s", entity.unit_number, entity.name))
    if global.entities[entity.unit_number] then
        logger.log(string.format("Recipe change: Old recipe [%s]", global.entities[entity.unit_number].recipe))
    else
        logger.log(string.format("Recipe change: Old recipe not set"))
    end
    logger.log(string.format("Recipe change: New recipe [%s]", recipeName))
    updateConsumersAndProducers(entity)
    global.entities[partition][entity.unit_number].recipe = recipeName
end

local function enrolNewEntity(entity)
    updateConsumersAndProducers(entity)
    addEntityToPartition(global.entities, global.global_partition_data, entity, global.entities_partition_lookup, function(e) return { entity=e, recipe=recipe_functions.getRecipeName(e)} end)
    if entity.type == "assembling-machine" then
        addEntityToPartition(global.entities_am, global.am_partition_data, entity, global.entities_am_partition_lookup, function(e) return { entity=e } end)
    end
    if entity.type == "mining-drill" then
        addEntityToPartition(global.entities_md, global.md_partition_data, entity, global.entities_md_partition_lookup, function(e) return { entity=e } end)
    end
    if entity.type == "furnace" then
        addEntityToPartition(global.entities_furnace, global.furnace_partition_data, entity, global.entities_furnace_partition_lookup, function(e) return { entity=e } end)
    end
end

local function checkEntityBatchForRecipeChanges()
    if global.entity_count == 0 then
        local am_count, md_count, furnace_count = 0, 0, 0
        logger.log("Re-enrolling all entities - full scan")
        for _, surface in pairs(game.surfaces) do
            local entities =  surface.find_entities_filtered({type = {"furnace", "assembling-machine", "mining-drill"}})
            for i, entity in ipairs(entities) do
                enrolNewEntity(entity)
                if entity.type == "assembling-machine" then am_count = am_count + 1 end
                if entity.type == "mining-drill" then md_count = md_count + 1 end
                if entity.type == "furnace" then furnace_count = furnace_count + 1 end
                global.entity_count = global.entity_count + 1
            end
            logger.log(string.format("Finished initialisation for %d entities (%d assemblers %d mining drills %d furnaces)", #entities, am_count, md_count, furnace_count))
        end
    end

    for number, data in pairs(global.entities[partition_being_checked]) do
        if not data.entity.valid then 
            removeEntityByNumber(number)
        else 
            checkExistingEntityForChanges(data.entity, partition_being_checked) 
        end
    end

    partition_being_checked = partition_being_checked + 1
    if partition_being_checked > global.global_partition_data.current then
        partition_being_checked = 1
        --logger.log(string.format("Finished checking all %d partitions in %d ticks", global.global_partition_data.current, (game.tick - update_timer)))
        update_timer = game.tick
    end
end

local function checkMissingEntities()
    logger.log(string.format("Checking all surfaces for missing entities"))
    for _, surface in pairs(game.surfaces) do
        local entities =  surface.find_entities_filtered({type = {"furnace", "assembling-machine", "mining-drill"}})
        for i, entity in ipairs(entities) do
            local partition = global.entities_partition_lookup[entity.unit_number]
            if not partition then
                logger.log(string.format(string.format("Entity %d %s added to database. This entity may have been created by a mod script.", entity.unit_number, entity.name)))
                enrolNewEntity(entity)
            end
        end
    end
end

return {
    checkEntityBatchForRecipeChanges = checkEntityBatchForRecipeChanges,
    enrolNewEntity = enrolNewEntity,
    removeEntity = removeEntity,
    checkMissingEntities = checkMissingEntities
}