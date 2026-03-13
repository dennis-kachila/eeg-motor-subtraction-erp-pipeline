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

/*****
This implementation is based on the following references:
[1] http://www.biopac.com/Manuals/app_pdf/app156.pdf
[2] https://github.com/uwmadison-chm/bioread/raw/2e9a312342210c394b9bd3a6dbc220e1e9e89851/notes/acqknowledge_file_structure.pdf
 *****/

#define _GNU_SOURCE
#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <iconv.h>
#include <stdlib.h>
#include <string.h>

#include "../biosig.h"

#define min(a,b)        (((a) < (b)) ? (a) : (b))

#ifdef __cplusplus
extern "C" {
#endif


void sopen_acqbiopac_read(HDRTYPE* hdr) {


		size_t SectionTable[37];
		memset(SectionTable,0,sizeof(SectionTable));
		SectionTable[0] = 0;

		if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s (HeadLen=%d)\n", __FILE__, __LINE__, __func__, hdr->HeadLen);

		void *ptr = NULL;
		// revert (ab-) use of hdr->FILE.POS in gdffiletype
		size_t count = hdr->HeadLen;	// bytes of data actually read intp hdr->AS.Header
		uint32_t compressed=0;
		hdr->FILE.POS = 0;
		if ( hdr->FILE.LittleEndian ) {
			hdr->HeadLen    = leu32p(hdr->AS.Header+6);
			hdr->NS         = lei16p(hdr->AS.Header+10);
			hdr->SampleRate = 1000.0/lef64p(hdr->AS.Header+16);
			compressed      = leu32p(hdr->AS.Header+822);
		}
		else {
			hdr->HeadLen    = beu32p(hdr->AS.Header+6);
			hdr->NS         = bei16p(hdr->AS.Header+10);
			hdr->SampleRate = 1000.0/bef64p(hdr->AS.Header+16);
			compressed      = beu32p(hdr->AS.Header+822);
		}
		SectionTable[1] = hdr->HeadLen;

		if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s (HeadLen=%d) compressed=0x%x \n", __FILE__, __LINE__, __func__, hdr->HeadLen,compressed);

		if (hdr->VERSION>=124.0) {
			// Block Seq 2: Unknown
			ptr = hdr->AS.Header + hdr->HeadLen;
			uint32_t u32=( hdr->FILE.LittleEndian ? leu32p(ptr) : beu32p(ptr) );
			if (VERBOSE_LEVEL>8) fprintf(stdout,"Warning: %s (line %i) %s(...) v%f HeadLen=%d,0x%x) Block Seq=2,Type=unknown does not have 40 but %d bytes\n", \
					__FILE__, __LINE__, __func__, hdr->VERSION, hdr->HeadLen, hdr->HeadLen, u32);
			if ( u32 != 40 ) {
				biosigERROR(hdr, B4C_UNSPECIFIC_ERROR, "SOPEN(ACQ-READ): unsupported file format version - needs fixing of code.");
				return;
			}
			hdr->HeadLen+=40;
		}
		SectionTable[2] = hdr->HeadLen;

		/* defined in http://biopac.com/AppNotes/app156FileFormat/FileFormat.htm */

		// Block Seq 3: channel header
		// define channel specific header information
		hdr->NRec = 1;
		hdr->SPR  = 1;
		hdr->CHANNEL = (CHANNEL_TYPE*) realloc(hdr->CHANNEL, hdr->NS * sizeof(CHANNEL_TYPE));

		if (hdr->HeadLen+4 > count) {
			hdr->AS.Header = (uint8_t*) realloc(hdr->AS.Header, hdr->HeadLen+4);
			count += ifread(hdr->AS.Header+count, 1, hdr->HeadLen+4-count, hdr);
		}
		ptr = hdr->AS.Header+hdr->HeadLen;
		uint32_t lChanHeaderLen = (hdr->FILE.LittleEndian ? leu32p(ptr) : beu32p(ptr));
		hdr->HeadLen += lChanHeaderLen * hdr->NS;
		SectionTable[3] = hdr->HeadLen;

		// Block Seq 4: "foreign data section"
		ptr = hdr->AS.Header+hdr->HeadLen;
		if (hdr->VERSION > 60.0)
			hdr->HeadLen += hdr->FILE.LittleEndian ? leu32p(ptr) : beu32p(ptr);
		else if (hdr->VERSION > 35.0)
			hdr->HeadLen += hdr->FILE.LittleEndian ? leu16p(ptr) : beu16p(ptr);
		SectionTable[4] = hdr->HeadLen;

		// Block Seq 5: channel type header
		hdr->HeadLen += 4*hdr->NS;
		SectionTable[5] = hdr->HeadLen;
		if (hdr->HeadLen+4 > count) {
			hdr->AS.Header = (uint8_t*) realloc(hdr->AS.Header, hdr->HeadLen+4);
			count += ifread(hdr->AS.Header+count, 1, hdr->HeadLen+4-count, hdr);
		}

		if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s(...): Version=%g  HeadLen=%d compressed=%d\n", __FILE__, __LINE__, __func__, hdr->VERSION, hdr->HeadLen, compressed);

		// Block Seq 6: channel data
		hdr->AS.bpb = 0;

		uint32_t minspr = 0xffffffff;
		int nVarSampleDividerOffset = -1;
		if  (hdr->VERSION>=38)
			nVarSampleDividerOffset=250;
		else if (hdr->VERSION>=60)
			nVarSampleDividerOffset=152;

		uint8_t *Header2 = hdr->AS.Header+SectionTable[2];
		uint8_t *Header3 = hdr->AS.Header+SectionTable[4];
		for (int k = 0; k < hdr->NS; k++) {
			CHANNEL_TYPE *hc = hdr->CHANNEL+k;

			hc->LeadIdCode = 0;
			hc->Transducer[0] = '\0';
			hc->XYZ[0] = 0.0;
			hc->XYZ[1] = 0.0;
			hc->XYZ[2] = 0.0;
			hc->TOffset  = 0.0;
			hc->HighPass = 0.0/0.0;
			hc->LowPass  = 0.0/0.0;
			hc->Notch    = 0.0/0.0;

			//CHAN = leu16p(Header2+4);

			int len=min(MAX_LENGTH_LABEL,40);
			strncpy(hc->Label,(char*)Header2+6,len);
			hc->Label[len]=0;

			char tmp[21];
			strncpy(tmp,(char*)Header2+68,20); tmp[20]=0;
			/* ACQ uses none-standard way of encoding physical units
			   Convert to ISO/IEEE 11073-10101 */
			if (!strcmp(tmp,"Volts"))
				hc->PhysDimCode = 4256;
			else if (!strcmp(tmp,"Seconds"))
				hc->PhysDimCode = 2176;
			else if (!strcmp(tmp,"deg C"))
				hc->PhysDimCode = 6048;
			else if (!strcmp(tmp,"microsiemen"))
				hc->PhysDimCode = 8307;
			else
				hc->PhysDimCode = PhysDimCode(tmp);

			if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s..) [%s]<%s>\n", __FILE__, __LINE__, __func__,hc->Label,tmp);

			hc->OnOff   = 1;
			hc->SPR     = 1;
			typeof(hc->SPR) spr = 1;
			size_t tmp64;
			uint32_t next, BufLength;
			uint32_t u32;
			uint16_t nVarSampleDivider=1;
			if ( hdr->FILE.LittleEndian ) {
				next        = leu32p(Header2);
				BufLength   = leu32p(Header2+88);
				hc->Cal     = lef64p(Header2+92);
				hc->Off     = lef64p(Header2+100);
				if (hdr->VERSION>=38) nVarSampleDivider = leu16p(Header2 + nVarSampleDividerOffset);  // used here as Divider
				u32         = leu32p(Header3);	// bug in the documentation [1,2]
			}
			else {
				next        = beu32p(Header2);
				BufLength   = beu32p(Header2+88);
				hc->Cal     = bef64p(Header2+92);
				hc->Off     = bef64p(Header2+100);
				if (hdr->VERSION>=38) nVarSampleDivider = beu16p(Header2 + nVarSampleDividerOffset);  // used here as Divider
				u32         = beu32p(Header3);	// bug in the documentation [1,2]
			}
			if (k==0) hdr->NRec = BufLength;
			if (hdr->NRec != BufLength)
				biosigERROR(hdr, B4C_UNSPECIFIC_ERROR, "SOPEN(ACQ-READ): channels with different sampling rates are not supported\n");

			if (hdr->NRec < BufLength)
				hdr->NRec = BufLength;
			if (minspr > BufLength)
				minspr = BufLength;

			hc->bi = hdr->AS.bpb;
			// u32 is
			switch (u32>>16)	{
			case 0:	/* undocumented, maybe a bug on BigEndian platform, because u32=0x00000008, 0x00000000 have been observed only on BE
				   on LE we see the documented values u32=0x00010008, 0x00020002
				 */
			case 1:
				hc->GDFTYP = 17;  // double
				hc->DigMax =  1e9;
				hc->DigMin = -1e9;
				break;
			case 2:
				hc->GDFTYP = 3;   // int
				hc->DigMax =  32767;
				hc->DigMin = -32678;
				break;
			default:
				if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s: #%d 0x%08x: type=%i v%g E%d c%d\n", \
					__FILE__, __LINE__, __func__, (int)k, u32, u32>>16, hdr->VERSION, hdr->FILE.LittleEndian, compressed);

				biosigERROR(hdr, B4C_UNSPECIFIC_ERROR, "SOPEN(ACQ-READ): invalid channel type.");
			};

			if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s: #%d 0x%08x: v%g E%d c%d NRec=%d SPR=%d spr=%d/%d/%d\n", \
				__FILE__, __LINE__, __func__, (int)k, u32, hdr->VERSION, hdr->FILE.LittleEndian, compressed, hdr->NRec, \
				hdr->SPR, hc->SPR,minspr,nVarSampleDivider);

			hc->PhysMax = hc->DigMax * hc->Cal + hc->Off;
			hc->PhysMin = hc->DigMin * hc->Cal + hc->Off;
			hdr->AS.bpb += (GDFTYP_BITS[hc->GDFTYP]*hc->SPR)>>3;

			Header2 += lChanHeaderLen;
			Header3 += 4;
		}

		if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s: v%g E%d c%d NRec=%d SPR=%d minspr=%d\n", __FILE__, __LINE__, __func__, \
			hdr->VERSION, hdr->FILE.LittleEndian, compressed, hdr->NRec, hdr->SPR,minspr);

		hdr->HeadLen += hdr->AS.bpb;
		SectionTable[6] = hdr->HeadLen;

		/// Block Seq 7: Markers header section
		Header2 = hdr->AS.Header+hdr->HeadLen;
		uint32_t markersByteLength = hdr->FILE.LittleEndian ? leu32p(Header2) : beu32p(Header2);

		if ( (hdr->HeadLen+4) > count) {
			hdr->AS.Header = (uint8_t*) realloc(hdr->AS.Header, hdr->HeadLen+4);
			count  += ifread(hdr->AS.Header+count, 1, hdr->HeadLen+4-count, hdr);
		}
		Header2 = hdr->AS.Header+hdr->HeadLen+4;
		hdr->EVENT.N = hdr->FILE.LittleEndian ? leu32p(Header2) : beu32p(Header2);

		SectionTable[7] = hdr->HeadLen+8;
		hdr->HeadLen += markersByteLength;
		SectionTable[8] = hdr->HeadLen;

		if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s: HeadLen=%i  NumberOfEvents=%d v%g markerLen=%d\n", __FILE__, __LINE__, __func__, hdr->HeadLen, hdr->EVENT.N, hdr->VERSION, markersByteLength);

