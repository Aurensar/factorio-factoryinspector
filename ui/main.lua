require("script.ui")
require("ui.item-list")
require("ui.production-tables")
require("ui.production-diagnostics")

fiMainFrame = {}

local function createHeader(player)
    local ui_state = ui.ui_state(player)
    local titleBar = ui_state.mainFrame.add{type="flow", name="fi_flow_main_titlebar", direction="horizontal"}
    titleBar.style.horizontal_spacing = 8
    titleBar.drag_target = ui_state.mainFrame
    titleBar.style.height = 30

    titleBar.add{type="label", caption={"mod-name.fi"}, style="frame_title",
        ignored_by_interaction=true}

    local label_hint = titleBar.add{type="label", ignored_by_interaction=true}
    label_hint.style.font = "heading-2"
    label_hint.style.margin = {0, 0, 0, 8}
    label_hint.style.horizontally_squashable = true

    local drag_handle = titleBar.add{type="empty-widget", name="fi_main_drag_handle",
       style="flib_titlebar_drag_handle", ignored_by_interaction=true}
    drag_handle.style.minimal_width = 80

    local separation = titleBar.add{type="line", direction="vertical"}
    separation.style.height = 24

    local button_close = titleBar.add{type="sprite-button", name="fi_title_bar_close_interface",
        sprite="utility/close", hovered_sprite="utility/close_black", clicked_sprite="utility/close_black",
        tooltip={"fi.close_interface"}, style="frame_action_button", mouse_button_filter={"left"}}
    button_close.style.padding = 2
end

function fiMainFrame.create(player, visible)
    local gui = player.gui.screen.add{type="frame", name="fi_frame_main_dialog", visible=visible, direction="vertical"}
    local ui_state = ui.ui_state(player)

    local resolution, scale = player.display_resolution, player.display_scale
    local dimensions = {width=resolution.width * 0.6 / scale, height = resolution.height * 0.7 / scale}
    local x_offset = ((resolution.width - (dimensions.width * scale)) / 2)
    local y_offset = ((resolution.height - (dimensions.height * scale)) / 2)
    gui.location = {x_offset, y_offset}
    gui.style.size = dimensions
    gui.style.width = dimensions.width
    gui.style.height = dimensions.height
    ui_state.mainFrame = gui
    createHeader(player)

    local main_horizontal = gui.add{type="flow", direction="horizontal"}
    main_horizontal.style.horizontal_spacing = 10
    main_horizontal.style.width = gui.style.maximal_width
    main_horizontal.style.height = gui.style.maximal_height - 50

    local toplevel_left_column = main_horizontal.add{type="flow", direction="vertical"}
    toplevel_left_column.style.vertical_spacing = 10
    toplevel_left_column.style.width = 250

    local toplevel_right_column = main_horizontal.add{type="flow", direction="vertical"}
    toplevel_right_column.style.vertical_spacing = 10
    toplevel_right_column.style.width = gui.style.maximal_width - 300

    ui_state.left_column = toplevel_left_column
    ui_state.right_column = toplevel_right_column

    itemList.create(player)
    productionTables.create(player)

    if visible then player.opened = gui end
end

function fiMainFrame.refresh(player, context_to_refresh)
end

function fiMainFrame.toggle(player)
    local ui_state = ui.ui_state(player)
    local mainFrame = ui_state.mainFrame

    if not mainFrame or not mainFrame.valid then
        ui_state.mainFrame = nil
        fiMainFrame.create(player, true)
        return
    end

    local v = not mainFrame.visible
    mainFrame.visible = v
    player.opened = (v) and mainFrame or nil
end

function fiMainFrame.close(player)
    local ui_state = ui.ui_state(player)
    local mainFrame = ui_state.mainFrame

    if mainFrame and mainFrame.valid then
        mainFrame.visible = false
        if player.opened == mainFrame then player.opened = nil end
    end
end