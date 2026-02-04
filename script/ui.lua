ui = {}

function ui.ui_state(player)
    -- move to oninit
    if not storage.players then storage.players = {} end
    if not storage.players[player.index] then storage.players[player.index] = {} end
    if not storage.players[player.index].ui then storage.players[player.index].ui = {} end
    return storage.players[player.index].ui
end