local M = {}

local highlight_groups = {
    SpaghettiCombv2Title = { fg = "#87CEEB", bold = true },
    SpaghettiCombv2Section = { fg = "#98C379", bold = true },
    SpaghettiCombv2File = { fg = "#61AFEF" },
    SpaghettiCombv2Location = { fg = "#C678DD" },
    SpaghettiCombv2Coupling = { fg = "#E06C75" },
    SpaghettiCombv2CouplingHigh = { fg = "#E06C75", bold = true },
    SpaghettiCombv2CouplingMedium = { fg = "#E5C07B" },
    SpaghettiCombv2CouplingLow = { fg = "#56B6C2" },
    SpaghettiCombv2Icon = { fg = "#D19A66" },
    SpaghettiCombv2Tree = { fg = "#5C6370" },
    SpaghettiCombv2Symbol = { fg = "#ABB2BF", bold = true },
    SpaghettiCombv2Bookmark = { fg = "#F39C12", bold = true },
    SpaghettiCombv2PreviewHeader = { fg = "#9B59B6", bold = true },
    SpaghettiCombv2PreviewLineNum = { fg = "#5C6370" },
    SpaghettiCombv2PreviewTarget = { bg = "#3E4451", bold = true },
    SpaghettiCombv2PreviewCode = { fg = "#ABB2BF" },
    SpaghettiCombv2ExpandIndicator = { fg = "#56B6C2", bold = true },
    SpaghettiCombv2Keyword = { fg = "#C678DD", bold = true },
    SpaghettiCombv2Function = { fg = "#61AFEF" },
    SpaghettiCombv2String = { fg = "#98C379" },
    SpaghettiCombv2Comment = { fg = "#5C6370", italic = true },
    SpaghettiCombv2Operator = { fg = "#C678DD" },
    SpaghettiCombv2Number = { fg = "#D19A66" },
    SpaghettiCombv2Type = { fg = "#E5C07B" },
}

local function setup_highlight_groups()
    for group_name, opts in pairs(highlight_groups) do
        vim.api.nvim_set_hl(0, group_name, opts)
    end
end

local function get_coupling_highlight(coupling_score)
    if not coupling_score then return "SpaghettiCombv2Coupling" end

    if coupling_score >= 0.7 then
        return "SpaghettiCombv2CouplingHigh"
    elseif coupling_score >= 0.4 then
        return "SpaghettiCombv2CouplingMedium"
    else
        return "SpaghettiCombv2CouplingLow"
    end
end

function M.apply_highlights(buf_id)
    if not vim.api.nvim_buf_is_valid(buf_id) then return end

    setup_highlight_groups()

    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local ns_id = vim.api.nvim_create_namespace("spaghetti-comb-v1-highlights")

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
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Section", line_idx, 0, -1)
        elseif line:match("^[├└]─") then
            M.highlight_relation_line(buf_id, ns_id, line_idx, line)
        elseif line:match("^  [▶▼] %[Preview:") then
            M.highlight_preview_header(buf_id, ns_id, line_idx, line)
        elseif line:match("^    [▶ ]%d+") then
            M.highlight_preview_code_line(buf_id, ns_id, line_idx, line)
        elseif line:match("Press <Tab>") or line:match("Try positioning") then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Comment", line_idx, 0, -1)
        end
    end
end

function M.highlight_title_line(buf_id, ns_id, line_idx, line)
    local start_pos = line:find("'")
    local end_pos = line:find("'", start_pos + 1)
    if start_pos and end_pos then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Title", line_idx, 0, start_pos - 1)
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Symbol", line_idx, start_pos - 1, end_pos)
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Title", line_idx, end_pos, -1)
    else
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Title", line_idx, 0, -1)
    end
end

function M.highlight_relation_line(buf_id, ns_id, line_idx, line)
    local tree_end = line:find("─ ") + 1
    vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Tree", line_idx, 0, tree_end)

    -- Highlight bookmark star
    local bookmark_start = line:find("★")
    if bookmark_start then
        vim.api.nvim_buf_add_highlight(
            buf_id,
            ns_id,
            "SpaghettiCombv2Bookmark",
            line_idx,
            bookmark_start - 1,
            bookmark_start
        )
    end

    local icon_start = line:find("📄")
    if icon_start then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Icon", line_idx, icon_start - 1, icon_start)
    end

    local file_start = tree_end + 1
    if bookmark_start and bookmark_start > tree_end then file_start = bookmark_start + 1 end

    local colon_pos = line:find(":", file_start)
    if colon_pos then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2File", line_idx, file_start, colon_pos - 1)

        local bracket_start = line:find("%[C:", colon_pos)
        if bracket_start then
            vim.api.nvim_buf_add_highlight(
                buf_id,
                ns_id,
                "SpaghettiCombv2Location",
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
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2Location", line_idx, colon_pos - 1, -1)
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
            "SpaghettiCombv2ExpandIndicator",
            line_idx,
            indicator_start - 1,
            indicator_start
        )
    end

    -- Highlight the preview header
    local preview_start = line:find("%[Preview:")
    if preview_start then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2PreviewHeader", line_idx, preview_start - 1, -1)
    end
end

function M.highlight_preview_code_line(buf_id, ns_id, line_idx, line)
    -- Highlight line number
    local line_num_match = line:match("^    ([▶ ])(%d+)")
    if line_num_match then
        local marker_end = line:find("%d") - 1
        local line_num_end = line:find("│") - 1

        if marker_end > 0 then
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2PreviewTarget", line_idx, 0, marker_end)
        end

        if line_num_end > marker_end then
            vim.api.nvim_buf_add_highlight(
                buf_id,
                ns_id,
                "SpaghettiCombv2PreviewLineNum",
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
        { pattern = "function%s+(%w+)%s*%(", highlight = "SpaghettiCombv2Function" },
        { pattern = "(%w+)%s*%(", highlight = "SpaghettiCombv2Function" },
        { pattern = '"[^"]*"', highlight = "SpaghettiCombv2String" },
        { pattern = "'[^']*'", highlight = "SpaghettiCombv2String" },
        { pattern = "`[^`]*`", highlight = "SpaghettiCombv2String" },
        { pattern = "//.*$", highlight = "SpaghettiCombv2Comment" },
        { pattern = "#.*$", highlight = "SpaghettiCombv2Comment" },
        { pattern = "%d+%.?%d*", highlight = "SpaghettiCombv2Number" },
        { pattern = "[%+%-*/=<>!&|]+", highlight = "SpaghettiCombv2Operator" },
        { pattern = "%b()", highlight = "SpaghettiCombv2Operator" },
        { pattern = "%b{}", highlight = "SpaghettiCombv2Operator" },
        { pattern = "%b[]", highlight = "SpaghettiCombv2Operator" },
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
                "SpaghettiCombv2Keyword",
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
    vim.api.nvim_buf_add_highlight(buf_id, ns_id, "SpaghettiCombv2PreviewCode", line_idx, start_pos, -1)
end

function M.setup()
    setup_highlight_groups()

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() setup_highlight_groups() end,
        group = vim.api.nvim_create_augroup("SpaghettiCombv2Highlights", { clear = true }),
    })
end

return M
