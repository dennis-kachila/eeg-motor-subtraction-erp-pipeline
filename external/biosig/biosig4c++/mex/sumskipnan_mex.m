% SUMSKIPNAN_MEX is a speedier implementation of, and used by SUMSKIPNAN
% SUMSKIPNAN adds all non-NaN values. 
%
% All NaN's are skipped; NaN's are considered as missing values. 
% SUMSKIPNAN of NaN's only  gives O; and the number of valid elements is return. 
% SUMSKIPNAN is also the elementary function for calculating 
% various statistics (e.g. MEAN, STD, VAR, RMS, MEANSQ, SKEWNESS, 
% KURTOSIS, MOMENT, STATISTIC etc.) from data with missing values.  
% SUMSKIPNAN implements the DIMENSION-argument for data with missing values.
% Also the second output argument return the number of valid elements (not NaNs) 
% 
% Y = sumskipnan(x [,DIM])
% [Y,N,SSQ] = sumskipnan(x [,DIM])
% [...] = sumskipnan(x, DIM, W)
% 
% x	input data 	
% DIM	dimension (default: [])
%	empty DIM sets DIM to first non singleton dimension	
% W	weight vector for weighted sum, numel(W) must fit size(x,DIM)
% Y	resulting sum
% N	number of valid (not missing) elements
% SSQ	sum of squares
%
% the function FLAG_NANS_OCCURED() returns whether any value in x
%  is a not-a-number (NaN)
%
% features:
% - can deal with NaN's (missing values)
% - implements dimension argument. 
% - computes weighted sum 
% - compatible with Matlab and Octave
%
% see also: FLAG_NANS_OCCURED, SUM, NANSUM, MEAN, STD, VAR, RMS, MEANSQ, 
%      SSQ, MOMENT, SKEWNESS, KURTOSIS, SEM


