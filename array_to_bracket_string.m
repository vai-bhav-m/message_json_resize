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