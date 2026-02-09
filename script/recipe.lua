local function getRecipe(entity)
    if entity.type == "mining-drill" then return nil, "normal" end
    local recipe, qualityPrototype = entity.get_recipe()
    local quality = (qualityPrototype and qualityPrototype.name) or "normal"
    if not recipe and entity.type == "furnace" and entity.previous_recipe then
        recipe = prototypes.recipe[entity.previous_recipe.name]
        quality = entity.previous_recipe.quality or "normal"
    end
    return recipe, quality
end

local function getRecipeName(entity)
    if entity.type == "mining-drill" then
        if entity.mining_target then return "Mine "..entity.mining_target.prototype.name, "normal" end
        return "", "normal"
    end
    local recipe, qualityPrototype = entity.get_recipe()
    local quality = (qualityPrototype and qualityPrototype.name) or "normal"
    if recipe then return recipe.name, quality end
    if entity.type == "furnace" and entity.previous_recipe then
        return entity.previous_recipe.name, entity.previous_recipe.quality or "normal"
    end
    return "", "normal"
end

return {
    getRecipe = getRecipe,
    getRecipeName = getRecipeName
}
