# Reshaping Messages in JSONs

This repository contains code to reshape messages containing N-D arrays as data. ```input.json``` is a sample json with data like:
- M - message with 36-element 1D array - the goal is to resize it into size (2, 3, 2, 3)
- y - a boolean 1D array

## resizejson.m
Call the function on the MATLAB Command Line using the syntax below 
```
resizejson(input_path, output_path, target_shape)
```
For example, for our input.json
```
resizejson("input.json", "output.json", [2 3 2 3])
```
The code will go through each data field and resize the 1D arrays that have length 36 (2\*3\*2\*3) into the desired shape. It will then create a new json with these reshaped messages.

## array_to_bracket_string.m
```
array_to_bracket_string(arr, dims)
```
This function can be used to get an output string with brackets for a reshaped input array. For example, if called in this case:
```
array_to_bracket_string([1 2 3 4 5 6], [2 3])
```
the output will be
``` '[[1,2,3],[4,5,6]]' ```

