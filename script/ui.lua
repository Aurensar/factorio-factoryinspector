ui = {}

function ui.ui_state(player)
    -- move to oninit
    if not global.players then global.players = {} end
    if not global.players[player.index] then global.players[player.index] = {} end
    if not global.players[player.index].ui then global.players[player.index].ui = {} end
    return global.players[player.index].ui
end