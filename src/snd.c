#include "snd.h"

#define SG_MAX			64
#define WAVE			1
#define STEREO			0

#define BEND_SHIFT		7
#define DR_SHIFT		4
#define SR_SHIFT		8
#define AR_MASK			7
#define DR_MASK			0xf
#define SR_MASK			7
#define SL_MASK			0x7000
#define SL_OFS			0xfff
#define PERC_MASK		8
#define RELEASE_MASK	0x800
#define NZ_MASK			0x8000

#define IOSound(a, d)	(ADR0 = a, DATA0 = d, DATA1 = d >> 8)

enum {
	ATTACK, DECAY, SUSTAIN, RELEASE, DISPOSE
};

typedef struct SG {
	struct SG *next; // must be first member
	u16 id;
	s16 env;
	u8 prog, velo, volex, ref, note, pan, adr, state;
} SG;

static SG sSG[SG_MAX];
static SG *sActiveCh, *sReleaseCh, *sFreeCh;

static const u16 sToneData[] = {
	0x2f72, 0x2f72, 0x3f72, 0x3f72, 0x2f80, 0x2f80, 0x3e80, 0x2f80,
	0x2e70, 0x3740, 0x2f80, 0x7520, 0x2e60, 0x1559, 0x3659, 0x2e61,
	0x7f01, 0x7f01, 0x7f01, 0x7f03, 0x7f03, 0x7f03, 0x7f03, 0x7f03,
	0x2e71, 0x2e71, 0x7e00, 0x7d00, 0x2e71, 0x3f90, 0x3f90, 0x2f81,
	0x7d21, 0x1f80, 0x1f80, 0x1f90, 0x1f70, 0x1f70, 0x1f71, 0x7f61,
	0x7f04, 0x7f04, 0x7f04, 0x7f04, 0x7f06, 0x1649, 0x2678, 0x3f71,
	0x7f06, 0x7f06, 0x7f06, 0x7f06, 0x7f04, 0x7f03, 0x7f03, 0x2e64,
	0x7f04, 0x7f04, 0x7f03, 0x7f03, 0x7f03, 0x7f22, 0x7f22, 0x4f93,
	0x6f53, 0x6f53, 0x6f53, 0x6f53, 0x7f03, 0x7f03, 0x7f03, 0x7f03,
	0x7f03, 0x7f03, 0x7f03, 0x7f76, 0x7f76, 0x7f75, 0x7f05, 0x7f03,
	0x7f01, 0x7f01, 0x7f74, 0x7f82, 0x2fb0, 0x7f01, 0x7f01, 0x7f00,
	0x7f01, 0x7f06, 0x7f00, 0x7f83, 0x7f86, 0x7f06, 0x7f01, 0x7f06,
	0x7f40, 0x5f96, 0x1678, 0x7f00, 0x7e01, 0x7f06, 0x7f01, 0x7f02,
	0x2f90, 0x7e00, 0x2d70, 0x7568, 0x1f80, 0x7f01, 0x7f04, 0x7f01,
	0x1f70, 0x1e50, 0x2568, 0x1638, 0x1568, 0x1658, 0x1558, 0xf206,
	0x7201, 0x7404, 0xfd06, 0x5e80, 0x7f00, 0xff06, 0xff06, 0xac50,
	0x7108, 0x2428, 0xa348, 0x2338, 0x7108, 0x7109, 0x6429, 0xb458,
	0x4459, 0x3338, 0xb348, 0x2338, 0x2328, 0x2328, 0x1328, 0x2328,
	0x2328, 0x2358, 0x2348, 0x1428, 0xb32b, 0xb21a, 0x7178, 0x7198,
	0x2328, 0x2328, 0x7108, 0x7608, 0x0000, 0x0000, 0x0000, 0x0000,
};

