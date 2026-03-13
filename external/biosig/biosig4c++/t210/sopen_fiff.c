/*
    sandbox is used for development and under constraction work
    The functions here are either under construction or experimental.
    The functions will be either fixed, then they are moved to another place;
    or the functions are discarded. Do not rely on the interface in this function

    Copyright (C) 2025 Alois Schloegl <alois.schloegl@gmail.com>
    This file is part of the "BioSig for C/C++" repository
    (biosig4c++) at http://biosig.sf.net/

    BioSig is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <assert.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#include "../biosig.h"

#define min(a,b)        (((a) < (b)) ? (a) : (b))
#define max(a,b)        (((a) > (b)) ? (a) : (b))


#ifdef __cplusplus
extern "C" {
#endif


uint16_t fiff_physdimcode(int32_t unit) {
	switch (unit) {
	case 0: return 0;
	case 1: return PhysDimCode("m");
	case 2: return PhysDimCode("kg");
	case 3: return PhysDimCode("s");
	case 4: return PhysDimCode("A");
	case 5: return PhysDimCode("K");
	case 6: return PhysDimCode("mol");
	case 7: return PhysDimCode("rad");
	case 8: return PhysDimCode("sr");
	case 9: return PhysDimCode("cd");

	case 101: return PhysDimCode("Hz");
	case 102: return PhysDimCode("N");
	case 103: return PhysDimCode("Pa");
	case 104: return PhysDimCode("J");
	case 105: return PhysDimCode("W");
	case 106: return PhysDimCode("C");
	case 107: return PhysDimCode("V");
	case 108: return PhysDimCode("F");
	case 109: return PhysDimCode("Ohm");
	case 110: return PhysDimCode("S");

	case 111: return PhysDimCode("Vs");
	case 112: return PhysDimCode("T");
	case 113: return PhysDimCode("H");
	case 114: return PhysDimCode("°C");
	case 115: return PhysDimCode("lm");
	case 116: return PhysDimCode("Lx");

	case 201: return PhysDimCode("T/m");
	case 202: return PhysDimCode("Am");
	}
	return 0;
}

gdftime_t julian2gdftype(void* val) {
	// https://github.com/mne-tools/mne-python/blob/main/mne/utils/numerics.py
	return floor(ldexp(beu32p(val)-2440588+719529.5, 32));
}

int sopen_fiff_read(HDRTYPE* hdr) {
	/* TODO: implement FIFF support
	        define all fields in hdr->....
		currently only the first hdr->HeadLen bytes are stored in
		hdr->AS.Header, all other fields still need to be defined.
	*/

	size_t count = hdr->HeadLen;
#if defined(_WIN32) || !defined(_SYS_STAT_H) || defined(ZLIB_H)
	// stat(...) can not be used in windows because including <sys/stat.h> causes a namespace conflict with sopen
	while (!feof(hdr->FILE.FID)) {
		void *ptr = realloc(hdr->AS.Header, count*2);
		if (ptr==NULL) {
			biosigERROR(hdr, B4C_MEMORY_ALLOCATION_FAILED, "FIFF: memory allocation");
			return -1;
		}
		hdr->AS.Header = (uint8_t*)ptr;
		count += ifread(hdr->AS.Header+count, 1, count, hdr);
	}
	fclose(hdr->FILE.FID);
	hdr->HeadLen = count;
	hdr->AS.Header = (uint8_t*)realloc(hdr->AS.Header, count+1);
#else
	struct stat FileBuf;
	stat(hdr->FileName,&FileBuf);
	void *ptr = realloc(hdr->AS.Header, FileBuf.st_size);
	if (ptr==NULL) {
		biosigERROR(hdr, B4C_MEMORY_ALLOCATION_FAILED, "FIFF: memory allocation");
		return -1;
	}
	hdr->AS.Header = (uint8_t*)ptr;
	if (!feof(hdr->FILE.FID) )
		count += ifread(hdr->AS.Header+count, 1, FileBuf.st_size-count, hdr);

	fclose(hdr->FILE.FID);
	hdr->HeadLen = count;
	if (count != FileBuf.st_size)
		biosigERROR(hdr, B4C_FORMAT_UNSUPPORTED, "FIFF: read error");
