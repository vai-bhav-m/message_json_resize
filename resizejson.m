function resizejson(json_in, json_out, target_shape)
    fid = fopen(json_in, 'r');
    raw = fread(fid, inf, 'uint8=>char')';
    fclose(fid);
    data = jsondecode(raw);

    fields = fieldnames(data);
    target_shape = [1 target_shape];

    for f = 1:length(fields)
        field = fields{f};
        % if ~ismember(field, ["M", "Min", "Mout"])
        %     continue
        % end

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

    json_str = jsonencode(data);
    
    % Cleaned up formatting
    json_str = regexprep(json_str, '(\d+)\.0', '$1');
    fid = fopen("converted.json", 'w');
    fwrite(fid, json_str, 'char');
    fclose(fid);
    customjsonstyle("converted.json", json_out)
end


function customjsonstyle(infile, outfile)
    % Read the single-line JSON string
    fid = fopen(infile, 'r');
    json_str = fread(fid, inf, 'uint8=>char')';
    fclose(fid);

    out_str = '';
    apstack = 0;
    stack = 0;
    i = 1;
    len = length(json_str);

    while i <= len
        c = json_str(i);
        
        if c == '"' 
            if isstrprop(json_str(i+1), 'alphanum')
                apstack = 1;
            elseif apstack == 1
                apstack = 0;
            else
                i = i+1;
                continue
            end
        end

        % Condition 1: stack goes from 0 to 1 (before writing '[')
        if c == '['
            if stack == 0
                out_str = [out_str newline c newline];
            
            else
                out_str = [out_str c];
            end
            stack = stack + 1;
            
        % Condition 2: stack goes from 1 to 0 (after writing ']')
        elseif c == ']'
            stack = stack - 1;
            out_str = [out_str c];
            if stack == 0
                out_str = [out_str(1:end-1) newline c newline];
            end
        elseif c == "," && stack == 1
            out_str = [out_str ',' newline];
        else
            out_str = [out_str c];
        end
        i = i + 1;
    end

    % Write to output file
    fid = fopen(outfile, 'w');
    fwrite(fid, out_str, 'char');
    fclose(fid);
end

function str = array_to_bracket_string(arr, dims)
    % array_to_bracket_string Recursively partitions arr and outputs nested brackets
    %   arr: 1D numeric array
    %   dims: vector of dimensions, e.g. [2,3,2,3]

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