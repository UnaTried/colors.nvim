# colors.nvim
This is a work-in-progress Neovim plugin to preview and edit colors, like in vscode!

## It supports
- Realtime color highlighting
- Hex, rgb, hsl, CSS variables, and Tailwind CSS
- LSP that supports textDocument/documentColor like [tailwindcss](https://github.com/tailwindlabs/tailwindcss-intellisense) and [csslsp](https://github.com/microsoft/vscode-css-languageservice)
- Multiple modes: background, foreground, and symbol.
- Two modes can be used at the same time! Foreground and background wouldn't work though

There are some problems, but I would probably need some time to fix them.

# Configuration
<details open>
<summary>Default configuration</summary>
<br>

```
require('colors').setup({
	display = { "foreground", "symbol", }, -- foreground can be replaced with background
    symbol = {
		symbol = "⬤", -- ■ so you don't need to look
		symbol_prefix = " ",
		symbol_suffix = "",
		symbol_position = "eow", -- sow or eol also works
	},
	enable_hex = true,
	enable_rgb = true,
	enable_hsl = true,
	enable_var_usage = false,
	enable_named_colors = false,
	enable_short_hex = false,
	enable_tailwind = false,
	custom_colors = nil,
	exclude_filetypes = {},
	exclude_buftypes = {},
})
```
</details>
<details open>
<summary><a href="https://github.com/hrsh7th/nvim-cmp">nvim-cmp</a> integration</summary>
<br>
<details open style="padding-left: 1em;">
<summary>Common configuration style</summary>
<br>

```
require("cmp").setup({
        ... other configs
        formatting = {
                format = require("nvim-highlight-colors").format
        }
})
```
</details>
<details open style="padding-left: 1em;">
<summary> In lua</summary>
<br>

```
require("cmp").setup({
        ... other configs
        formatting = {
                format = function(entry, item)
                        item = -- YOUR other configs come first
                        return require("nvim-highlight-colors").format(entry, item)
                end
        }
})
```
</details>
</details>
<details open>
<summary><a href="https://github.com/Saghen/blink.cmp">blink.cmp</a> integration</summary>
<br>

```
require("blink.cmp").setup {
	completion = {
		menu = {
			draw = {
				components = {
					-- customize the drawing of kind icons
					kind_icon = {
						text = function(ctx)
						  -- default kind icon
						  local icon = ctx.kind_icon
							-- if LSP source, check for color derived from documentation
							if ctx.item.source_name == "LSP" then
								local color_item = require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
								if color_item and color_item.abbr then
								  icon = color_item.abbr
								end
							end
							return icon .. ctx.icon_gap
						end,
						highlight = function(ctx)
							-- default highlight group
							local highlight = "BlinkCmpKind" .. ctx.kind
							-- if LSP source, check for color derived from documentation
							if ctx.item.source_name == "LSP" then
								local color_item = require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
								if color_item and color_item.abbr_hl_group then
								  highlight = color_item.abbr_hl_group
								end
							end
							return highlight
						end,
					},
				},
			},
		},
	},
}
```
</details>
</details>
<details open>
<summary><a href="https://github.com/onsails/lspkind.nvim">lspkind.nvim</a> integration</summary>
<br>

```
require("cmp").setup({
        ... other configs
        formatting = {
                format = function(entry, item)
                        local color_item = require("nvim-highlight-colors").format(entry, { kind = item.kind })
                        item = require("lspkind").cmp_format({
                                -- any lspkind format settings here
                        })(entry, item)
                        if color_item.abbr_hl_group then
                                item.kind_hl_group = color_item.abbr_hl_group
                                item.kind = color_item.abbr
                        end
                        return item
                end
        }
})
```
</details>

# Special thanks to
- Breno Prata for [brenoprata10/nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors)