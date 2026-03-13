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

#define _GNU_SOURCE
#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <iconv.h>
#include <stdlib.h>
#include <string.h>

#include "../biosig.h"
#define min(a,b)        (((a) < (b)) ? (a) : (b))
#define max(a,b)        (((a) > (b)) ? (a) : (b))

/*
	guid_* are adapted from util-linux/uuid for the use of
	windows-formated guid.
*/

#ifndef UUID_DEFINED
typedef unsigned char uuid_t[16];
#endif

struct uuid {
	uint32_t	time_low;
	uint16_t	time_mid;
	uint16_t	time_hi_and_version;
	uint16_t	clock_seq;
	uint8_t	node[6];
};

int guid_parse_range(const char *in_start, const char *in_end, uuid_t uu) {
	struct uuid	uuid;
	int		i;
	const char	*cp;
	char		buf[3];

	if ((in_end - in_start) != 36)
		return -1;
	for (i=0, cp = in_start; i < 36; i++,cp++) {
		if ((i == 8) || (i == 13) || (i == 18) ||
		    (i == 23)) {
			if (*cp == '-')
				continue;
			return -1;
		}

		if (!isxdigit(*cp))
			return -1;
	}
	errno = 0;

	cp = in_start;
	buf[2] = 0;
	for (i=0; i < 16; i++) {
		buf[0] = *cp++;
		buf[1] = *cp++;

		errno = 0;
		uuid.node[i] = strtoul(buf, NULL, 16);
		if (errno)
			return -1;
	}

	return 0;
}


/*
  code list derived from
  https://github.com/ieeg-portal/Nicolet-Reader/blob/master/%40NicoletFile/NicoletFile.m
 */
const char* TagTable[] = {
	"{A271CCCB-515D-4590-B6A1-DC170C8D6EE2}", "TSGUID",
	"{8A19AA48-BEA0-40D5-B89F-667FC578D635}", "DERIVATIONGUID",
	"{F824D60C-995E-4D94-9578-893C755ECB99}", "FILTERGUID",
	"{02950361-35BB-4A22-9F0B-C78AAA5DB094}", "DISPLAYGUID",
	"{8E94EF21-70F5-11D3-8F72-00105A9AFD56}", "FILEINFOGUID",
	"{E4138BC0-7733-11D3-8685-0050044DAAB1}", "SRINFOGUID",
	"{C728E565-E5A0-4419-93D2-F6CFC69F3B8F}", "EVENTTYPEINFOGUID",
	"{D01B34A0-9DBD-11D3-93D3-00500400C148}", "AUDIOINFOGUID",
	"{BF7C95EF-6C3B-4E70-9E11-779BFFF58EA7}", "CHANNELGUID",
	"{2DEB82A1-D15F-4770-A4A4-CF03815F52DE}", "INPUTGUID",
	"{5B036022-2EDC-465F-86EC-C0A4AB1A7A91}", "INPUTSETTINGSGUID",
	"{99A636F2-51F7-4B9D-9569-C7D45058431A}", "PHOTICGUID",
	"{55C5E044-5541-4594-9E35-5B3004EF7647}", "ERRORGUID",
	"{223A3CA0-B5AC-43FB-B0A8-74CF8752BDBE}", "VIDEOGUID",
	"{0623B545-38BE-4939-B9D0-55F5E241278D}", "DETECTIONPARAMSGUID",
	"{CE06297D-D9D6-4E4B-8EAC-305EA1243EAB}", "PAGEGUID",
	"{782B34E8-8E51-4BB9-9701-3227BB882A23}", "ACCINFOGUID",
	"{3A6E8546-D144-4B55-A2C7-40DF579ED11E}", "RECCTRLGUID",
	"{D046F2B0-5130-41B1-ABD7-38C12B32FAC3}", "GUID TRENDINFOGUID",
	"{CBEBA8E6-1CDA-4509-B6C2-6AC2EA7DB8F8}", "HWINFOGUID",
	"{E11C4CBA-0753-4655-A1E9-2B2309D1545B}", "VIDEOSYNCGUID",
	"{B9344241-7AC1-42B5-BE9B-B7AFA16CBFA5}", "SLEEPSCOREINFOGUID",
	"{15B41C32-0294-440E-ADFF-DD8B61C8B5AE}", "FOURIERSETTINGSGUID",
	"{024FA81F-6A83-43C8-8C82-241A5501F0A1}", "SPECTRUMGUID",
	"{8032E68A-EA3E-42E8-893E-6E93C59ED515}", "SIGNALINFOGUID",
	"{30950D98-C39C-4352-AF3E-CB17D5B93DED}", "SENSORINFOGUID",
	"{F5D39CD3-A340-4172-A1A3-78B2CDBCCB9F}", "DERIVEDSIGNALINFOGUID",
	"{969FBB89-EE8E-4501-AD40-FB5A448BC4F9}", "ARTIFACTINFOGUID",
	"{02948284-17EC-4538-A7FA-8E18BD65E167}", "STUDYINFOGUID",
	"{D0B3FD0B-49D9-4BF0-8929-296DE5A55910}", "PATIENTINFOGUID",
	"{7842FEF5-A686-459D-8196-769FC0AD99B3}", "DOCUMENTINFOGUID",
	"{BCDAEE87-2496-4DF4-B07C-8B4E31E3C495}", "USERSINFOGUID",
	"{B799F680-72A4-11D3-93D3-00500400C148}", "EVENTGUID",
	"{AF2B3281-7FCE-11D2-B2DE-00104B6FC652}", "SHORTSAMPLESGUID",
	"{89A091B3-972E-4DA2-9266-261B186302A9}", "DELAYLINESAMPLESGUID",
	"{291E2381-B3B4-44D1-BB77-8CF5C24420D7}", "GENERALSAMPLESGUID",
	"{5F11C628-FCCC-4FDD-B429-5EC94CB3AFEB}", "FILTERSAMPLESGUID",
	"{728087F8-73E1-44D1-8882-C770976478A2}", "DATEXDATAGUID",
	"{35F356D9-0F1C-4DFE-8286-D3DB3346FD75}", "TESTINFOGUID",
};

