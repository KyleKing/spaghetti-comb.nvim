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
    SpaghettiCombBookmark = { fg = "#F39C12", bold = true },
    SpaghettiCombPreviewHeader = { fg = "#9B59B6", bold = true },
    SpaghettiCombPreviewLineNum = { fg = "#5C6370" },
    SpaghettiCombPreviewTarget = { bg = "#3E4451", bold = true },
    SpaghettiCombPreviewCode = { fg = "#ABB2BF" },
    SpaghettiCombExpandIndicator = { fg = "#56B6C2", bold = true },
    SpaghettiCombKeyword = { fg = "#C678DD", bold = true },
    SpaghettiCombFunction = { fg = "#61AFEF" },
    SpaghettiCombString = { fg = "#98C379" },
    SpaghettiCombComment = { fg = "#5C6370", italic = true },
    SpaghettiCombOperator = { fg = "#C678DD" },
    SpaghettiCombNumber = { fg = "#D19A66" },
    SpaghettiCombType = { fg = "#E5C07B" },
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
            M.highlight_title_line(buf_id, ns_id, line_idx, line)
        elseif
            line:match("^References")
            or line:match("^Definitions")
            or line:match("^Incoming Calls")
            or line:match("^Outgoing Calls")
        then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombSection", line_idx, 0, -1)
        elseif line:match("^[├└]─") then
            M.highlight_relation_line(buf_id, ns_id, line_idx, line)
        elseif line:match("^  [▶▼] %[Preview:") then
            M.highlight_preview_header(buf_id, ns_id, line_idx, line)
        elseif line:match("^    [▶ ]%d+") then
            M.highlight_preview_code_line(buf_id, ns_id, line_idx, line)
        elseif line:match("Press <Tab>") or line:match("Try positioning") then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombComment", line_idx, 0, -1)
        end
    end
end

function M.highlight_title_line(buf_id, ns_id, line_idx, line)
    local start_pos = line:find("'")
    local end_pos = line:find("'", start_pos + 1)
    if start_pos and end_pos then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, 0, start_pos - 1)
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombSymbol", line_idx, start_pos - 1, end_pos)
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, end_pos, -1)
    else
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTitle", line_idx, 0, -1)
    end
end

function M.highlight_relation_line(buf_id, ns_id, line_idx, line)
    local tree_end = line:find("─ ") + 1
    vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombTree", line_idx, 0, tree_end)

    -- Highlight bookmark star
    local bookmark_start = line:find("★")
    if bookmark_start then
        vim.api.nvim_buf_add_highlight(
            buf_id,
            ns_id,
            "SpaghettiCombBookmark",
            line_idx,
            bookmark_start - 1,
            bookmark_start
        )
    end

    local icon_start = line:find("📄")
    if icon_start then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombIcon", line_idx, icon_start - 1, icon_start)
    end

    local file_start = tree_end + 1
    if bookmark_start and bookmark_start > tree_end then file_start = bookmark_start + 1 end

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

function M.highlight_preview_header(buf_id, ns_id, line_idx, line)
    -- Highlight expand/collapse indicator
    local indicator_start = line:find("[▶▼]")
    if indicator_start then
        vim.api.nvim_buf_add_highlight(
            buf_id,
            ns_id,
            "SpaghettiCombExpandIndicator",
            line_idx,
            indicator_start - 1,
            indicator_start
        )
    end

    -- Highlight the preview header
    local preview_start = line:find("%[Preview:")
    if preview_start then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombPreviewHeader", line_idx, preview_start - 1, -1)
    end
end

function M.highlight_preview_code_line(buf_id, ns_id, line_idx, line)
    -- Highlight line number
    local line_num_match = line:match("^    ([▶ ])(%d+)")
    if line_num_match then
        local marker_end = line:find("%d") - 1
        local line_num_end = line:find("│") - 1

        if marker_end > 0 then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombPreviewTarget", line_idx, 0, marker_end)
        end

        if line_num_end > marker_end then
            vim.api.nvim_buf_add_highlight(
                buf_id,
                ns_id,
                "SpaghettiCombPreviewLineNum",
                line_idx,
                marker_end,
                line_num_end
            )
        end

        -- Highlight the code content with basic syntax highlighting
        local code_start = line:find("│") + 1
        if code_start then M.highlight_code_syntax(buf_id, ns_id, line_idx, line, code_start) end
    end
end

function M.highlight_code_syntax(buf_id, ns_id, line_idx, line, start_pos)
    local code_text = line:sub(start_pos + 1)

    -- Basic syntax highlighting patterns
    local patterns = {
        { pattern = "function%s+(%w+)%s*%(", highlight = "SpaghettiCombFunction" },
        { pattern = "(%w+)%s*%(", highlight = "SpaghettiCombFunction" },
        { pattern = '"[^"]*"', highlight = "SpaghettiCombString" },
        { pattern = "'[^']*'", highlight = "SpaghettiCombString" },
        { pattern = "`[^`]*`", highlight = "SpaghettiCombString" },
        { pattern = "//.*$", highlight = "SpaghettiCombComment" },
        { pattern = "#.*$", highlight = "SpaghettiCombComment" },
        { pattern = "%d+%.?%d*", highlight = "SpaghettiCombNumber" },
        { pattern = "[%+%-*/=<>!&|]+", highlight = "SpaghettiCombOperator" },
        { pattern = "%b()", highlight = "SpaghettiCombOperator" },
        { pattern = "%b{}", highlight = "SpaghettiCombOperator" },
        { pattern = "%b[]", highlight = "SpaghettiCombOperator" },
    }

    -- Keywords by language (basic set)
    local keywords = {
        "function",
        "return",
        "if",
        "else",
        "for",
        "while",
        "do",
        "end",
        "local",
        "const",
        "let",
        "var",
        "class",
        "interface",
        "type",
        "import",
        "export",
        "from",
        "as",
        "def",
        "async",
        "await",
        "true",
        "false",
        "null",
        "undefined",
        "nil",
        "None",
        "True",
        "False",
    }

    for _, keyword in ipairs(keywords) do
        local pattern = string.format("\\b%s\\b", keyword)
        local start_col = 1
        while true do
            local match_start, match_end = code_text:find(pattern, start_col)
            if not match_start then break end

            vim.api.nvim_buf_add_highlight(
                buf_id,
                ns_id,
                "SpaghettiCombKeyword",
                line_idx,
                start_pos + match_start - 1,
                start_pos + match_end
            )
            start_col = match_end + 1
        end
    end

    -- Apply other patterns
    for _, pattern_info in ipairs(patterns) do
        local start_col = 1
        while true do
            local match_start, match_end = code_text:find(pattern_info.pattern, start_col)
            if not match_start then break end

            vim.api.nvim_buf_add_highlight(
                buf_id,
                ns_id,
                pattern_info.highlight,
                line_idx,
                start_pos + match_start - 1,
                start_pos + match_end
            )
            start_col = match_end + 1
        end
    end

    -- Default code highlighting for the rest
    vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombPreviewCode", line_idx, start_pos, -1)
end

function M.setup()
    setup_highlight_groups()

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() setup_highlight_groups() end,
        group = vim.api.nvim_create_augroup("SpaghettiCombHighlights", { clear = true }),
    })
end

return M
