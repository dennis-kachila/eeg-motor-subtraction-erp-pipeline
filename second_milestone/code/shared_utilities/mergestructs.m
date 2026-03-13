% easily merge structs that have 100% different fieldnames

function myStruct = mergestructs(x,y)

myStruct = cell2struct([struct2cell(x);struct2cell(y)],[fieldnames(x);fieldnames(y)]);