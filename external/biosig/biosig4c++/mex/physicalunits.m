% PHYSICALUNITS converts PhysDim inte PhysDimCode and vice versa
% according to Annex A of FEF Vital Signs Format [1] 
%
%   HDR = physicalunits(HDR); 
%	adds HDR.PhysDim or HDR.PhysDimCode, if needed 
%
%   PhysDim = physicalunits(PhysDimCode);
%	converts Code of PhysicalUnits into descriptive physical units
%
%   PhysDimCode = physicalunits(PhysDim);
%	converts descriptive units into Code for physical units.
%
%   [..., scale] = physicalunits(...);
%	scale contains the scaling factor of the decimal prefix
%
% Reference(s):
% ISO/IEEE 11073-10101:2004
%   Health Informatics - Point-of-care medical device communications - Part 10101: Nomenclature
%   p.62-75. Table A.6.3: Vital signs units of measurements
%
