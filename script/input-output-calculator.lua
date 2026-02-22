local function initResults(item, recipe)
    if not storage.results[item] then storage.results[item] = {} end
    if not storage.results[item].consumed then storage.results[item].consumed = {} end
    if not storage.results[item].consumed[recipe] then storage.results[item].consumed[recipe] = {} end
    if not storage.results[item].consumed.total then storage.results[item].consumed.total = {} end

    if not storage.results[item].produced then storage.results[item].produced = {} end
    if not storage.results[item].produced[recipe] then storage.results[item].produced[recipe] = {} end
    if not storage.results[item].produced.total then storage.results[item].produced.total = {} end
end

local function addFakeRecipeLookup(fakeRecipe, prototype, prototypeType, formatString)
    if not storage.fakeRecipeLookup then storage.fakeRecipeLookup = {} end
    if storage.fakeRecipeLookup[fakeRecipe] then return end
    storage.fakeRecipeLookup[fakeRecipe] = { prototype=prototype, prototypeType=prototypeType, formatString=formatString}
end

local function enrolConsumedRecipeIngredients(entity, recipe, quality)
    for i, ingredient in ipairs(recipe.ingredients) do
          local ingredient_quality = ingredient.type == "fluid" and "normal" or quality
          table.insert(storage.consumers[entity.unit_number], {entity=entity, item=ingredient.name, amount=ingredient.amount, recipe=recipe.name, quality=ingredient_quality})
          initResults(ingredient.name, recipe.name)
          addFakeRecipeLookup(recipe.name, recipe.name, "recipe", "recipe-display.ingredient")
    end
end

local function enrolConsumedMiningFluid(entity)
    if entity.type == "mining-drill" and entity.mining_target and entity.mining_target.valid and entity.mining_target.prototype.mineable_properties.required_fluid then
        local per_craft = entity.mining_target.prototype.mineable_properties.fluid_amount / 10
        local recipe_name = "Mining fluid for ".. entity.mining_target.prototype.name
        table.insert(storage.consumers[entity.unit_number], {entity=entity, item=entity.mining_target.prototype.mineable_properties.required_fluid, amount=per_craft, recipe=recipe_name, quality="normal"})
        initResults(entity.mining_target.prototype.mineable_properties.required_fluid, recipe_name)
        addFakeRecipeLookup(recipe_name, entity.mining_target.prototype.name, "resource", "recipe-display.mining-fluid")
    end
end

local function enrolConsumedSolidFuel(entity, recipe, quality)
    if entity.burner and entity.burner.currently_burning then
        local burning = entity.burner.currently_burning
        local fuel_name = burning.name
        local fuel_quality = burning.quality or "normal"
        local fuel_value = burning.fuel_value
        if not fuel_value then
            local proto = prototypes.item[fuel_name]
            if not proto then return end
            fuel_value = proto.fuel_value
        end
        local entity_power_use = entity.prototype.energy_usage * 60

        local recipeName, time_in_seconds
        if recipe then
            time_in_seconds = recipe.energy -- multiplied by building speed?
            recipeName = recipe.name.." solid fuel"
            addFakeRecipeLookup(recipeName, recipe.name, "recipe", "recipe-display.solid-fuel")
        elseif entity.type == "mining-drill" then
            if not entity.mining_target or not entity.mining_target.valid then return end
            time_in_seconds = entity.mining_target.prototype.mineable_properties.mining_time / entity.prototype.mining_speed
            recipeName = "Mine "..entity.mining_target.prototype.name.. "solid fuel"
            addFakeRecipeLookup(recipeName, entity.mining_target.prototype.name, "resource", "recipe-display.mining-solid-fuel")
        else
            -- no recipe, and not a miner - not something we want to track
            return
        end

        local per_craft = entity_power_use / fuel_value * time_in_seconds
        table.insert(storage.consumers[entity.unit_number], {entity=entity, item=fuel_name, amount=per_craft, recipe=recipeName, quality=fuel_quality})
        initResults(fuel_name, recipeName)
    end
end

