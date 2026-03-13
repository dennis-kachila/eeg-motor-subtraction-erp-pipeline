####### Demo for Python interface to BioSig" #####################
###
###  Copyright (C) 2016-2025 Alois Schloegl <alois.schloegl@gmail.com>
###  This file is part of the "BioSig for Python" repository
###  at http://biosig.sf.net/
###
##############################################################

# download and extract 
#   http://www.biosemi.com/download/BDFtestfiles.zip 
# into /tmp/
# then run this demo 
#
# on linux you can run instead  
#   make test 

import sys
import biosig
import numpy as np
import matplotlib.pyplot as plt
import json

def printf(format, *args):
    sys.stdout.write(format % args)


## read header
# example from https://github.com/user-attachments/files/19322137/20250314_S5_C1_CellChar.zip
FILENAME="20250314_S5_C1_CellChar.cfs"
HDR=biosig.header(FILENAME)
#print HDR
## extracting header fields
H=json.loads(HDR)
print(H["Filename"])
print(H["TYPE"])
print(H["Samplingrate"])
Fs=H["Samplingrate"]
NS=len(H["CHANNEL"])	# number of channels
T0=H["StartOfRecording"]
print(Fs,NS,T0)

### read and display data ###
A=biosig.data(FILENAME)
NS=np.size(A,1)		# number of channels

fig = plt.figure()
ax  = fig.add_subplot(111)
h   = plt.plot(np.arange(np.size(A,0))/H["Samplingrate"],A[:,0]);
ax.set_xlabel('time [s]')
# plt.show()

rec={"dt" : 1000.0/Fs, "xunits": "ms", "channel" : [] }
for chan in list(range(NS)):
	name=H["CHANNEL"][chan]["Label"]	# name of channel
	unit=H["CHANNEL"][chan]["PhysicalUnit"]	# units of channel
	printf("#%d:\t%s\t[%s]\n", chan, name, unit)

### get all sweeps, breaks-in-recording
selpos=[0]
if "EVENT" in H:
    for k in list(range(len(H["EVENT"]))):
        if (H["EVENT"][k]["TYP"] == '0x7ffe'):
            selpos.append(round(H["EVENT"][k]["POS"]*H["Samplingrate"]))

selpos.append(np.size(A,0))

### data from channel m and sweep c can be obtained by:
m=0	# channel
c=0	# segment, trace, sweep number
d = A[selpos[c]:selpos[c+1]-1,m]

### display data
fig, ax = plt.subplots(nrows=NS)
k=0
for m in list(range(NS)):
	for c in list(range(len(selpos)-1)):
		k = k+1
		d = np.asarray(A[selpos[c]:selpos[c+1]-1,m])
		ax[m].plot(np.arange(np.size(d,0))/H["Samplingrate"], d, 'r-')
		# TODO:
		# REC[m].append((c,d));
		# rec["channel"].append((chan, [{"name": name, "yunits": unit, 'section': []}]))
		# rec["channel"][m]["section"].insert(c,d)

plt.show()

