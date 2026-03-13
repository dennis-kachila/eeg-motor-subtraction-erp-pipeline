% mexSOPEN opens a biosig file and reads its header/metainformation
%   
%   Usage of mexSOPEN:
%	HDR = mexSOPEN(f)
%   Input:
%	f	filename
%	... = mexSLOAD(f,'--free-text-event-limiter',';')
%	'--free-text-event-limiter',';' : free text limited by first ";", remainder is ignored.
%		This can help to reduce the number of distinct free text events.
%
%  Output:
%	HDR	header structure
%
%  see also: mexSLOAD, mexSSAVE, sload, sload4mod, sopen, sread, sclose