#if 0
		/// Block Seq 8: Marker Item section
		Header2 = hdr->AS.Header+SectionTable[7];
		if (35.0 <= hdr->VERSION && hdr->VERSION <= 45.0) {
			hdr->EVENT.TYP = (uint16_t*)calloc(hdr->EVENT.N,2);
			hdr->EVENT.POS = (uint32_t*)calloc(hdr->EVENT.N,4);
			// Version 3 marker structure
			for (int k=0; k<hdr->EVENT.N; k++) {
				hdr->EVENT.POS[k] = hdr->FILE.LittleEndian ? leu32p(Header2) : leu32p(Header2);
				hdr->EVENT.TYP[k] = 1;
				char *markerText = Header2+12;
				Header2 += 12 + (hdr->FILE.LittleEndian ? leu32p(Header2+10) : leu32p(Header2+10));
			}
		}
		else if (60.0 < hdr->VERSION && hdr->VERSION < 133.0) {
			hdr->EVENT.TYP = (uint16_t*)calloc(hdr->EVENT.N,2);
			hdr->EVENT.POS = (uint32_t*)calloc(hdr->EVENT.N,4);
			hdr->EVENT.CHN = (uint16_t*)calloc(hdr->EVENT.N,2);
			hdr->EVENT.DUR = (uint32_t*)calloc(hdr->EVENT.N,4);
			int next = 14 + (hdr->VERSION>=124.0) * 8 + (hdr->VERSION>=128.0) * 8 ;
			// Version 4 marker structure
			for (int k=0; k<hdr->EVENT.N; k++) {
				char *markerText = Header2 + next + 2;
				uint16_t markerType;
				hdr->EVENT.TYP[k] = 1;
				hdr->EVENT.DUR[k] = 0;
				if (hdr->FILE.LittleEndian) {
					hdr->EVENT.POS[k] = leu32p(Header2);
					hdr->EVENT.CHN[k] = leu16p(Header2+8);
					markerType        = leu16p(Header2+10);
					Header2 += next + 2 + leu32p(Header2+next);
				}
				else {
					hdr->EVENT.POS[k] = beu32p(Header2);
					hdr->EVENT.CHN[k] = beu16p(Header2+8);
					markerType        = beu16p(Header2+10);
					Header2 += next + 2 + beu32p(Header2+next);
				}
			}
		}
		else {
			if (VERBOSE_LEVEL>7) fprintf(stdout,"%s (line %i) %s(..) reading of (%d) Markers not supported for ACQ v%g: \n", \
				__FILE__, __LINE__, __func__, hdr->EVENT.N, hdr->VERSION );

			hdr->EVENT.N = 0;
		}
#endif

	/* TODO: implement ACQ/BIOPAC format support
	        define all fields in hdr->....
		currently only the first hdr->HeadLen bytes are stored in
		hdr->AS.Header, all other fields still need to be defined.
	*/

	// hdr->AS.rawdata = hdr->AS.Header+SectionTable[5];
	hdr->HeadLen  = SectionTable[5];
	ifseek(hdr, hdr->HeadLen, SEEK_SET);

}

#ifdef __cplusplus
}
#endif