static void SetStep(SG *p, s16 bend) {
	static const u16 dptable[] = {
		6, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 
		11, 12, 13, 14, 14, 15, 16, 17, 18, 19, 20, 22, 
		23, 24, 26, 27, 29, 31, 32, 34, 36, 38, 41, 43, 
		46, 48, 51, 54, 58, 61, 65, 69, 73, 77, 81, 86, 
		91, 97, 103, 109, 115, 122, 129, 137, 145, 154, 163, 173, 
		183, 194, 205, 217, 230, 244, 259, 274, 290, 308, 326, 345, 
		366, 388, 411, 435, 461, 488, 517, 548, 581, 615, 652, 690, 
		732, 775, 821, 870, 922, 977, 1035, 1096, 1161, 1230, 1303, 1381, 
		1463, 1550, 1642, 1740, 1843, 1953, 2069, 2192, 2323, 2461, 2607, 2762, 
		2926, 3100, 3285, 3480, 3687, 3906, 4138, 4384, 4645, 4921, 5214, 5524, 
		5852, 6200, 6569, 6960, 7374, 7812, 8277, 8769, 
	};
	if (!(sToneData[p->prog] & NZ_MASK)) {
		u8 note = p->note + (bend >> BEND_SHIFT);
		u8 detune = bend & (1 << BEND_SHIFT) - 1;
		u16 dp = (u32)((1 << BEND_SHIFT) - detune) * dptable[note] + 
			(u32)detune * dptable[note + 1] >> BEND_SHIFT;
		IOSound(p->adr, dp);
	}
}

static void SetVol(SG *p) {
	u8 pan = p->pan, v = (u32)((u16)p->velo * p->volex) * p->env >> 22;
	v = (u16)v * v >> 8;	// 0-0xff
#if STEREO
	u8 vl = (u16)v * (127 - pan) >> 7;
	u8 vr = (u16)v * pan >> 7;
	IOSound(p->adr + 3, (u16)vr << 8 | vl);
#else
	IOSound(p->adr + 3, (u16)v << 8 | v);
#endif
}

#define TC(x)	((INTERVAL << 16) / (x))

static void UpdateEnvelope(SG *p) {
	u16 d = sToneData[p->prog];
	s16 w, env0 = p->env;
	switch (p->state) {
		case ATTACK:
		if (d & AR_MASK) {
			w = p->env + (TC(5000) >> (d & AR_MASK));
			if (w > 0) {
				p->env = w;
				break;
			}
		}
		p->env = 0x7fff;
		p->state = DECAY;
		// fall
		case DECAY:
		if (d >> DR_SHIFT & DR_MASK) {
			w = p->env - (TC(25000) >> (d >> DR_SHIFT & DR_MASK));
			if (w > (d & SL_MASK) + SL_OFS) {
				p->env = w;
				break;
			}
		}
		p->env = (d & SL_MASK) + SL_OFS;
		p->state = SUSTAIN;
		// fall
		case SUSTAIN:
		if ((d >> SR_SHIFT & SR_MASK) < SR_MASK) {
			w = p->env - (TC(125000) >> (d >> SR_SHIFT & SR_MASK));
			if (w > 0) p->env = w;
			else {
				p->env = 0;
				p->state = DISPOSE;
			}
		}
		break;
		case RELEASE:
		w = p->env - (d & RELEASE_MASK ? TC(1000000) : TC(100000));
		if (w > 0) p->env = w;
		else {
			p->env = 0;
			p->state = DISPOSE;
		}
		break;
	}
	if (p->env != env0) SetVol(p);
}