local function enrolConsumedFluidFuel(entity, recipe)
    if entity.prototype.fluid_energy_source_prototype and entity.prototype.fluid_energy_source_prototype.burns_fluid then
        local fuel
        for i=1, #entity.fluidbox do
            if entity.fluidbox[i] then
                local fluid_is_ingredient, fluid_is_product = false, false
                for j, ingredient in ipairs(recipe.ingredients) do
                    if ingredient.name == entity.fluidbox[i].name then fluid_is_ingredient = true end
                end
                for k, product in ipairs(recipe.products) do
                    if product.name == entity.fluidbox[i].name then fluid_is_product = true end
                end
                if not fluid_is_product and not fluid_is_ingredient then
                    fuel = entity.fluidbox[i].name
                end
            end
        end

        if fuel then
            local entity_power_use = entity.prototype.energy_usage * 60
            local item_power_value = prototypes.fluid[fuel].fuel_value
            local per_craft = entity_power_use / item_power_value * recipe.energy
            table.insert(storage.consumers[entity.unit_number], {entity=entity, item=fuel, amount=per_craft, recipe=recipe.name.." fluid fuel", quality="normal"})
            initResults(fuel, recipe.name.." fluid fuel")
            addFakeRecipeLookup(recipe.name.." fluid fuel", recipe.name, "recipe", "recipe-display.fluid-fuel")
        end
    end
end


local function enrolProducedMiningOutputs(entity, recipe)
    if entity.type == "mining-drill" and entity.mining_target and entity.mining_target.valid then
        local per_craft = 1

        for i, product in ipairs(entity.mining_target.prototype.mineable_properties.products) do

            if not product.amount then
                product.amount = product.amount_min + ((product.amount_max - product.amount_min) / 2)
            end

            local recipeName="mine-"..entity.mining_target.prototype.name
            table.insert(storage.producers[entity.unit_number], {entity=entity, item=product.name, amount=product.amount * product.probability, recipe=recipeName, quality="normal"})
            initResults(product.name, recipeName)
            addFakeRecipeLookup("mine-"..entity.mining_target.prototype.name, entity.mining_target.prototype.name, "resource", "recipe-display.mining")
        end
    end
end


local function enrolProducedRecipeOutputs(entity, recipe, quality)
    for i, product in ipairs(recipe.products) do
        local amount
        if product.amount then amount = product.amount * product.probability
        else amount = (product.amount_min + product.amount_max) / 2 * product.probability end

        local product_quality = product.type == "fluid" and "normal" or quality
        table.insert(storage.producers[entity.unit_number], {entity=entity, item=product.name, amount=amount, recipe=recipe.name, quality=product_quality})
        initResults(product.name, recipe.name)
        addFakeRecipeLookup(recipe.name, recipe.name, "recipe", "recipe-display.ingredient")
  end
end


local function buildForceLabCache(force)
    local labs = {}
    local total_speed = 0
    local max_partition = storage.lab_partition_data and storage.lab_partition_data.current or 1
    for partition = 1, max_partition do
        for unit_number, data in pairs(storage.entities_lab[partition] or {}) do
            if data.entity.valid and data.entity.force.index == force.index then
                local speed = 1 + data.entity.speed_bonus
                total_speed = total_speed + speed
                table.insert(labs, {
                    unit_number = unit_number,
                    surface_index = data.entity.surface_index,
                    speed = speed,
                    productivity_bonus = data.entity.productivity_bonus
                })
            end
        end
    end
    for _, lab in ipairs(labs) do
        lab.speed_fraction = total_speed > 0 and (lab.speed / total_speed) or 0
    end
    storage.force_lab_cache[force.index] = { total_speed = total_speed, labs = labs }
end

local function addResearchFakeRecipeLookup(tech)
    local recipe_name = "research-"..tech.name
    addFakeRecipeLookup(recipe_name, tech.name, "technology", "recipe-display.research")
    for _, ingredient in ipairs(tech.research_unit_ingredients) do
        initResults(ingredient.name, recipe_name)
    end
    return recipe_name
end

return {
    enrolConsumedRecipeIngredients = enrolConsumedRecipeIngredients,
    enrolConsumedMiningFluid = enrolConsumedMiningFluid,
    enrolConsumedSolidFuel = enrolConsumedSolidFuel,
    enrolConsumedFluidFuel = enrolConsumedFluidFuel,
    enrolProducedMiningOutputs = enrolProducedMiningOutputs,
    enrolProducedRecipeOutputs = enrolProducedRecipeOutputs,
    buildForceLabCache = buildForceLabCache,
    addResearchFakeRecipeLookup = addResearchFakeRecipeLookup
  }
