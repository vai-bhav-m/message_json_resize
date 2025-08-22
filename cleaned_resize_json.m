function cleaned_resize_json(json_in, json_out, target_shape)
% RESIZEJSON Reshapes specific fields in a JSON file and writes a custom-formatted output.
%   resizejson(json_in, json_out, target_shape)
%   - json_in: Input JSON filename
%   - json_out: Output JSON filename
%   - target_shape: Desired shape for arrays (e.g. [2,3,4])

    % Read and decode input JSON
    raw = fileread(json_in);
    data = jsondecode(raw);

    % Fields to process
    fields = fieldnames(data);
    target_shape = [1 target_shape];  % Ensure row vector

    for f = 1:length(fields)
        field = fields{f};
        if ~ismember(field, ["M", "Min", "Mout"])
            continue
        end

        arr = data.(field);
        for i = 1:numel(arr)
            entry = arr{i};
            if ~isempty(entry)
                if isnumeric(entry) && isvector(entry) && numel(entry) == prod(target_shape)
                    arr{i} = array_to_bracket_string(entry, target_shape);
                end
            end
        end
        data.(field) = arr;
    end

    % Encode back to JSON and clean up formatting
    json_str = jsonencode(data);
    json_str = regexprep(json_str, '(\d+)\.0', '$1'); % Remove trailing .0

    % Write to a temporary file for pretty-printing
    temp_file = [tempname, '.json'];
    fid = fopen(temp_file, 'w');
    fwrite(fid, json_str, 'char');
    fclose(fid);

    % Find 1D array fields
    oned_fields = find_1d_fields(data);

    % Apply custom pretty-printing and save to output
    customjsonstyle(temp_file, json_out, oned_fields);

    % Clean up temporary file
    delete(temp_file);
end

function oned_fields = find_1d_fields(data)
    % Returns a cell array of field names whose value is a 1D array (numeric or logical)
    oned_fields = {};
    fields = fieldnames(data);
    for i = 1:length(fields)
        field = fields{i};
        val = data.(field);
        if isnumeric(val) || islogical(val)
            if isvector(val)
                oned_fields{end+1} = field;
            end
        elseif iscell(val)
            % Check if cell array of scalars (not nested)
            try
                arr = cell2mat(val);
                if isvector(arr)
                    oned_fields{end+1} = field;
                end
            end
        end
    end
end

function customjsonstyle(infile, outfile, oned_fields)
% CUSTOMJSONSTYLE Applies custom pretty-printing to JSON arrays at the top level,
% but keeps 1D arrays in a single line.

    raw = fileread(infile);

    out_str = '';
    stack = 0;      % Tracks array nesting level
    in_string = false; % Tracks if inside a string
    i = 1;
    len = length(raw);

    current_field = '';
    field_mode = 'none'; % 'none', 'maybe', 'reading'
    field_buffer = '';
    top_level_array_field = '';
    is_top_level_1d = false;

    while i <= len
        c = raw(i);

        % Handle string context
        if c == '"' && (i == 1 || raw(i-1) ~= '\')
            in_string = ~in_string;
            if in_string
                if field_mode == "none"
                    field_mode = "maybe";
                    field_buffer = '';
                elseif field_mode == "maybe"
                    field_mode = "reading";
                end
            else
                if field_mode == "reading"
                    current_field = field_buffer;
                    field_mode = "none";
                end
            end
            out_str = [out_str c];
            i = i + 1;
            continue
        end

        % Accumulate field name when reading
        if in_string && field_mode == "reading"
            field_buffer = [field_buffer c];
            out_str = [out_str c];
            i = i + 1;
            continue
        end

        % Detect colon after field name (e.g., "y":)
        if ~in_string && field_mode == "none" && c == ':' && ~isempty(current_field)
            % Next non-space, non-colon char that is '[' marks start of array for this field
            j = i + 1;
            while j <= len && isspace(raw(j))
                j = j + 1;
            end
            if j <= len && raw(j) == '['
                top_level_array_field = current_field;
                is_top_level_1d = ismember(top_level_array_field, oned_fields);
            else
                top_level_array_field = '';
                is_top_level_1d = false;
            end
        end

        % Handle entering/leaving arrays
        if ~in_string && c == '['
            stack = stack + 1;
            if stack == 1
                if is_top_level_1d
                    out_str = [out_str c];
                else
                    out_str = [out_str newline c newline];
                end
            else
                out_str = [out_str c];
            end
            i = i + 1;
            continue
        elseif ~in_string && c == ']'
            if stack == 1
                if is_top_level_1d
                    out_str = [out_str c];
                else
                    out_str = [out_str c newline];
                end
                % Finished top-level array, clear context
                top_level_array_field = '';
                is_top_level_1d = false;
            else
                out_str = [out_str c];
            end
            stack = stack - 1;
            i = i + 1;
            continue
        end

        % Newline after ',' if at top-level array and not 1D
        if ~in_string && c == ',' && stack == 1 && ~is_top_level_1d
            out_str = [out_str ',' newline];
            i = i + 1;
            continue
        end

        % Normal character
        out_str = [out_str c];
        i = i + 1;
    end

    % Write to output file
    fid = fopen(outfile, 'w');
    fwrite(fid, out_str, 'char');
    fclose(fid);
end

function str = array_to_bracket_string(arr, dims)
% ARRAY_TO_BRACKET_STRING Recursively formats a numeric array as nested brackets.
%   arr: 1D numeric array
%   dims: vector of dimensions, e.g. [2,3,4]

    if isempty(dims)
        str = num2str(arr);
        return;
    end

    n = dims(1);
    rest_dims = dims(2:end);
    chunk_size = numel(arr) / n;

    if mod(numel(arr), n) ~= 0
        error('Cannot evenly divide array of length %d into %d parts.', numel(arr), n);
    end

    str = '[';
    for i = 1:n
        idx_start = round((i-1)*chunk_size) + 1;
        idx_end = round(i*chunk_size);
        subarr = arr(idx_start:idx_end);
        str = [str, array_to_bracket_string(subarr, rest_dims)];
        if i < n
            str = [str, ','];
        end
    end
    str = [str, ']'];
end