void SndKeyOn(u8 prog, u8 note, u8 velo, u8 volex, u8 pan, s16 bend, u16 id) {
	static const u8 wavesel[] = {
		0x00, 0x0f, 0x00, 0x0c, 0x55, 0x05, 0x55, 0x69, 
		0x55, 0xaa, 0x00, 0x30, 0x00, 0x8f, 0xaa, 0x55, 
		0x55, 0xc0, 0xff, 0xc0, 0x00, 0x0c, 0xc3, 0x00, 
		0xf0, 0x00, 0x0a, 0x10, 0x50, 0x00, 0x00, 0x00, 
	};
	static const s16 rd[] = {
		0x0480, 0x0480, 0x0601, 0x02c2, 0x0783, 0x0382, 0xa504, 0x4a85,
		0xd544, 0x4a85, 0xf584, 0x4a86, 0x15c4, 0x3604, 0x4907, 0x6644,
		0xca88, 0xc907, 0xca88, 0x0789, 0xc90a, 0x478b, 0xc907, 0x0000,
		0xca88, 0x7a0c, 0x794d, 0xba2e, 0xb86f, 0xc730, 0x4991, 0x4612,
		0x9913, 0x9873, 0x9a14, 0x8a15, 0x7ad6, 0x7a97, 0x0000, 0x0000,
		0x4c38, 0x79f9, 0x7959, 0x0000, 0x0000, 0x879a, 0x879b, 
	};
	if ((id & 0xff) == 9) {
		if (note < 35 || note > 81) return;
		s16 t = rd[note - 35];
		prog = t & 0x1f | 0x80;
		note = t >> 5 & 0x7f;
		pan = 0x40 + 5 * (t >> 12);
	}
	SG *p, *p0, *pn;
	u8 ref = velo * volex >> 8;
	for (p = sActiveCh; p && p->id != id; p = p->next)
		;
	if (!p) {
		if (sFreeCh) {
			p = sFreeCh;
			sFreeCh = p->next;
		}
		else if (sReleaseCh) {
			p = sReleaseCh; // smallest ref
			sReleaseCh = p->next;
		}
		else if (sActiveCh) {
			p = sActiveCh; // smallest ref
			sActiveCh = p->next;
		}
		else return;
		for (p0 = (SG *)&sActiveCh, pn = sActiveCh; pn && ref >= pn->ref; p0 = pn, pn = pn->next)
			;
		p->next = p0->next;
		p0->next = p;
	}
	p->id = id;
	p->prog = prog;
	p->velo = velo;
	p->volex = volex;
	p->ref = ref;
	p->note = note;
	p->pan = pan;
	p->env = 0;
	p->state = ATTACK;
	SetStep(p, bend);
	IOSound(p->adr + 1, 0);
	IOSound(p->adr + 3, 0);
	u8 t = 0xff;
	if (!(sToneData[prog] & NZ_MASK))
#if WAVE
		t = prog;
#else
		t = wavesel[prog >> 2] >> ((prog & 3) << 1) & 3;
#endif
	IOSound(p->adr + 2, t);
}

void SndKeyOff(u16 id) {
	SG *p, *p0, *pn;
	for (p0 = (SG *)&sActiveCh, p = sActiveCh; p && p->id != id; p0 = p, p = p->next)
		;
	if (p && !(sToneData[p->prog] & PERC_MASK)) {
		p->state = RELEASE;
		p0->next = p->next;
		for (p0 = (SG *)&sReleaseCh, pn = sReleaseCh; pn && p->ref >= pn->ref; p0 = pn, pn = pn->next)
			;
		p->next = p0->next;
		p0->next = p;
	}
}

void SndVolex(u8 id_low, u8 volex, u8 pan) {
	SG *p;
	for (p = sActiveCh; p; p = p->next) 
		if ((p->id & 0xff) == id_low) {
			p->volex = volex;
			p->pan = pan;
			SetVol(p);
		}
}

void SndBend(u8 id_low, s16 bend) {
	SG *p;
	for (p = sActiveCh; p; p = p->next) 
		if ((p->id & 0xff) == id_low) SetStep(p, bend);
}

void SndInit(void) {
	u8 a = 0;
	SG *p;
	for (p = sSG; p < sSG + SG_MAX; p++) {
		p->next = p + 1;
		p->adr = a;
		IOSound(a + 3, 0);
		a += 4;
	}
	(--p)->next = 0;
	sActiveCh = sReleaseCh = 0;
	sFreeCh = sSG;
}

void SndUpdate(void) {
	SG *p, *p0, *pn;
	for (p = sActiveCh; p; p = p->next) UpdateEnvelope(p);
	for (p = sReleaseCh; p; p = p->next) UpdateEnvelope(p);
	for (p0 = (SG *)&sReleaseCh, p = sReleaseCh; p; p = pn) {
		pn = p->next;
		if (p->state == DISPOSE) {
			p0->next = pn;
			p->next = sFreeCh;
			sFreeCh = p;
		}
		else p0 = p;
	}
}
