function resizejson(json_in, json_out, target_shape)
    % Reads a JSON file, reshapes numeric arrays in its fields to target_shape,
    % and writes the modified JSON to a new file with custom formatting.
    
    % Open the input JSON file for reading and parse it into a MATLAB
    % struct
    fid = fopen(json_in, 'r');
    raw = fread(fid, inf, 'uint8=>char')';  % Read file content as char array
    fclose(fid);
    data = jsondecode(raw);

    % Get the names of each field in the JSON (as struct fields)
    fields = fieldnames(data);

    % Ensure target_shape is a row vector (1 x n)
    target_shape = [1 target_shape];

    % Loop over all fields in the JSON object
    for f = 1:length(fields)
        field = fields{f};
        arr = data.(field);
        % Loop over all entries (presumed to be cell arrays)
        for i = 1:numel(arr)
            entry = arr{i};
            if ~isempty(entry)
                % Only process if the entry is a numeric vector of desired total size
                if isnumeric(entry) && isvector(entry) && numel(entry) == prod(target_shape)
                    % Convert the numeric vector to a custom JSON-style string
                    arr{i} = array_to_bracket_string(entry, target_shape);
                end
            end
        end

        % Assign the modified array back to the struct field
        data.(field) = arr;
    end

    % Encode the MATLAB struct back into a JSON string
    json_str = jsonencode(data);
    
    % Replace floating point numbers ending with .0 to integers ("12.0" -> "12")
    json_str = regexprep(json_str, '(\d+)\.0', '$1');

    % Write (intermediate) JSON string to a temporary file
    fid = fopen("converted.json", 'w');
    fwrite(fid, json_str, 'char');
    fclose(fid);

    % Apply custom pretty-printing/formatting and write to output file
    customjsonstyle("converted.json", json_out)

    % Clean up the temporary file
    delete("converted.json")
end


function customjsonstyle(infile, outfile)
    % Function to pretty-print or custom format a JSON file
    % Read the single-line JSON string from infile
    fid = fopen(infile, 'r');
    json_str = fread(fid, inf, 'uint8=>char')';
    fclose(fid);

    out_str = '';   % Initialize output string
    apstack = 0;    % Track quotes (to handle string context)
    stack = 0;      % Track array bracket nesting level
    i = 1;          % String position
    len = length(json_str);

    while i <= len
        c = json_str(i);

        % Handle double quotes for string quotation
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

        % Condition 1: Opening of array at root (stack==0)
        if c == '['
            if stack == 0
                out_str = [out_str newline c newline];  % Newline before and after bracket
            else
                out_str = [out_str c];  % Otherwise, write normally
            end
            stack = stack + 1;

        % Condition 2: Closing bracket (array)
        elseif c == ']'
            stack = stack - 1;
            out_str = [out_str c];
            if stack == 0
                % When closing top-level array, add newline before last bracket
                out_str = [out_str(1:end-1) newline c newline];
            end
        % Add newline after commas at stack==1
        elseif c == "," && stack == 1
            out_str = [out_str ',' newline];
        else
            % Otherwise, append character to output string
            out_str = [out_str c];
        end
        i = i + 1;
    end

    % Write the formatted JSON string to the output file
    fid = fopen(outfile, 'w');
    fwrite(fid, out_str, 'char');
    fclose(fid);
end