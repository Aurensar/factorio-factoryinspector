data:extend({
    {
        type = "bool-setting",
        name = "factory-inspector-enable-verification",
        setting_type = "runtime-global",
        default_value = false,
        order = "a"
    },
    {
        type = "int-setting",
        name = "factory-inspector-display-window-seconds",
        setting_type = "runtime-global",
        default_value = 120,
        minimum_value = 10,
        maximum_value = 300,
        order = "b"
    }
})
