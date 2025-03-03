local utils = require("colors.utils")
local table_utils = require("colors.table_utils")
local buffer_utils = require("colors.buffer_utils")
local colors = require("colors.color.utils")
local color_patterns = require("colors.color.patterns")
local ns_id = vim.api.nvim_create_namespace("colors")

if vim.g.loaded_colors ~= nil then
	return {}
end
vim.g.loaded_colors = 1

local displays = utils.displays
local row_offset = 2
local is_loaded = false
local options = {
	display = { displays.symbol, displays.foreground },
	symbol = {
		text = "■", -- One more: 
		prefix = "◄", -- Some more: ▸, ◜
		suffix = "►", -- Some more: ◂, ◞
		position = "eow",
	},
	enable_hex = true,
	enable_rgb = true,
	enable_hsl = true,
	enable_hsl_without_function = true,
	enable_var_usage = true,
	enable_named_colors = true,
	enable_short_hex = true,
	enable_tailwind = false,
	custom_colors = nil,
	exclude_filetypes = {},
	exclude_buftypes = {},
	exclude_buffer = function(bufnr) end,
}

local M = {}

local function validate_displays(user_display)
	local valid_display_types = {
		[displays.background] = true,
		[displays.foreground] = true,
		[displays.symbol] = true,
	}

	local filtered_display = {}
	for _, r in ipairs(user_display) do
		if valid_display_types[r] then
			table.insert(filtered_display, r)
		end
	end

	if #filtered_display >= 2 then
		local has_background = false
		local has_foreground = false
		for _, v in ipairs(filtered_display) do
			if v == displays.background then
				has_background = true
			elseif v == displays.foreground then
				has_foreground = true
			end
		end
		if has_background and has_foreground then
			vim.notify(
				"You cannot use background and foreground at the same time, colors.nvim is disabled!",
				"error"
			)
			M.turn_off()
			vim.api.nvim_del_user_command("Colors")
		end
	end

	return filtered_display
end



---Plugin entry point
---@param user_options table Check 'options' variable above
function M.setup(user_options)
	is_loaded = true
	if user_options ~= nil and user_options ~= {} then
		for key, _ in pairs(user_options) do
			if user_options[key] ~= nil then
				if key == "display" and type(user_options[key]) == "table" then
					options[key] = validate_displays(user_options[key])
				elseif key == "display" and type(user_options[key]) == "string" then
					options[key] = validate_displays({ user_options[key] })
				else
					options[key] = user_options[key]
				end
			end
		end
	end
	-- M.create_command()
end

---Highlight visible colors within specified buffer id
---@param min_row number
---@param max_row number
---@param active_buffer_id number
function M.highlight_colors(min_row, max_row, active_buffer_id)
	local patterns = {}
	local patterns_config = {
		HEX = {
			is_enabled = options.enable_hex,
			patterns = {
				color_patterns.hex_regex,
				color_patterns.hex_0x_regex,
			},
		},
		RGB = {
			is_enabled = options.enable_rgb,
			patterns = { color_patterns.rgb_regex },
		},
		HSL = {
			is_enabled = options.enable_hsl,
			patterns = { color_patterns.hsl_regex },
		},
		HSL_WITHOUT_FUNC = {
			is_enabled = options.enable_hsl_without_function,
			patterns = { color_patterns.hsl_without_func_regex },
		},
		VAR_USAGE = {
			is_enabled = options.enable_var_usage,
			patterns = { color_patterns.var_usage_regex },
		},
		NAMED_COLORS = {
			is_enabled = options.enable_named_colors,
			patterns = { colors.get_css_named_color_pattern() },
		},
		TAILWIND = {
			is_enabled = options.enable_tailwind and not utils.has_tailwind_css_lsp(),
			patterns = { colors.get_tailwind_named_color_pattern() },
		},
	}

	for _, config in pairs(patterns_config) do
		if config.is_enabled then
			for _, pattern in pairs(config.patterns) do
				table.insert(patterns, pattern)
			end
		end
	end

	if options.custom_colors ~= nil then
		for _, custom_color in pairs(options.custom_colors) do
			table.insert(patterns, custom_color.label)
		end
	end

	local positions = buffer_utils.get_positions_by_regex(
		patterns,
		min_row - 1,
		max_row,
		active_buffer_id,
		row_offset
	)
	for _, data in pairs(positions) do
		for _, display_type in ipairs(options.display) do
			utils.create_highlight(
				active_buffer_id,
				ns_id,
				data,
				vim.tbl_extend("force", options, { display = display_type }) -- Pass display type dynamically
			)
		end
	end

	utils.highlight_with_lsp(active_buffer_id, ns_id, positions, options)
end

