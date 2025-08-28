local utils = require("spaghetti-comb.utils")

local M = {}

local coupling_cache = {}
local MAX_CACHE_SIZE = 1000

-- Coupling weights for different types
local COUPLING_WEIGHTS = {
    STRUCTURAL = 0.3,
    DATA = 0.25,
    CONTROL = 0.25,
    CONTENT = 0.2,
}

-- Thresholds for coupling classification
local COUPLING_THRESHOLDS = {
    HIGH = 0.7,
    MEDIUM = 0.4,
    LOW = 0.0,
}

function M.calculate_coupling_score(symbol_info, references, definitions, incoming_calls, outgoing_calls)
    if not symbol_info or not symbol_info.text then return 0.0 end

    local cache_key = M.get_cache_key(symbol_info, references, definitions, incoming_calls, outgoing_calls)
    if coupling_cache[cache_key] then return coupling_cache[cache_key].total end

    references = references or {}
    definitions = definitions or {}
    incoming_calls = incoming_calls or {}
    outgoing_calls = outgoing_calls or {}

    local structural = M.analyze_structural_coupling(symbol_info, references, definitions)
    local data = M.analyze_data_coupling(symbol_info, references, outgoing_calls)
    local control = M.analyze_control_coupling(symbol_info, incoming_calls, outgoing_calls)
    local content = M.analyze_content_coupling(symbol_info, references)

    local total = (structural * COUPLING_WEIGHTS.STRUCTURAL)
        + (data * COUPLING_WEIGHTS.DATA)
        + (control * COUPLING_WEIGHTS.CONTROL)
        + (content * COUPLING_WEIGHTS.CONTENT)

    local metrics = {
        structural = structural,
        data = data,
        control = control,
        content = content,
        total = math.min(1.0, total),
        classification = M.classify_coupling(total),
        factors = M.get_coupling_factors(structural, data, control, content),
    }

    M.cache_coupling_result(cache_key, metrics)

    return metrics.total
end

function M.analyze_structural_coupling(symbol_info, references, definitions)
    local ref_count = #references
    local def_count = #definitions

    -- Base coupling from reference count (normalized)
    local ref_coupling = math.min(1.0, ref_count / 10.0)

    -- Multiple definitions increase coupling
    local def_coupling = def_count > 1 and 0.3 or 0.0

    -- File distribution analysis
    local file_distribution = M.analyze_file_distribution(references)
    local distribution_coupling = file_distribution.concentration

    -- Module boundary analysis
    local boundary_coupling = M.analyze_module_boundaries(symbol_info, references)

    return math.min(1.0, (ref_coupling + def_coupling + distribution_coupling + boundary_coupling) / 4.0)
end

function M.analyze_data_coupling(symbol_info, references, outgoing_calls)
    local data_coupling = 0.0

    -- Analyze parameter passing patterns
    local param_coupling = M.analyze_parameter_coupling(symbol_info, outgoing_calls)
    data_coupling = data_coupling + param_coupling

    -- Analyze shared data structures
    local shared_data_coupling = M.analyze_shared_data(symbol_info, references)
    data_coupling = data_coupling + shared_data_coupling

    -- Analyze return type complexity
    local return_coupling = M.analyze_return_coupling(symbol_info)
    data_coupling = data_coupling + return_coupling

    return math.min(1.0, data_coupling / 3.0)
end

function M.analyze_control_coupling(symbol_info, incoming_calls, outgoing_calls)
    local control_coupling = 0.0

    -- Control flow complexity
    local flow_complexity = M.analyze_control_flow(symbol_info)
    control_coupling = control_coupling + flow_complexity

    -- Call hierarchy depth
    local call_depth = M.analyze_call_depth(incoming_calls, outgoing_calls)
    control_coupling = control_coupling + call_depth

    -- Exception handling patterns
    local exception_coupling = M.analyze_exception_coupling(symbol_info)
    control_coupling = control_coupling + exception_coupling

    return math.min(1.0, control_coupling / 3.0)
end

function M.analyze_content_coupling(symbol_info, references)
    local content_coupling = 0.0

    -- Access to internal data
    local internal_access = M.analyze_internal_access(symbol_info, references)
    content_coupling = content_coupling + internal_access

    -- Modification patterns
    local modification_coupling = M.analyze_modification_patterns(symbol_info, references)
    content_coupling = content_coupling + modification_coupling

    return math.min(1.0, content_coupling / 2.0)
end

