% ACCOVF_MEX computes auto- and cross-correlation functions 
%       between two signals, up to lag. NaN's are considered
%       as missing values and are ignore. 
% 
%       The purpose is to speed up these computations (see also [1]): 
%	
%        for k = -maxlag : maxlag,
%                Rxy(k+1+maxlag) = mean(X(ixtrain-k) .* Y(ixtrain));
%                Rxx(k+1+maxlag) = mean(X(ixtrain-k) .* X(ixtrain));
%        end; 
%
%
% Usage:
%	[Sxx,Nxx,Sxy,Nxy,lag] = accovf_mex(X, Y, maxlag)
%	[Sxx,Nxx,Sxy,Nxy,lag] = accovf_mex(X, Y, maxlag, tix)
% Input:
%	X: 1st input channel
% 	Y: 2nd input channel 
% 	lag: maximum lag 
% 	tix: time indices used. This is useful for excluding periods
% 		that should be ignored (e.g. because of artifacts)
% Output: 
%      Sxx./Nxx : auto-covariance function
%      Sxy./Nxy : cross-covariance function
%
% References: 
% 
% [1] Xiaomin Zhang, Alois Schlögl, David Vandael, and Peter Jonas
%	MOD: A novel machine-learning optimal-filtering method for accurate and efficient detection of subthreshold synaptic events in vivo.
%	Journal of Neuroscience Methods, Volume 357, 1 June 2021, 109125.
%	here and supplement
%	https://www.sciencedirect.com/science/article/pii/S0165027021000601
%	https://doi.org/10.1016/j.jneumeth.2021.109125
% 

