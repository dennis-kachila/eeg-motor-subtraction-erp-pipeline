% mexSLOAD can load many different biosig data formats 
%
%   Usage of mexSLOAD:
%	[s,HDR]=mexSLOAD(f)
%	[s,HDR]=mexSLOAD(f,chan)
%		chan must be sorted in ascending order
%	[s,HDR]=mexSLOAD(f,chan,'...')
%	[s,HDR]=mexSLOAD(f,chan,'OVERFLOWDETECTION:ON')
%	[s,HDR]=mexSLOAD(f,chan,'OVERFLOWDETECTION:OFF')
%	[s,HDR]=mexSLOAD(f,chan,'UCAL:ON')
%	[s,HDR]=mexSLOAD(f,chan,'UCAL:OFF')
%	[s,HDR]=mexSLOAD(f,chan,'OUTPUT:SINGLE')
%	[s,HDR]=mexSLOAD(f,chan,'TARGETSEGMENT:<N>')
%	[s,HDR]=mexSLOAD(f,chan,'SWEEP',[NE, NG, NS])
%	[s,HDR]=mexSLOAD(f,chan,'--free-text-event-limiter',';')
%   Input:
%	f	filename
%	chan	list of selected channels; 0=all channels [default]
%	UCAL	ON: do not calibrate data; default=OFF
%	OVERFLOWDETECTION	default = ON
%		ON: values outside dynamic range are not-a-number (NaN)
%	TARGETSEGMENT:<N>
%		select segment <N> in multisegment files (like Nihon-Khoden), default=1
%		It has no effect for other data formats.
%	[NE, NG, NS] are the number of the experiment, the series and the sweep, resp. for sweep selection in HEKA/PatchMaster files. (0 indicates all)
%		 examples: [1,2,3] the 3rd sweep from the 2nd series of experiment 1; [1,3,0] selects all sweeps from experiment=1, series=3. 
%
%	'--free-text-event-limiter',';' : free text limited by first ";", remainder is ignored.
%		This can help to reduce the number of distinct free text events.
%
%   Output:
%	s	signal data, each column is one channel
%	HDR	header structure
%

