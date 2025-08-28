local M = {}

local highlight_groups = {
    SpaghettiCombTitle = { fg = "#87CEEB", bold = true },
    SpaghettiCombSection = { fg = "#98C379", bold = true },
    SpaghettiCombFile = { fg = "#61AFEF" },
    SpaghettiCombLocation = { fg = "#C678DD" },
    SpaghettiCombCoupling = { fg = "#E06C75" },
    SpaghettiCombCouplingHigh = { fg = "#E06C75", bold = true },
    SpaghettiCombCouplingMedium = { fg = "#E5C07B" },
    SpaghettiCombCouplingLow = { fg = "#56B6C2" },
    SpaghettiCombIcon = { fg = "#D19A66" },
    SpaghettiCombTree = { fg = "#5C6370" },
    SpaghettiCombSymbol = { fg = "#ABB2BF", bold = true },
}

local function setup_highlight_groups()
    for group_name, opts in pairs(highlight_groups) do
        vim.api.nvim_set_hl(0, group_name, opts)
    end
end

local function get_coupling_highlight(coupling_score)
    if not coupling_score then return "SpaghettiCombCoupling" end

    if coupling_score >= 0.7 then
        return "SpaghettiCombCouplingHigh"
    elseif coupling_score >= 0.4 then
        return "SpaghettiCombCouplingMedium"
    else
        return "SpaghettiCombCouplingLow"
    end
end

function M.apply_highlights(buf_id)
    if not vim.api.nvim_buf_is_valid(buf_id) then return end

    setup_highlight_groups()

    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local ns_id = vim.api.nvim_create_namespace("spaghetti-comb-highlights")

    vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)

    for line_num, line in ipairs(lines) do
        local line_idx = line_num - 1

        if line:match("^Relations for") then
            local start_pos = line:find("'")
            local end_pos = line:find("'", start_pos + 1)
            if start_pos and end_pos then
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, 0, start_pos - 1)
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombSymbol", line_idx, start_pos - 1, end_pos)
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, end_pos, -1)
            else
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, 0, -1)
            end
        elseif
            line:match("^References")
            or line:match("^Definitions")
            or line:match("^Incoming Calls")
            or line:match("^Outgoing Calls")
        then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombSection", line_idx, 0, -1)
        elseif line:match("^[├└]─") then
            local tree_end = line:find("─ ") + 1
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTree", line_idx, 0, tree_end)

            local icon_start = line:find("📄")
            if icon_start then
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombIcon", line_idx, icon_start - 1, icon_start)
            end

            local file_start = tree_end + 1
            local colon_pos = line:find(":", file_start)
            if colon_pos then
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombFile", line_idx, file_start, colon_pos - 1)

                local bracket_start = line:find("%[C:", colon_pos)
                if bracket_start then
                    vim.api.nvim_buf_add_highlight(
                        buf_id,
                        ns_id,
                        "SpaghettiCombLocation",
                        line_idx,
                        colon_pos - 1,
                        bracket_start - 1
                    )

                    local coupling_match = line:match("%[C:([%d%.]+)%]", bracket_start)
                    if coupling_match then
                        local coupling_score = tonumber(coupling_match)
                        local highlight_group = get_coupling_highlight(coupling_score)
                        vim.api.nvim_buf_add_highlight(buf_id, ns_id, highlight_group, line_idx, bracket_start - 1, -1)
                    end
                else
                    vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombLocation", line_idx, colon_pos - 1, -1)
                end
            end
        end
    end
end

function M.setup()
    setup_highlight_groups()

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() setup_highlight_groups() end,
        group = vim.api.nvim_create_augroup("SpaghettiCombHighlights", { clear = true }),
    })
end

return M
