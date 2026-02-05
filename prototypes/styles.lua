local styles = data.raw["gui-style"].default

-- Nomenclature: small = size 36; tiny = size 32

-- Imitates a listbox, but allowing for way more customisation by using real buttons
styles["fi_scroll-pane_fake_listbox"] = {
    type = "scroll_pane_style",
    extra_right_padding_when_activated = -12,
    background_graphical_set = { -- rubber grid
        position = {282,17},
        corner_size = 8,
        overall_tiling_vertical_size = 22,
        overall_tiling_vertical_spacing = 6,
        overall_tiling_vertical_padding = 4,
        overall_tiling_horizontal_padding = 4
    },
    vertically_stretchable = "on",
    padding = 0,
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0
    }
}

styles["fi_table_production"] = {
    type = "table_style",
    odd_row_graphical_set =
      {
        filename = "__core__/graphics/gui-new.png",
        position = {472, 25},
        size = 1
      }
}

-- A button that can be used in a fake listbox, but looks identical to the real thing
styles["fi_button_fake_listbox_item"] = {
    type = "button_style",
    parent = "list_box_item",
    left_padding = 4,
    right_padding = 8,
    horizontally_stretchable = "on",
    horizontally_squashable = "on"
}

styles["fi_button_fake_listbox_item_active"] = {
    type = "button_style",
    parent = "fi_button_fake_listbox_item",
    default_graphical_set = styles.button.selected_graphical_set,
    hovered_graphical_set = styles.button.selected_hovered_graphical_set,
    clicked_graphical_set = styles.button.selected_clicked_graphical_set,
    default_font_color = styles.button.selected_font_color,
    default_vertical_offset = styles.button.selected_vertical_offset
}

-- Production and consumption table styles

styles["fi_table_sprite_heading"] = {
    type = "label_style",
    font = "default-bold",
    width = 30,
    maximal_width = 30
}

styles["fi_table_text_heading"] = {
    type = "label_style",
    font = "default-bold",
    width = 250,
    maximal_width = 250
}

styles["fi_table_number_heading"] = {
    type = "label_style",
    font = "default-bold",
    width = 120,
    maximal_width = 120,
    horizontal_align = "center"
}

styles["fi_table_text"] = {
    type = "label_style",
    width = 250,
    maximal_width = 250
}

styles["fi_table_number"] = {
    type = "label_style",
    width = 120,
    maximal_width = 120,
    horizontal_align = "center"
}