function M.analyze_file_distribution(references)
    if #references == 0 then return { concentration = 0.0, unique_files = 0, max_per_file = 0 } end

    local file_counts = {}
    local unique_files = 0
    local max_per_file = 0

    for _, ref in ipairs(references) do
        local file = ref.path or ref.file
        if file then
            file_counts[file] = (file_counts[file] or 0) + 1
            if file_counts[file] == 1 then unique_files = unique_files + 1 end
            max_per_file = math.max(max_per_file, file_counts[file])
        end
    end

    -- Calculate concentration (higher = more concentrated = higher coupling)
    local concentration = unique_files > 0 and (max_per_file / #references) or 0.0

    return {
        concentration = concentration,
        unique_files = unique_files,
        max_per_file = max_per_file,
        total_references = #references,
    }
end

function M.analyze_module_boundaries(symbol_info, references)
    if not symbol_info.file then return 0.0 end

    local symbol_module = M.get_module_name(symbol_info.file)
    local cross_module_refs = 0

    for _, ref in ipairs(references) do
        local ref_file = ref.path or ref.file
        if ref_file then
            local ref_module = M.get_module_name(ref_file)
            if ref_module ~= symbol_module then cross_module_refs = cross_module_refs + 1 end
        end
    end

    return #references > 0 and (cross_module_refs / #references) or 0.0
end

function M.analyze_parameter_coupling(symbol_info, outgoing_calls)
    -- Simplified parameter analysis
    local param_count = 0
    local complex_params = 0

    for _, call in ipairs(outgoing_calls) do
        if call.text then
            -- Count parameters by counting commas + 1
            local comma_count = select(2, call.text:gsub(",", ""))
            param_count = param_count + comma_count + 1

            -- Check for complex parameter patterns
            if call.text:match("%{") or call.text:match("%[") or call.text:match("%.") then
                complex_params = complex_params + 1
            end
        end
    end

    local base_coupling = #outgoing_calls > 0 and (param_count / (#outgoing_calls * 3)) or 0.0
    local complexity_coupling = #outgoing_calls > 0 and (complex_params / #outgoing_calls) or 0.0

    return math.min(1.0, (base_coupling + complexity_coupling) / 2.0)
end

function M.analyze_shared_data(symbol_info, references)
    -- Analyze if references suggest shared data access
    local shared_access_patterns = 0

    for _, ref in ipairs(references) do
        if ref.text then
            -- Look for patterns suggesting shared data access
            if ref.text:match("%.") or ref.text:match("%[") or ref.text:match("get") or ref.text:match("set") then
                shared_access_patterns = shared_access_patterns + 1
            end
        end
    end

    return #references > 0 and (shared_access_patterns / #references) or 0.0
end

function M.analyze_return_coupling(symbol_info)
    -- Analyze return type complexity (simplified)
    if not symbol_info.text then return 0.0 end

    -- Look for complex return patterns in function signature
    local return_complexity = 0.0

    if symbol_info.type == "function" then
        -- Simple heuristics for return complexity
        if symbol_info.context then
            for _, ctx in ipairs(symbol_info.context) do
                if ctx.text and (ctx.text:match("return") or ctx.text:match("=>")) then
                    if ctx.text:match("%{") or ctx.text:match("%[") then return_complexity = return_complexity + 0.3 end
                end
            end
        end
    end

    return math.min(1.0, return_complexity)
end

function M.analyze_control_flow(symbol_info)
    -- Analyze control flow complexity
    if not symbol_info.context then return 0.0 end

    local complexity_indicators = 0
    local total_context_lines = 0

    for _, ctx in ipairs(symbol_info.context) do
        if ctx.text then
            total_context_lines = total_context_lines + 1

            -- Count control flow indicators
            if
                ctx.text:match("if")
                or ctx.text:match("else")
                or ctx.text:match("for")
                or ctx.text:match("while")
                or ctx.text:match("switch")
                or ctx.text:match("try")
                or ctx.text:match("catch")
            then
                complexity_indicators = complexity_indicators + 1
            end
        end
    end

    return total_context_lines > 0 and (complexity_indicators / total_context_lines) or 0.0
end

function M.analyze_call_depth(incoming_calls, outgoing_calls)
    local incoming_depth = #incoming_calls
    local outgoing_depth = #outgoing_calls

    -- Normalize depth scores
    local in_score = math.min(1.0, incoming_depth / 5.0)
    local out_score = math.min(1.0, outgoing_depth / 5.0)

    return (in_score + out_score) / 2.0
end

function M.analyze_exception_coupling(symbol_info)
    -- Simplified exception analysis
    if not symbol_info.context then return 0.0 end

    local exception_patterns = 0
    for _, ctx in ipairs(symbol_info.context) do
        if ctx.text then
            if
                ctx.text:match("throw")
                or ctx.text:match("catch")
                or ctx.text:match("except")
                or ctx.text:match("finally")
            then
                exception_patterns = exception_patterns + 1
            end
        end
    end

    return math.min(1.0, exception_patterns / 3.0)
end

function M.analyze_internal_access(symbol_info, references)
    -- Check for internal access patterns
    local internal_access = 0

    for _, ref in ipairs(references) do
        if ref.text then
            -- Look for private/internal access patterns
            if ref.text:match("_") or ref.text:match("private") or ref.text:match("internal") then
                internal_access = internal_access + 1
            end
        end
    end

    return #references > 0 and (internal_access / #references) or 0.0
end

function M.analyze_modification_patterns(symbol_info, references)
    -- Analyze patterns that suggest modification
    local modification_patterns = 0

    for _, ref in ipairs(references) do
        if ref.text then
            if ref.text:match("=") or ref.text:match("set") or ref.text:match("update") or ref.text:match("modify") then
                modification_patterns = modification_patterns + 1
            end
        end
    end

    return #references > 0 and (modification_patterns / #references) or 0.0
end

function M.get_module_name(file_path)
    if not file_path then return "unknown" end

    -- Extract module name from file path
    local path_parts = vim.split(file_path, "/", { plain = true })
    if #path_parts >= 2 then
        return path_parts[#path_parts - 1] -- Parent directory
    end
    return "root"
end

function M.classify_coupling(coupling_score)
    if coupling_score >= COUPLING_THRESHOLDS.HIGH then
        return "high"
    elseif coupling_score >= COUPLING_THRESHOLDS.MEDIUM then
        return "medium"
    else
        return "low"
    end
end

function M.get_coupling_factors(structural, data, control, content)
    local factors = {}

    if structural > 0.6 then table.insert(factors, "High structural dependency") end
    if data > 0.6 then table.insert(factors, "Complex data coupling") end
    if control > 0.6 then table.insert(factors, "Tight control flow coupling") end
    if content > 0.6 then table.insert(factors, "Internal content access") end

    return factors
end

function M.get_cache_key(symbol_info, references, definitions, incoming_calls, outgoing_calls)
    local key_parts = {
        symbol_info.text or "unknown",
        symbol_info.file or "unknown",
        tostring(symbol_info.line or 0),
        tostring(#(references or {})),
        tostring(#(definitions or {})),
        tostring(#(incoming_calls or {})),
        tostring(#(outgoing_calls or {})),
    }
    return table.concat(key_parts, ":")
end

function M.cache_coupling_result(cache_key, metrics)
    if vim.tbl_count(coupling_cache) >= MAX_CACHE_SIZE then M.clear_cache() end

    coupling_cache[cache_key] = {
        metrics = metrics,
        timestamp = os.time(),
    }
end

function M.clear_cache() coupling_cache = {} end

function M.get_coupling_metrics(symbol_info, references, definitions, incoming_calls, outgoing_calls)
    if not symbol_info or not symbol_info.text then
        return {
            structural = 0.0,
            data = 0.0,
            control = 0.0,
            content = 0.0,
            total = 0.0,
            classification = "none",
            factors = {},
        }
    end

    local cache_key = M.get_cache_key(symbol_info, references, definitions, incoming_calls, outgoing_calls)
    if coupling_cache[cache_key] then return coupling_cache[cache_key].metrics end

    references = references or {}
    definitions = definitions or {}
    incoming_calls = incoming_calls or {}
    outgoing_calls = outgoing_calls or {}

    local structural = M.analyze_structural_coupling(symbol_info, references, definitions)
    local data = M.analyze_data_coupling(symbol_info, references, outgoing_calls)
    local control = M.analyze_control_coupling(symbol_info, incoming_calls, outgoing_calls)
    local content = M.analyze_content_coupling(symbol_info, references)

    local total = (structural * COUPLING_WEIGHTS.STRUCTURAL)
        + (data * COUPLING_WEIGHTS.DATA)
        + (control * COUPLING_WEIGHTS.CONTROL)
        + (content * COUPLING_WEIGHTS.CONTENT)

    local metrics = {
        structural = structural,
        data = data,
        control = control,
        content = content,
        total = math.min(1.0, total),
        classification = M.classify_coupling(total),
        factors = M.get_coupling_factors(structural, data, control, content),
    }

    M.cache_coupling_result(cache_key, metrics)

    return metrics
end

function M.get_coupling_summary(metrics_list)
    if not metrics_list or #metrics_list == 0 then
        return {
            average = 0.0,
            max = 0.0,
            min = 0.0,
            high_count = 0,
            medium_count = 0,
            low_count = 0,
        }
    end

    local total = 0.0
    local max_coupling = 0.0
    local min_coupling = 1.0
    local high_count = 0
    local medium_count = 0
    local low_count = 0

    for _, metrics in ipairs(metrics_list) do
        local coupling = metrics.total or 0.0
        total = total + coupling
        max_coupling = math.max(max_coupling, coupling)
        min_coupling = math.min(min_coupling, coupling)

        if coupling >= COUPLING_THRESHOLDS.HIGH then
            high_count = high_count + 1
        elseif coupling >= COUPLING_THRESHOLDS.MEDIUM then
            medium_count = medium_count + 1
        else
            low_count = low_count + 1
        end
    end

    return {
        average = total / #metrics_list,
        max = max_coupling,
        min = min_coupling,
        high_count = high_count,
        medium_count = medium_count,
        low_count = low_count,
        total_analyzed = #metrics_list,
    }
end

function M.get_cache_stats()
    return {
        size = vim.tbl_count(coupling_cache),
        max_size = MAX_CACHE_SIZE,
    }
end

return M