const char* infoProps[] = {
	"patientID", 	"firstName", 	"middleName", 	"lastName",
	"altID", 	"mothersMaidenName", "DOB", 	"DOD",
	"street", 	"sexID", 	"phone", 	"notes",
	"dominance", 	"siteID", 	"suffix", 	"prefix",
	"degree", 	"apartment", 	"city", 	"state",
	"country", 	"language", 	"height", 	"weight",
	"race",		"religion", 	"maritalStatus", ""
};


int guid_parse(const char *in, uuid_t uu) {
	size_t len = strlen(in);
	if (len != 36)
		return -1;

	return guid_parse_range(in, in + len, uu);
}

#ifdef __cplusplus
extern "C" {
#endif

int sopen_nicoletE_read(HDRTYPE* hdr) {
	/* TODO: implement Nicolet-E format support
	        define all fields in hdr->....
		currently only the first hdr->HeadLen bytes are stored in
		hdr->AS.Header, all other fields still need to be defined.
	*/

		const int LABELSIZE     = 32;
		const int TSLABELSIZE   = 64;
		const int UNITSIZE      = 16;
		const int ITEMNAMESIZE  = 64;

		if (VERBOSE_LEVEL > 8) fprintf(stderr,"%s line %ld: NICOLET:E\n",__FILE__,__LINE__);
		// Nicolet_E
		uint16_t gdftyp=3;  // int16_t
		size_t pos=0;
		size_t count = hdr->HeadLen;
		while (!ifeof(hdr)) {
			hdr->AS.Header = (uint8_t*)realloc(hdr->AS.Header, count*2 + 1);
			count         += ifread(hdr->AS.Header+count, 1, count, hdr);
		}
		hdr->HeadLen=count;
		hdr->AS.Header[count]=0;
		hdr->NS=0;

		fprintf(stderr,"%s line %d: NICOLET:E\n",__FILE__,__LINE__);
		fflush(stdout);

		typedef struct {
			uint16_t index[2];
			uint32_t misc1;
			uint32_t indexIdx;
			uint32_t misc2[3];
			uint32_t sectionIdx;
			uint32_t misc3;
			uint32_t offset;
			uint32_t blockL;
			uint32_t dataL;
		} Qindex_t;

		typedef struct {
			uint64_t sectionIdx;
			uint64_t offset;
			uint32_t blockL;
			uint32_t sectionL;
		} NicoletIndex_t;
		NicoletIndex_t *NicoletIndex = NULL;

		typedef struct {
			gdf_time gdfTime;
			gdf_time gdfTime2;
			uint64_t internalOffset;
			uint32_t packetSize;
			char*    IDStr;
			uint8_t *data;
			size_t  datasize;
		} dynamicPacket_t;

		// format definition obtained from https://github.com/ieeg-portal/Nicolet-Reader
		hdr->FILE.LittleEndian = 1;	// default little endian
		uint64_t indexIdx = leu32p(hdr->AS.Header+6*4);
		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E  # Get tags and datastructure\n",__FILE__,__LINE__);

		// Get TAGS structure and Channel IDS
		int32_t nrTags = lei32p(hdr->AS.Header+172);

		char** Taglist = (char**)alloca(nrTags * sizeof(char*));

		iconv_t CD=iconv_open("UTF8", "UTF-16LE");
		char BUFFER[(LABELSIZE+TSLABELSIZE+UNITSIZE+ITEMNAMESIZE)*2];
		for (size_t k=0; k<nrTags; k++) {
			size_t outbytesleft = sizeof(BUFFER);
			char *tag=BUFFER;
			char *wctag = hdr->AS.Header + 176 + k*84;
			uint32_t tagIndex = leu32p(hdr->AS.Header + 176 + 80 + k*84);
			size_t inbytesleft = 80;
			size_t ret=iconv(CD, &wctag, &inbytesleft, &tag, &outbytesleft);

			if (k!=tagIndex) {
				biosigERROR(hdr, B4C_DATATYPE_UNSUPPORTED, "Error SOPEN(Nicolet_E): invalid tagIndex - file seems corrupted");
			}

			Taglist[k] = (BUFFER[0]=='{') ? "UNKNOWN" : NULL;
			const int TL = (sizeof(TagTable)/sizeof(char*));
			for (int l=0; l < TL ; l+=2) {
				if (!strcmp(BUFFER, TagTable[l])) {
					Taglist[k] = TagTable[l+1];
					break;
				}
			}
			if (Taglist[k]==NULL) {
				Taglist[k] = alloca(strlen(BUFFER)+1);
				strcpy(Taglist[k], BUFFER);
			}
			if (VERBOSE_LEVEL>7) fprintf(stdout, "%s (line %d) NICOLET_E: %d/%d  #%d tag: <%s> <%s> %ld\n", __FILE__, __LINE__, k, nrTags, tagIndex, BUFFER, Taglist[k], ret);

		}

		if (VERBOSE_LEVEL > 7) fprintf(stdout,"\n#------- %s line %d: NICOLET:E\n",__FILE__,__LINE__);

		// QI index
		pos=172208;
		uint32_t Qi_nrEntries = leu32p(hdr->AS.Header+pos);
		uint32_t Qi_misc1     = leu32p(hdr->AS.Header+pos+4);
		uint32_t Qi_indexIdx  = leu32p(hdr->AS.Header+pos+8);
		uint32_t Qi_misc3     = leu32p(hdr->AS.Header+pos+12);
		uint32_t Qi_LQi       = leu64p(hdr->AS.Header+pos+16);
		uint32_t Qi_firstIdx  = leu64p(hdr->AS.Header+pos+24);

		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E\n",__FILE__,__LINE__);
		Qindex_t *Qindex      = (Qindex_t*)(hdr->AS.Header+188664);

		// TODO: do we need Qindex, or can we omit it ? If needed, Endianity conversion of Qindex->FIELDS
		for (size_t k=0; k<Qi_LQi; k++) {
			// offset 48
		}

		// Get Main Index
		if (VERBOSE_LEVEL > 7) fprintf(stdout,"\n-------- %s line %d: NICOLET:E  get Main index  indexIdx=%ld,%ld\n",__FILE__,__LINE__,indexIdx,Qi_nrEntries);
		NicoletIndex = (NicoletIndex_t*)alloca(Qi_nrEntries*sizeof(NicoletIndex_t));
		uint64_t nextIndexPointer = indexIdx;
		int curIdx=0;
		int curIdx2=1;	// TODO: can be omitted

		uint64_t *spr=NULL;	// spr[i] number of samples of sections (i.e. sum of sectionL) with sectionIdx==i,
		uint64_t *nsi=NULL;	// nsi[i] number of sections with sectionIdx==i
		uint64_t numSectionType=0;
		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E  %d %d  next:%ld  %ld\n",__FILE__,__LINE__,curIdx, Qi_nrEntries,nextIndexPointer,count);
		while (curIdx < Qi_nrEntries) {
			size_t nrIdx = leu64p(hdr->AS.Header+nextIndexPointer);
			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E  nrIdx=%d next=%lx\n",__FILE__,__LINE__, nrIdx, nextIndexPointer);
			for (size_t k=0; k < nrIdx; k++, curIdx++) {
				uint64_t ns                     = leu64p(hdr->AS.Header + nextIndexPointer + k*24 + 8);
				NicoletIndex[curIdx].sectionIdx = ns;
				NicoletIndex[curIdx].offset     = leu64p(hdr->AS.Header + nextIndexPointer + k*24 + 16);
				NicoletIndex[curIdx].blockL     = leu32p(hdr->AS.Header + nextIndexPointer + k*24 + 24);
				NicoletIndex[curIdx].sectionL   = leu32p(hdr->AS.Header + nextIndexPointer + k*24 + 28);

				if (VERBOSE_LEVEL > 8) fprintf(stdout,"%s line %d: NICOLET:E %d %ld %ld| %9ld %9ld %9d  %9d  \n", __FILE__, __LINE__, curIdx, k, ns,
					NicoletIndex[curIdx].sectionIdx, NicoletIndex[curIdx].offset, NicoletIndex[curIdx].blockL, NicoletIndex[curIdx].sectionL);

				if (numSectionType < (ns+1)) {
					//fprintf(stdout,"%s line %d: NICOLET:E ns=%d,%ld\n",__FILE__, __LINE__, hdr->NS,ns);
					spr = realloc(spr, (ns+1)*sizeof(uint64_t));
					nsi = realloc(nsi, (ns+1)*sizeof(uint64_t));
					for (size_t k=numSectionType; k<=ns; k++) {
						spr[k]=0;
						nsi[k]=0;
					}
					numSectionType = ns;
				}
				spr[ns]+= NicoletIndex[curIdx].sectionL;
				nsi[ns]++;
			};
			nextIndexPointer = leu64p(hdr->AS.Header + nextIndexPointer + nrIdx*24);
			curIdx2++;
		}

#if 1
		if (VERBOSE_LEVEL > 7)
		for (size_t k=0; k < numSectionType; k++) {
			fprintf(stdout, "#%d spr/nsi=%lu/%lu\n", k, spr[k], nsi[k]);
		}
#endif


		for (int k=0; k<Qi_nrEntries; k++) {
			if (!strcmp(Taglist[NicoletIndex[k].sectionIdx],"InfoChangeStream")) {
				curIdx=k;
				break;
			}
		}

		// dynamic packages
		int nrDynamicPackets = NicoletIndex[curIdx].sectionL / 48;
		pos = NicoletIndex[curIdx].offset;
		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E DynPKG: %d  %d 0x%0x \n",__FILE__,__LINE__,nrDynamicPackets,pos,pos);

		dynamicPacket_t *dynamicPacket = alloca(nrDynamicPackets * sizeof(dynamicPacket_t));
		for (size_t k=0; k < nrDynamicPackets; k++) {
			uint8_t *ptr = hdr->AS.Header + pos + k*48;

			dynamicPacket[k].gdfTime        = t_time2gdf_time((lef64p(ptr+16) + lef64p(ptr+24) - 25569) * 24 * 3600);
			dynamicPacket[k].gdfTime2        = ldexp(lef64p(ptr+16) + lef64p(ptr+24) + 693961,32);
			dynamicPacket[k].internalOffset = leu64p(ptr+32);
			dynamicPacket[k].packetSize     = lef64p(ptr+40);
			dynamicPacket[k].data           = NULL;
			dynamicPacket[k].datasize       = 0;
			dynamicPacket[k].IDStr          = NULL;

			uint8_t *guid = ptr;
			char BUFFER[40];
			snprintf(BUFFER, sizeof(BUFFER), "{%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X}",
				guid[3],guid[2],guid[1],guid[0],   guid[5],guid[4],guid[7],guid[6],
				guid[8],guid[9],guid[10],guid[11], guid[12],guid[13],guid[14],guid[15]);

			const int TL = (sizeof(TagTable)/sizeof(char*));
			for (int j=0; j < TL ; j+=2) {
				if (!strcmp(BUFFER, TagTable[j])) {
					dynamicPacket[k].IDStr = TagTable[j+1];
					break;
				}
			}
			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: k=%d ptr=<%s> <%s>\n",__FILE__,__LINE__,k,BUFFER, dynamicPacket[k].IDStr);
		}


		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...)\n",__FILE__,__LINE__,__func__);

		for (size_t k=0; k < nrDynamicPackets; k++) {

			if (dynamicPacket[k].IDStr==NULL) continue;

			// const char *BUFFER=dynamicPacket[k].IDStr;  //
			const char *BUFFER=dynamicPacket[k].IDStr;  	// this is equialent to dynamicPacket[k].IDStr

		        size_t internalOffset = 0;
			size_t remainingDataToRead = dynamicPacket[k].packetSize;
			size_t currentTargetStart  = dynamicPacket[k].internalOffset;
			for (int j = 0; j < Qi_nrEntries; j++) {
				if (k==NicoletIndex[j].sectionIdx) {
					NicoletIndex_t *currentInstance = NicoletIndex+j;
					if ((internalOffset <= currentTargetStart) && ((internalOffset+currentInstance->sectionL) >= currentTargetStart)) {

						size_t startAt = currentTargetStart;
						size_t stopAt  = min(startAt+remainingDataToRead, internalOffset+currentInstance->sectionL);
						size_t readLength = stopAt-startAt;

						size_t filePosStart   = currentInstance->offset + startAt - internalOffset;
						uint8_t *dataPart      = hdr->AS.Header+filePosStart;
						dynamicPacket[k].data = realloc(dynamicPacket[k].data, dynamicPacket[k].datasize + readLength);
						memcpy(dynamicPacket[k].data + dynamicPacket[k].datasize, dataPart, readLength);
						dynamicPacket[k].datasize += readLength;

						remainingDataToRead  -= readLength;
						currentTargetStart   += readLength;
					}
					internalOffset += currentInstance->sectionL;
				}
			}
		}

		curIdx=-1;
		for (int k=0; k<Qi_nrEntries; k++) {
			if (!strcmp(Taglist[NicoletIndex[k].sectionIdx],"PATIENTINFOGUID")) {
				curIdx=k;
				break;
			}
		}
		if (curIdx != -1) {
			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...) idx=%d \n",__FILE__,__LINE__,__func__,curIdx);
			pos = NicoletIndex[curIdx].offset;
			NicoletIndex_t *currentInstance = NicoletIndex+curIdx;
			uint8_t* ptr = hdr->AS.Header + pos;
			uint8_t *guid16   = ptr;
			ptr += 16;
			uint64_t lSection = leu64p(ptr);
			ptr += 8;
			// uint64_t reserved = leu64_t(ptr);
			//ptr += 6;
			uint64_t nrValues = leu64p(ptr);
			ptr += 8;
			uint64_t nrBstr   = leu64p(ptr);
			ptr += 8;
			for (size_t k=0; k < nrValues; k++) {

				uint64_t id = leu64p(ptr);
				ptr += 8;
				double  value = lef64p(ptr);
				switch (id) {
				case 7: // DOB
				case 8: // DOD
				case 23: // height
				case 24: // weight
					ptr += 8;
				};

				switch (id) {
				case 7: // DOB
					hdr->Patient.Birthday = t_time2gdf_time((value - 25569) * 24 * 3600);
					break;
				case 8: // DOD
					hdr->T0 = t_time2gdf_time((value - 25569) * 24 * 3600);
					break;
				case 23: // height
					hdr->Patient.Height = value;
					break;
				case 24: // weight
					hdr->Patient.Weight = value;
					break;
				};
			}

			// strSetup = fread(h,nrBstr*2,'uint64');
			// ptr += nrBstr*2*sizeof(uint64_t);
			char* pos2 = ptr + nrBstr * 16;
			char* name1 = NULL;
			char* name2 = NULL;
			char* name3 = NULL;
			for (size_t k=0; k < 2*nrBstr; k+=2) {
				uint64_t id = leu64p(ptr+k*8);
				uint64_t len = (leu64p(ptr+k*8+8)+1)*2;
				size_t inbytesleft = len;

				size_t outbytesleft = ITEMNAMESIZE*2+1;
				uint8_t BUFFER[ITEMNAMESIZE*2+1];
				char* ptr2=BUFFER;
				size_t ret=iconv(CD, &pos2, &inbytesleft, &ptr2, &outbytesleft);

			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...) %d <%s><%s><%s>\n",__FILE__,__LINE__,__func__, id, name1, name2, name3 );

				switch (id) {
				case 1: // patientID
					strncpy(hdr->Patient.Id, BUFFER, MAX_LENGTH_PID);
					hdr->Patient.Id[MAX_LENGTH_PID]=0;
					break;
				case 2: // first name
					// FIXME
					name1 = alloca(strlen(BUFFER)+1);
					strcpy(name1,BUFFER);
					break;
				case 3: // middle name
					// FIXME
					name2 = alloca(strlen(BUFFER)+1);
					strcpy(name2,BUFFER);
					break;
				case 4: // last name
					// FIXME
					name3 = alloca(strlen(BUFFER)+1);
					strcpy(name3,BUFFER);
					break;
				case 10: // Sex
					hdr->Patient.Sex = 0;	// FIXME
					break;
				}
				pos2 += len;
			}
			// FIXME
			snprintf(hdr->Patient.Name, MAX_LENGTH_NAME+1,"%s\x1f%s\x01f%s\0",name3,name1,name2);
			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...)\n",__FILE__,__LINE__,__func__);
		}

		curIdx=-1;
		for (int k=0; k<Qi_nrEntries; k++) {
			if (!strcmp(Taglist[NicoletIndex[k].sectionIdx],"InfoGuids")) {
				curIdx=k;
				break;
			}
		}
		if (curIdx != -1) {
			NicoletIndex_t *currentInstance = NicoletIndex+curIdx;
			uint8_t* ptr = hdr->AS.Header + NicoletIndex[curIdx].offset;
			// ignored
		}

		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...)\n",__FILE__,__LINE__,__func__);

		curIdx = -1;
		for (int k=0; k < nrTags; k++) {
			if (!strcmp(Taglist[k],"SIGNALINFOGUID")) {
				curIdx=k;
				break;
			}
		}
		if (curIdx != -1) {
			// %% Get SignalInfo (SIGNALINFOGUID): One per file
			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...) %d\n",__FILE__,__LINE__,__func__,curIdx);
			pos = NicoletIndex[curIdx].offset;
			pos = NicoletIndex[curIdx].offset+16+ITEMNAMESIZE+152+512;
			hdr->NS        = leu16p(hdr->AS.Header + pos);
			uint32_t nrIdx = leu32p(hdr->AS.Header + pos);

			if (hdr->NS != nrIdx) biosigERROR(hdr, B4C_DATATYPE_UNSUPPORTED, "Error SOPEN(Nicolet_E): unexpected/unsupported values - possible file corruption ");

			if (VERBOSE_LEVEL > 7) fprintf(stdout,"# -------- %s line %d: NICOLET:E  get SignalInfo idx=%d  NS=%d 0x%016x\n",__FILE__,__LINE__,curIdx,hdr->NS, nrIdx);
			hdr->CHANNEL = (CHANNEL_TYPE*) realloc(hdr->CHANNEL,hdr->NS * sizeof(CHANNEL_TYPE));

			pos = NicoletIndex[curIdx].offset+16+ITEMNAMESIZE+152+512+4*2;
			for (int ch=0; ch < hdr->NS; ch++) {
				CHANNEL_TYPE *hc = hdr->CHANNEL+ch;
				hc->GDFTYP=0;
				// TODO: initialize all fields

				size_t pos2 = pos + ch*(512-64-8); //(LABELSIZE+UNITSIZE+16+4*4+256);
				char *wctag = hdr->AS.Header + pos2;
				size_t inbytesleft = LABELSIZE*2;
				size_t outbytesleft = MAX_LENGTH_LABEL+1;
				char *tag   = hc->Label;
				size_t ret=iconv(CD, &wctag, &inbytesleft, &tag, &outbytesleft);
				*tag=0;

				wctag = hdr->AS.Header + pos2 + LABELSIZE*2; //(LABELSIZE+UNITSIZE+16+4*4+256);
				outbytesleft = MAX_LENGTH_TRANSDUCER+1;
				tag   = hc->Transducer;
				inbytesleft = UNITSIZE*2;
				ret=iconv(CD, &wctag, &inbytesleft, &tag, &outbytesleft);
				*tag=0;

				hc->LowPass = leu32p(hdr->AS.Header + pos2 + LABELSIZE*2+UNITSIZE*2+16*2+4);
				hc->HighPass = leu32p(hdr->AS.Header + pos2 + LABELSIZE*2+UNITSIZE*2+16*2+4+4);

				// FIXME
				if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E @%08x #%-5d/%d <%s>:<%s> filter:[%g,%g]\n",__FILE__,__LINE__,pos,ch,hdr->NS,hc->Label,hc->Transducer,hc->LowPass,hc->HighPass);
			}
		}

		for (int k=0; k<Qi_nrEntries; k++) {
			if (strcmp(Taglist[NicoletIndex[k].sectionIdx],"CHANNELGUID")) continue;
			curIdx=k;
			//  Get CHANNELINFO (CHANNELGUID)
			pos = NicoletIndex[curIdx].offset;
			// guid
			pos = NicoletIndex[curIdx].offset+16+ITEMNAMESIZE+152+16+16+488;
//TODO: check			pos = NicoletIndex[idxSIGNALINFOGUID].offset+16+ITEMNAMESIZE*2+152+16+16+488;
			uint32_t nrIdx1 = leu32p(hdr->AS.Header + pos);
			uint32_t nrIdx2 = leu32p(hdr->AS.Header + pos + 4);

			if (VERBOSE_LEVEL > 7) fprintf(stdout,"# --------- %s line %d: NS=%d  %d %d \n",__FILE__,__LINE__,hdr->NS,nrIdx1,nrIdx2);

			// TODO: check handling of disabled channels, see max(hdr->NS,nrIdx2), bOn, etc.
			hdr->CHANNEL = (CHANNEL_TYPE*) realloc(hdr->CHANNEL,max(hdr->NS,nrIdx2)*sizeof(CHANNEL_TYPE));
			pos += 8;
			for (int ch=0; ch<nrIdx2; ch++) {
				CHANNEL_TYPE *hc = hdr->CHANNEL+ch;

				char *wctag = hdr->AS.Header + pos;
				size_t inbytesleft = LABELSIZE*2;
				size_t outbytesleft = MAX_LENGTH_LABEL+1;
				char *tag   = hc->Label;
				size_t ret=iconv(CD, &wctag, &inbytesleft, &tag, &outbytesleft);
				*tag=0;

				double Fs = lef64p(hdr->AS.Header + pos + LABELSIZE*2);
				uint32_t bOn  = leu32p(hdr->AS.Header + pos + LABELSIZE*2+8);
				hc->OnOff     = bOn>0;

				uint32_t lInputID   = leu32p(hdr->AS.Header + pos + LABELSIZE*2+8+4);
				uint32_t lInputSettingID   = leu32p(hdr->AS.Header + pos + LABELSIZE*2+8+8);

				if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E @%08x #%d/%d %dHz <%s> [%d,%d,%d]\n",__FILE__,__LINE__,pos,ch,hdr->NS,Fs,hc->Label,hc->Transducer,bOn, lInputID, lInputSettingID);
				pos += LABELSIZE*2+8+4*4+128;
			}
		}

		curIdx=-1;
		for (size_t k=0; k < nrDynamicPackets; k++) {
			if (strcmp("TSGUID", dynamicPacket[k].IDStr)) continue;
			dynamicPacket_t* tsPacket = dynamicPacket + k;
			uint32_t elems = leu32p(tsPacket->data+752);
			uint32_t alloc = leu32p(tsPacket->data+756);
			uint32_t offset = 760;

			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...) %d %d TSGUID\n",__FILE__,__LINE__,__func__,k,elems);

			for (uint32_t i=0; i<elems; i++, offset+=552) {
				uint32_t internalOffset = offset;

				char *inbuf;
				char *outbuf;
				size_t inbytesleft,outbytesleft;

				inbuf=tsPacket->data+internalOffset; inbytesleft = TSLABELSIZE*2;
				outbuf=BUFFER;               outbytesleft = sizeof(BUFFER);
				size_t ret=iconv(CD, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
				char *label = alloca(strlen(BUFFER)+1);
				strcpy(label,BUFFER);

				internalOffset += TSLABELSIZE*2;
				inbuf=tsPacket->data+internalOffset; inbytesleft = LABELSIZE*2;
				outbuf=BUFFER;               outbytesleft = sizeof(BUFFER);
				ret=iconv(CD, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
				char *activeSensor = alloca(strlen(BUFFER)+1);
				strcpy(label,BUFFER);

				internalOffset += LABELSIZE*2;
			inbuf=tsPacket->data+internalOffset; inbytesleft = 8*2;
				outbuf=BUFFER;               outbytesleft = sizeof(BUFFER);
				ret=iconv(CD, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
				char *refSensor = alloca(strlen(BUFFER)+1);
				strcpy(label,BUFFER);

				internalOffset += 8+56;
				double dLowCut = lef64p(tsPacket->data+offset+internalOffset);
				double dHighCut = lef64p(tsPacket->data+offset+internalOffset+8);
				double dSamplingRate = lef64p(tsPacket->data+offset+internalOffset+16);
				double dResolution = lef64p(tsPacket->data+offset+internalOffset+24);
				double bMark = leu16p(tsPacket->data+offset+internalOffset+32);
				double bNotch = leu16p(tsPacket->data+offset+internalOffset+34);
				double dEegOffset = lef64p(tsPacket->data+offset+internalOffset+36);

			if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...) elem %d/%d Label:%s A:%s Ref:%s [%g,%g] %gHz Cal:%g Off:%g M:%d Notch:%d\n",
				__FILE__, __LINE__, __func__, i, elems, label, activeSensor, refSensor,
				dLowCut, dHighCut, dSamplingRate, dResolution, dEegOffset, bMark, bNotch);
			}
		}

		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: %s(...)\n",__FILE__,__LINE__,__func__);

		curIdx=-1;
		for (int k=0; k<Qi_nrEntries; k++) {
			if (!strcmp(Taglist[NicoletIndex[k].sectionIdx],"SegmentStream")) {
				curIdx=k;
				break;
			}
		}
		if (curIdx != -1) {
			size_t nrSegments = NicoletIndex[curIdx].sectionL/152;

			size_t N = hdr->EVENT.N + nrSegments - 1;
			hdr->EVENT.POS = realloc(hdr->EVENT.POS, N * sizeof(hdr->EVENT.POS[0]));
			hdr->EVENT.TYP = realloc(hdr->EVENT.TYP, N * sizeof(hdr->EVENT.TYP[0]));
			hdr->EVENT.CHN = realloc(hdr->EVENT.CHN, N * sizeof(hdr->EVENT.CHN[0]));
			hdr->EVENT.DUR = realloc(hdr->EVENT.DUR, N * sizeof(hdr->EVENT.DUR[0]));
			hdr->EVENT.TimeStamp= realloc(hdr->EVENT.TimeStamp, N * sizeof(hdr->EVENT.TimeStamp[0]));

			pos = NicoletIndex[curIdx].offset;
			for (size_t i = 0; i<nrSegments; i++) {
				double dateOLE  = lef64p(hdr->AS.Header + pos + i*152);
				double duration = lef64p(hdr->AS.Header + pos + i*152 + 16);

				gdf_time TimeStamp = t_time2gdf_time( (dateOLE - 25569) * 24 * 3600);
				if (i==0)
					hdr->T0 = TimeStamp;
				else {
					size_t n = hdr->EVENT.N + i - 1;
					hdr->EVENT.TimeStamp[n] = TimeStamp;
					hdr->EVENT.CHN[n] = 0;
					hdr->EVENT.TYP[n] = 0x7ffe;
					hdr->EVENT.DUR[n] = duration;	// TODO: convert to samples
					hdr->EVENT.POS[n] = 0;   // TODO: get samples
				}
			}
		}

		curIdx=-1;
		for (int k=0; k<Qi_nrEntries; k++) {
			if (!strcmp(Taglist[NicoletIndex[k].sectionIdx],"Events")) {
				curIdx=k;
				break;
			}
		}
		if (curIdx != -1) {
			size_t nrSegments = NicoletIndex[curIdx].sectionL/152;
			// TODO: get evnets
		}

		// Get montage  - TODO
		// there is more TODO

		if (VERBOSE_LEVEL > 7) fprintf(stdout,"%s line %d: NICOLET:E --- parsing has stopped here \n",__FILE__,__LINE__);

		iconv_close(CD);
		if (spr) free(spr);
		if (nsi) free(nsi);
		for (size_t k=0; k < nrDynamicPackets; k++) {
			uint8_t* ptr = dynamicPacket[k].data;
			if (ptr) free(ptr);
		}

		biosigERROR(hdr, B4C_DATATYPE_UNSUPPORTED, "Error SOPEN(Nicolet_E):not supported (yet)");
		return 0;
	}

#ifdef __cplusplus
}
#endif

