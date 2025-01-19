local colors = require("colors.color.utils")
local table_utils = require("colors.table_utils")

local M = {
	render_options = {
		background = "background",
		foreground = "foreground",
		symbol = 'symbol'
	}
}

---Returns the last row index of the current buffer
---@return number
function M.get_last_row_index()
	return vim.fn.line('$')
end

---Returns a range of visible rows of the specified buffer
---@param buffer_id number
---@return table {first_line_index, last_line_index}
function M.get_visible_rows_by_buffer_id(buffer_id)
	local window_id = vim.fn.bufwinid(buffer_id)

	return vim.api.nvim_win_call(
		window_id ~= -1 and window_id or 0,
		function()
			return {
				vim.fn.line('w0'),
				vim.fn.line('w$')
			}
		end
	)
end

---Returns a highlight name that can be used as a group highlight
---@param color_value string
---@return string
function M.create_highlight_name(color_value)
	return 'colors-' .. string.gsub(color_value, "#", ""):gsub("[!(),%s%.-/%%=:\"']+", "")
end

---Creates the highlight based on the received params
---@param active_buffer_id number
---@param ns_id number
---@param data {row: number, start_column: number, end_column: number, value: string}
---@param options {symbol: table, custom_colors: table, render: string, enable_short_hex: boolean}
---@param symbol {symbol: string, symbol_prefix: string, symbol_suffix: string, symbol_position: 'eow' | 'sow'}
---
---For `options.custom_colors`, a table with the following structure is expected:
---* `label`: A string representing a template for the color name, likely using placeholders for the theme name. (e.g., '%-%-theme%-primary%-color')
---* `color`: A string representing the actual color value in a valid format (e.g., '#0f1219').
function M.create_highlight(active_buffer_id, ns_id, data, options)
	local color_value = colors.get_color_value(data.value, 2, options.custom_colors, options.enable_short_hex)

	if color_value == nil then
		return
	end

	local highlight_group = M.create_highlight_name(options.render .. data.value .. color_value)
	local background_color = colors.get_background_color()
	local reversed_background_color = colors.get_reversed_background_color()

	if options.render == M.render_options.foreground then
		if background_color == color_value then
			pcall(vim.api.nvim_set_hl, 0, highlight_group, {
				fg = reversed_background_color,
				bg = color_value,
				default = true,
			})
		else
			pcall(vim.api.nvim_set_hl, 0, highlight_group, {
				fg = background_color,
				bg = color_value,
				default = true,
			})
		end
	elseif options.render == M.render_options.symbol then
		pcall(
			M.highlight_extmarks,
			active_buffer_id,
			ns_id,
			data,
			highlight_group,
			options
		)
		return
	else
		if background_color == color_value then
			pcall(vim.api.nvim_set_hl, 0, highlight_group, {
				fg = color_value,
				bg = reversed_background_color,
				default = true,
			})
		else
			pcall(vim.api.nvim_set_hl, 0, highlight_group, {
				fg = color_value,
				bg = background_color,
				default = true,
			})
		end
	end

	pcall(
		function()
			vim.api.nvim_buf_add_highlight(
				active_buffer_id,
				ns_id,
				highlight_group,
				data.row + 1,
				data.start_column,
				data.end_column
			)
		end
	)
end

---Highlights extmarks 
---@param active_buffer_id number
---@param ns_id number
---@param data {row: number, start_column: number, end_column: number, value: string}
---@param highlight_group string
---@param options {symbol: table, custom_colors: table, render: string, enable_short_hex: boolean}
---@param symbol {symbol: string, symbol_prefix: string, symbol_suffix: string, symbol_position: 'eow' | 'sow'}
function M.highlight_extmarks(active_buffer_id, ns_id, data, highlight_group, options)
	local start_extmark_row = data.row + 1
	local start_extmark_column = data.start_column - 1
	local symbol_text_position = M.get_symbol_text_position(options)
	local symbol_text_column = M.get_symbol_text_column(
		symbol_text_position,
		start_extmark_column,
		data.end_column
	)
	local already_highlighted_extmark = vim.api.nvim_buf_get_extmarks(
		active_buffer_id,
		ns_id,
		{start_extmark_row, start_extmark_column},
		{start_extmark_row, symbol_text_column},
		{details = true}
	)
	local is_already_highlighted = #table_utils.filter(
		already_highlighted_extmark,
		function (extmark)
			local extmark_data = vim.deepcopy(extmark[4])
			local extmark_highlight_group = extmark_data.virt_text[1][2]
			return extmark_highlight_group == highlight_group
		end
	) > 0
	if (is_already_highlighted) then
		return
	end

	-- Delete currently shown extmarks in this same position
	for _, extmark in pairs(already_highlighted_extmark) do
		pcall(
			vim.api.nvim_buf_del_extmark,
			active_buffer_id,
			ns_id,
			extmark[1]
		)
	end

	vim.api.nvim_buf_set_extmark(
		active_buffer_id,
		ns_id,
		start_extmark_row,
		symbol_text_column,
		{

			virt_text_pos = symbol_text_position == 'eow' and 'sow' or symbol_text_position,
			virt_text = {{
				options.symbol_symbol_prefix .. options.symbol .. options.symbol_suffix,
				vim.api.nvim_get_hl_id_by_name(highlight_group)
			}},
			hl_mode = "combine",
		}
	)
end

---Returns the symbol text(extmark) position based on the user preferences
---@param options {symbol_position: 'eol' | 'sow'}
---@return 'eol' | 'sow'
function M.get_symbol_text_position(options)
	local nvim_version = vim.version()

	-- Safe guard for older neovim versions
	if nvim_version.major == 0 and nvim_version.minor < 10 then
		return 'eol'
	end

	return options.symbol_position
end

---Returns the symbol text(extmark) column index position based on the user preferences
---@param symbol_text_position 'eol' | 'sow'
---@param start_extmark_column number
---@param end_extmark_column number
---@return number
function M.get_symbol_text_column(symbol_text_position, start_extmark_column, end_extmark_column)
	if symbol_text_position == 'eol' then
		return start_extmark_column
	end

	if symbol_text_position == 'eow' then
		return end_extmark_column
	end

	return start_extmark_column + 1
end

return M
