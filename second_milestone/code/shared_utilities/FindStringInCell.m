function myIndex = FindStringInCell(CellArray, Searchstring)

myIndex = find(cellfun(@(x)ischar(x)&&strcmp(x,Searchstring),CellArray));