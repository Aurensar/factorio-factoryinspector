local function getRecipe(entity)
    if entity.type == "mining-drill" then return nil end
    local recipe = entity.get_recipe()
    if not recipe and entity.type == "furnace" and entity.previous_recipe then
        recipe = prototypes.recipe[entity.previous_recipe.name]
    end
    return recipe
end

local function getRecipeName(entity)
    if entity.type == "mining-drill" then
        if entity.mining_target then return "Mine "..entity.mining_target.prototype.name end
        return ""
    end
    local recipe = entity.get_recipe()
    if recipe then return recipe.name end
    if entity.type == "furnace" and entity.previous_recipe then return entity.previous_recipe.name end
    return ""
end

return {
    getRecipe = getRecipe,
    getRecipeName = getRecipeName
}


