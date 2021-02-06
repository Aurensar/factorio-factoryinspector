local input_output_calculator = require "script.input-output-calculator"
local recipe_functions = require "script.recipe"
local logger = require "script.logger"

local partition_being_checked = 1

local update_timer = 0

local function updateConsumersAndProducers(entity)
    global.consumers[entity.unit_number] = {}
    global.producers[entity.unit_number] = {}

    local recipe = recipe_functions.getRecipe(entity)
    -- consumption
    if recipe then input_output_calculator.enrolConsumedRecipeIngredients(entity, recipe) end
    if entity.type == "mining-drill" then input_output_calculator.enrolConsumedMiningFluid(entity) end
    input_output_calculator.enrolConsumedSolidFuel(entity, recipe)
    input_output_calculator.enrolConsumedFluidFuel(entity, recipe)

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
        logger.log(string.format("Recipe change: Old recipe %s", global.entities[entity.unit_number].recipe))
    else
        logger.log(string.format("Recipe change: Old recipe not set"))
    end
    logger.log(string.format("Recipe change: New recipe %s", recipeName))
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

    local i = 0
    for number, data in pairs(global.entities[partition_being_checked]) do
        checkExistingEntityForChanges(data.entity, partition_being_checked)
        i = i + 1
    end

    partition_being_checked = partition_being_checked + 1
    if partition_being_checked > global.global_partition_data.current then
        partition_being_checked = 1
        --logger.log(string.format("Finished checking all %d partitions in %d ticks", global.global_partition_data.current, (game.tick - update_timer)))
        update_timer = game.tick
    end
end

local function removeEntity(entity)
    global.entities[global.entities_partition_lookup[entity.unit_number]][entity.unit_number] = nil
    logger.log("Entity removed "..entity.unit_number)

    if entity.type == "assembling-machine" then
        global.entities_am[global.entities_am_partition_lookup[entity.unit_number]][entity.unit_number] = nil
    end
    if entity.type == "mining-drill" then
        global.entities_md[global.entities_md_partition_lookup[entity.unit_number]][entity.unit_number] = nil
    end
    if entity.type == "furnace" then
        global.entities_furnace[global.entities_furnace_partition_lookup[entity.unit_number]][entity.unit_number] = nil
    end

    global.consumers[entity.unit_number] = {}
    global.producers[entity.unit_number] = {}
end

return {
    checkEntityBatchForRecipeChanges = checkEntityBatchForRecipeChanges,
    enrolNewEntity = enrolNewEntity,
    removeEntity = removeEntity
}