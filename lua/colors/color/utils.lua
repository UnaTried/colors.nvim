local buffer_utils = require("colors.buffer_utils")
local css_named_colors = require("colors.named-colors.css")
local tailwind_named_colors = require("colors.named-colors.tailwind")
local converters = require("colors.color.converters")
local patterns = require("colors.color.patterns")

local M = {}

---Returns the color value in hex
---@param color string
---@param row_offset? number
---@param custom_colors? {label: string, color: string}[]
---@param enable_short_hex? boolean
---@return string | nil
function M.get_color_value(color, row_offset, custom_colors, enable_short_hex )
	if (enable_short_hex and patterns.is_short_hex_color(color)) then
		return converters.short_hex_to_hex(color)
	end

	if (patterns.is_alpha_layer_hex(color)) then
		return string.sub(color, 1, 7)
	end

	if (patterns.is_rgb_color(color)) then
		local rgb_table = M.get_rgb_values(color)
		if (#rgb_table >= 3) then
			return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
		end
	end

	if (patterns.is_hsl_color(color)) then
		local hsl_table = M.get_hsl_values(color)
		local rgb_table = converters.hsl_to_rgb(hsl_table[1], hsl_table[2], hsl_table[3])
		return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
	end

	if (patterns.is_named_color({M.get_css_named_color_pattern()}, color)) then
		return M.get_css_named_color_value(color)
	end

	if (patterns.is_named_color({M.get_tailwind_named_color_pattern()}, color)) then
		local tailwind_color = M.get_tailwind_named_color_value(color)
		if (tailwind_color ~= nil) then
			return tailwind_color
		end
	end

	if (row_offset ~= nil and patterns.is_var_color(color)) then
		return M.get_css_var_color(color, row_offset)
	end

	if (custom_colors ~= nil and patterns.is_custom_color(color, custom_colors)) then
		return M.get_custom_color(color, custom_colors)
	end

	local hex_color = color:gsub("0x", "#")

	if (patterns.is_hex_color(hex_color)) then
		return hex_color
	end

	return nil
end

---Returns the rgb table of a rgb string
---@param color string
---@return string[]
function M.get_rgb_values(color)
	local rgb_table = {}
	for color_number in string.gmatch(color, "%d+") do
		table.insert(rgb_table, color_number)
	end

	return rgb_table
end

---Returns the hsl table of a hsl string
---@param color string
---@return string[]
function M.get_hsl_values(color)
	local hsl_table = {}
	for color_number in string.gmatch(color, "%d?%.?%d+") do
		table.insert(hsl_table, color_number)
	end

	return hsl_table
end

---Returns the hex value of a CSS color
---@param color string
---@return string
---@usage get_css_named_color_value('red') => Returns '#FF0000'
function M.get_css_named_color_value(color)
	local color_name = string.match(color, "%a+")
	return css_named_colors[color_name]
end

---Returns the hex value of a tailwind color
---@param color string
---@return string|nil
---@usage get_tailwind_named_color_value('bg-white') => Returns '#FFFFFF'
function M.get_tailwind_named_color_value(color)
	local tailwind_color_name = color
	-- Removing tailwind prefix from color name: text-slate-500 -> slate-500
	local _, end_index = string.find(tailwind_color_name, patterns.tailwind_prefix .. "%-")
	if end_index then
		tailwind_color_name = string.sub(tailwind_color_name, end_index + 1, string.len(tailwind_color_name))
	end
	local tailwind_color = tailwind_named_colors[tailwind_color_name]
	if tailwind_color == nil then
		return nil
	end
	local rgb_table = M.get_rgb_values(tailwind_color)
	if (#rgb_table >= 3) then
		return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
	end
end

---Returns a pattern for tailwind colors
---@return string
function M.get_tailwind_named_color_pattern()
	return patterns.tailwind_prefix .. "%-%a+[%-%d+]*"
end

---Returns a pattern for CSS colors
---@return string
function M.get_css_named_color_pattern()
	return buffer_utils.color_usage_regex .. "%a+"
end

---Returns the hex value of a custom color
---@param color string
---@param custom_colors {label: string, color: string}[]
---@usage get_custom_color('custom-white', {{label = 'custom%-white', color: '#FFFFFF'}}) => Returns '#FFFFFF'
---@return string|nil
function M.get_custom_color(color, custom_colors)
	for _, custom_color in pairs(custom_colors) do
		if color == custom_color.label:gsub("%%", "") then
			return M.get_color_value(custom_color.color)
		end
	end

	return nil
end

---Returns the hex value of a CSS variable
---@param color string
---@param row_offset number
---@return string|nil
function M.get_css_var_color(color, row_offset)
	local var_name = string.match(color, patterns.var_regex)
	local var_name_regex = string.gsub(var_name, "%-", "%%-")
	local value_patterns = {patterns.hex_regex, patterns.rgb_regex, patterns.hsl_regex}
	local var_patterns = {}

	for _, pattern in pairs(value_patterns) do
		table.insert(var_patterns, var_name_regex .. ":%s*" .. pattern)
	end
	for _, css_color_pattern in pairs({M.get_css_named_color_pattern()}) do
		table.insert(var_patterns, var_name_regex .. css_color_pattern)
	end

	local var_position = buffer_utils.get_positions_by_regex(var_patterns, 0, vim.fn.line('$'), 0, row_offset)

	if (#var_position > 0) then
		local hex_color = string.match(var_position[1].value, patterns.hex_regex)
		local rgb_color = string.match(var_position[1].value, patterns.rgb_regex)
		local hsl_color = string.match(var_position[1].value, patterns.hsl_regex)
		if hex_color then
			return M.get_color_value(hex_color)
		elseif rgb_color then
			return M.get_color_value(rgb_color)
		elseif hsl_color then
			return M.get_color_value(hsl_color)
		else
			return M.get_css_named_color_value(
				string.gsub(var_position[1].value, var_name_regex, "")
			)
		end
	end

	return nil
end

---Returns a contrast friendly color that matches the current color for reading purposes
---@param color string
---@return string|nil

function M.get_background_color()
    -- Get the 'Normal' highlight group properties
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    -- Check if 'bg' (background color) exists
    if normal_hl and normal_hl.bg then
        -- Return background color as a hex string
        return string.format("#%06x", normal_hl.bg)
    end

    -- Return nil if no background color is set
    return nil
end

-- Ensure bit32 module is available for Lua 5.1 (Lua 5.2+ uses the bit library by default)
local bit = require('bit')

function M.get_reversed_background_color()
    -- Get the 'Normal' highlight group properties
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    -- Check if 'bg' (background color) exists
    if normal_hl and normal_hl.bg then
        -- Extract the individual RGB components from the bg integer using bit32
        local red = bit.rshift(normal_hl.bg, 16) -- Extract the red component
        local green = bit.rshift(normal_hl.bg, 8) -- Extract the green component
        local blue = normal_hl.bg                 -- Extract the blue component

        -- Apply the bitwise AND operation to isolate each component
        red = bit.band(red, 0xFF)
        green = bit.band(green, 0xFF)
        blue = bit.band(blue, 0xFF)

        -- Invert the colors by subtracting each component from 255
        local inverted_red = 255 - red
        local inverted_green = 255 - green
        local inverted_blue = 255 - blue

        -- Combine the inverted components back into an integer
        local inverted_color = bit.lshift(inverted_red, 16) + bit.lshift(inverted_green, 8) + inverted_blue

        -- Return the inverted color as a hex string
        return string.format("#%06x", inverted_color)
    end

    -- Return nil if no background color is set
    return nil
end




return M