---Refreshes current highlights within the specified buffer
---@param active_buffer_id number
---@param should_clear_highlights boolean Indicates whether the current highlights should be deleted before displaying
function M.refresh_highlights(active_buffer_id, should_clear_highlights)
	local buffer_id = active_buffer_id ~= nil and active_buffer_id or 0
	if
		not vim.api.nvim_buf_is_valid(active_buffer_id)
		or vim.bo[buffer_id].buftype == "terminal"
		or vim.tbl_contains(options.exclude_filetypes, vim.bo[buffer_id].filetype)
		or vim.tbl_contains(options.exclude_buftypes, vim.bo[buffer_id].buftype)
		or (options.exclude_buffer and options.exclude_buffer(buffer_id))
	then
		return
	end

	if should_clear_highlights then
		M.clear_highlights(buffer_id)
	end
	local visible_rows = utils.get_visible_rows_by_buffer_id(buffer_id)
	local min_row = visible_rows[1]
	local max_row = visible_rows[2]
	M.highlight_colors(min_row, max_row, buffer_id)
end

---Deletes highlights for the specified buffer
---@param active_buffer_id number
function M.clear_highlights(active_buffer_id)
	pcall(function()
		local buffer_id = active_buffer_id ~= nil and active_buffer_id or 0
		vim.api.nvim_buf_clear_namespace(buffer_id, ns_id, 0, utils.get_last_row_index())
		local symbol_texts = vim.api.nvim_buf_get_extmarks(buffer_id, ns_id, 0, -1, {})

		if #symbol_texts then
			for _, symbol_text in pairs(symbol_texts) do
				local extmart_id = symbol_text[1]
				if tonumber(extmart_id) ~= nil then
					vim.api.nvim_buf_del_extmark(buffer_id, ns_id, extmart_id)
				end
			end
		end
	end)
end

-- a cache of documentation text to hex code & hlgroup
-- an entry of nil means a cache miss
-- an entry of false means a cache hit with no color
-- an entry of a table means a cache hit with a color
---@type table<string,nil|false|{ hl_group: string, color_hex: string }>
local format_cache = {}

---Formats nvim-cmp to showcase colors in the autocomplete
---@usage
---Add the following to your nvim-cmp setup
---cmp.setup({
---...other configs
---formatting = {
---    format = require("colors").format
---}
function M.format(entry, item)
	item.menu = item.kind
	item.kind = item.abbr
	item.kind_hl_group = ""
	item.abbr = ""

	if item.menu ~= "Color" then
		return item
	end

	local entryDoc = entry
	if type(entryDoc) == "table" then
		entryDoc = vim.tbl_get(entry or {}, "completion_item", "documentation")
	end
	if type(entryDoc) ~= "string" then
		return item
	end

	local cached = format_cache[entryDoc]
	if cached == nil then
		local color_hex = colors.get_color_value(entryDoc)
		cached = color_hex
				and {
					hl_group = utils.create_highlight_name("fg-" .. color_hex),
					color_hex = color_hex,
				}
			or false
		format_cache[entryDoc] = cached
	end
	if cached then
		vim.api.nvim_set_hl(0, cached.hl_group, { fg = cached.color_hex, default = true })
		item.abbr_hl_group = cached.hl_group
		item.abbr = options.symbol.text
	end
	return item
end

---Callback to manually show the highlights
function M.turn_on()
	local buffers = vim.fn.getbufinfo({ buflisted = true })
	for _, buffer in ipairs(buffers) do
		M.refresh_highlights(buffer.bufnr, false)
	end

	is_loaded = true
end

---Callback to manually hide the highlights
function M.turn_off()
	local buffers = vim.fn.getbufinfo({ buflisted = true })
	for _, buffer in ipairs(buffers) do
		M.clear_highlights(buffer.bufnr)
	end

	is_loaded = false
end

---Callback to manually toggle the highlights
function M.toggle()
	if is_loaded then
		M.turn_off()
	else
		M.turn_on()
	end
end

---Callback to get the current on/off state of the plugin.
function M.is_active()
	return is_loaded
end

---Autocmd callback to handle changes that require a complete redraw of the highlights (clear current highlights + highlight again)
---@param props {buf: number}
function M.handle_change_autocmd_callback(props)
	if is_loaded then
		M.refresh_highlights(props.buf, true)
	end
end

---Autocmd callback to handle changes that do not require a full redraw of the highlights
---@param props {buf: number}
function M.handle_autocmd_callback(props)
	if is_loaded then
		M.refresh_highlights(props.buf, false)
	end
end

vim.api.nvim_create_autocmd({
	"TextChanged",
	"InsertLeave",
	"TextChangedP",
	"LspAttach",
	"BufEnter",
}, {
	callback = M.handle_change_autocmd_callback,
})
vim.api.nvim_create_autocmd({
	"VimResized",
	"WinScrolled",
}, {
	callback = M.handle_autocmd_callback,
})

vim.api.nvim_create_user_command("HighlightColors", function(opts)
	local arg = string.lower(opts.fargs[1])
	if arg == "on" then
		M.turn_on()
	elseif arg == "off" then
		M.turn_off()
	elseif arg == "toggle" then
		M.toggle()
	elseif arg == "isactive" then
		M.is_active()
	end
end, {
	nargs = 1,
	complete = function()
		return { "On", "Off", "Toggle", "IsActive" }
	end,
	desc = "Config color highlight",
})

return {
	turnOff = M.turn_off,
	turnOn = M.turn_on,
	setup = M.setup,
	toggle = M.toggle,
	is_active = M.is_active,
	format = M.format,
}