#endif

	if (VERBOSE_LEVEL>7) fprintf(stdout,"#  %s  line %d: %s(....) \n", __FILE__, __LINE__, __func__);

	char* firstname=NULL;
	char* middlename=NULL;
	char* surname=NULL;
	int nn1=0, nn2=0, nn3=0;
	float lowpass=0.0, highpass=0.0;
	uint32_t pos = 0, NumTags=0;
	int32_t* badchanlist=NULL;
	int numbadchan=0;
	while (1) {
		// fifftag_t* ct = (fifftag_t*)(hdr->AS.Header+pos);
		NumTags++;
		int32_t kind = bei32p(hdr->AS.Header+pos);
		int32_t type = bei32p(hdr->AS.Header+pos+4);
		int32_t size = bei32p(hdr->AS.Header+pos+8);
		int32_t next = bei32p(hdr->AS.Header+pos+12);
		uint8_t *val = hdr->AS.Header+(pos+16);

	if (VERBOSE_LEVEL>8) fprintf(stdout,"# FIFFTAG %d: %d, %08x, %d, %08x :\t%08x %9d %s  \n", NumTags, kind, type, size, next, be32toh(*(uint32_t*)val), be32toh(*(uint32_t*)val), (char*)val);

		switch (kind) {
		case 107: // unused
		case 108: // nop
			break;

		case 200: hdr->NS = beu32p(val);
			hdr->CHANNEL = (CHANNEL_TYPE*) realloc(hdr->CHANNEL, hdr->NS * sizeof(CHANNEL_TYPE));
			break;
		case 201: hdr->SampleRate = bef32p(val); break;
		case 203: {
			int32_t scanNo   = bei32p(val);
			int32_t logNo    = bei32p(val+4);
			int32_t chankind = bei32p(val+8);
			float range      = bef32p(val+12);
			float cal        = bef32p(val+16);
			int32_t coil_type = bei32p(val+20);
			float r1         = bef32p(val+24);
			float r2         = bef32p(val+28);
			float r3         = bef32p(val+32);

			uint32_t unit    = beu32p(val+72);
			uint32_t unitm   = beu32p(val+76);

			CHANNEL_TYPE* hc = hdr->CHANNEL + scanNo;
			hc->Cal = range * cal * pow(10.0, unitm);
			hc->Off = 0.0;
			hc->OnOff = 1;
			hc->PhysDimCode = fiff_physdimcode(unit);
			hc->SPR      = hdr->SPR;
			hc->GDFTYP   = 3;
			hc->LowPass  = lowpass;
			hc->HighPass = highpass;
			break;
		}
		case 204: hdr->T0  = julian2gdftype(val); break;
		case 208: // first_sample
			break;
		case 209: // last_sample
			break;
		case 219: lowpass  = bef32p(val); break;
		case 220: numbadchan  = size/4;
			  badchanlist = (int32_t*)val;
			  break;

		case 223: highpass = bef32p(val); break;
		case 228: hdr->SPR = beu32p(val); break;


		case 401: nn1=size; firstname=(char*)val; break;
		case 402: nn2=size; middlename=(char*)val; break;
		case 403: nn3=size; surname=(char*)val; break;
		case 404: hdr->Patient.Birthday   = julian2gdftype(val); break;
		case 405: hdr->Patient.Sex        = beu32p(val); break;
		case 406: hdr->Patient.Handedness = beu32p(val); break;
		case 407: hdr->Patient.Weight     = lef32p(val); break;
		case 408: hdr->Patient.Height     = lef32p(val); break;
		// case 409: break;
		case 410: strncpy(hdr->Patient.Id, (char*)val, MAX_LENGTH_PID+1); break;

		default:
	if (VERBOSE_LEVEL>4) fprintf(stdout,"# FIFFTAG %d ignored: %d, %08x, %d, %08x :\t%08x %9d %s  \n", NumTags, kind, type, size, next, be32toh(*(uint32_t*)val), be32toh(*(uint32_t*)val), (char*)val);

		;
		}

		//
		if (next==0) pos += size+16;
		else if (next == -1) break;
		else pos = next;
	}

	if (!hdr->FLAG.ANONYMOUS) {
		strncpy(hdr->Patient.Name, surname, min(nn3,MAX_LENGTH_NAME));
		if (nn3 < MAX_LENGTH_NAME) {
			hdr->Patient.Name[nn3] = 0x1f;
			strncpy(hdr->Patient.Name+nn3+1, firstname, min(nn1,MAX_LENGTH_NAME-nn3-1));
		}
		if (nn3+nn1+1 < MAX_LENGTH_NAME) {
			hdr->Patient.Name[nn3+1+nn1] = 0x1f;
			strncpy(hdr->Patient.Name+nn3+nn1+2, middlename, min(nn2,MAX_LENGTH_NAME-nn3-2-nn1));
		}
		hdr->Patient.Name[min(nn1+nn2+nn3+2,MAX_LENGTH_NAME)]=0;
	}
	fflush(stdout);

	/* define channel headers */
	hdr->CHANNEL = (CHANNEL_TYPE*) realloc(hdr->CHANNEL, hdr->NS * sizeof(CHANNEL_TYPE));
	for (int k=0; k < numbadchan; k++)
		hdr->CHANNEL[bei32p(badchanlist+k)].OnOff = 0;
	for (int k = 0; k < hdr->NS; k++) {
		CHANNEL_TYPE *hc = hdr->CHANNEL + k;
	}

	/* define event table */
	hdr->EVENT.N = 0;
	//reallocEventTable(hdr, 0);

	/* report status header and return */
	hdr2ascii(hdr,stdout,4);
	biosigERROR(hdr, B4C_FORMAT_UNSUPPORTED, "FIFF support not completed");
	return 0;
}



#ifdef __cplusplus
}
#endif

