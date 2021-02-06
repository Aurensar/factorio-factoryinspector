local results = require "script.results"
itemList = {}

function itemList.create(player)
    local ui_state = ui.ui_state(player)

    local search_box = ui_state.left_column.add{type="text-box", name="fi_textbox_search_items"}

    local item_list_holder = ui_state.left_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    item_list_holder.style.vertically_stretchable = true

    ui_state.listbox_items = item_list_holder.add{type="scroll-pane", style="fi_scroll-pane_fake_listbox"}
    ui_state.listbox_items.style.width = 200

    itemList.refresh(player)
end

function renderItem(ui_state, item, selected_item)
    if ui_state.item_filter and not string.find(item, ui_state.item_filter) then return end

    local selected = (item == selected_item)
    local style = (selected) and "fp_button_fake_listbox_item_active" or "fp_button_fake_listbox_item"
    local tooltip = {"", item, item}
    local name
    if game.item_prototypes[item] then name = game.item_prototypes[item].localised_name else name = game.fluid_prototypes[item].localised_name end

    ui_state.listbox_items.add{type="button", name = string.format("fi_item_button_%s", item), caption = name,
      tooltip=tooltip, style=style, mouse_button_filter={"left-and-right"}}
end

function itemList.refresh(player)
    local ui_state = ui.ui_state(player)
    local items = results.getOrderedItemList()
    local selected_item = ui_state.selected_item

    ui_state.listbox_items.clear()

    for _, item in pairs(items) do
        renderItem(ui_state, item, selected_item)
    end
end