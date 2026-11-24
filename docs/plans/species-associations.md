# Plan: "Grows with" — symbiotic links between species

**Status:** proposed 16/11/2026; owner decisions 16/11/2026 below. Steps 1–4 built 23/11/2026
(model, validation, reverse-link test, "Grows With" page section, editor section, report column).
Step 5 done 23/11/2026, in two parts. (1) 20 pairs between entries that already existed. (2) Seven
host-tree drafts added (silver birch, European beech, red, hard, black, mountain and silver beech;
owner reviews them as a group) and 33 more pairs, including fly agaric–lilly pilly on the owner's
word: 53 pairs, 106 links. Every link rests on a New Zealand record naming the host species — Biota
of New Zealand PDD host records read through Biota's current-name column (old 'Nothofagus solandri'
records split between black and mountain beech), Virtual Mycota, Plant & Food, the Fungal Guide,
Segedin 1984 — recorded as a dated 'Associations round' line on both entries. UI test: slippery jack →
radiata pine. Black and mountain beech also carry lookalike cards to each other (NZPCN similar taxa).

Not linked, for want of a species-level New Zealand record (raise again only if a record turns up):
oakbug milkcap–oak ('Quercus sp.'); porcini–sweet chestnut (its habitat text names chestnut, no NZ
record); death cap–mānuka/kānuka and fly agaric–larch/mānuka (genus only); slimy milkcap (no NZ host
record at all); olive oyster–silver beech (one photo record); skirt webcap–black beech; umere–kānuka and
tawai–tōtara (single records outside their beech habitat); peppery bolete–trees (treated as a parasite
of fly agaric, not a tree partner). GloBI root-partner leads checked against Biota NZ PDD host
records 23/11/2026, none naming the tree: slippery jack with walnuts, pear, Douglas fir, oak, European
beech, plantain and silver birch (its NZ records are all pines); birch bolete with black cherry and oak;
larch bolete with radiata pine and European beech (all larch); western painted suillus with radiata
pine; fly agaric with walnuts, strawberry tree and sweet chestnut; oakbug and slimy milkcap with
European beech and silver birch; saffron milk cap with black locust and Douglas fir (radiata pine
only); porcini with radiata pine ('Pinus' only). Chalciporus aurantiacus with silver and hard beech
(Biota hosts, but Cooper's IUCN assessment has it as probably a parasite of other fungi, not a beech
partner; owner 23/11/2026: don't link). No entries for goat willow (Flora of New Zealand: NZ 'Salix caprea'
records are probably S. ×reichardtii), poplar (genus-only records) or alder (no NZ record).
No entry for Japanese red pine (Pinus densiflora; owner link round 23/11/2026, seven links; owner
'yes' to dropping it): a GloBI root-partner lead of slippery jack, fly agaric, saffron milk cap, slimy
milkcap and larch bolete, but not present wild in New Zealand. iNaturalist NZ has 0 wild observations
(7 captive), neither the Flora of New Zealand vol. IV nor the NZ Flora Online Pinus page lists it,
Biota gives biostatus Exotic, Cultivated, NZPCN has no page, and of 44 GBIF NZ herbarium sheets all
but one are arboretum, domain, trial or farm plantings; the one wild sheet (NZFRI 27531, Rotorua,
03/03/2009, 'First naturalised record of this species in N.Z.') is a single young tree near its two
planted parents. It is in the Northland and Greater Wellington regional pest plans (DOC Weeds
database, 43 records). Raise again only if wild records turn up. The report drops it from the leads
(`NOT_IN_NZ_HOSTS` in `Tools/catalogue_report.py`; owner 23/11/2026: 'if dont exist in nz drop').
No entry for Japanese black pine (Pinus thunbergii; owner link round 23/11/2026, five links; owner
'drop it' 23/11/2026): a GloBI root-partner lead of slippery jack, saffron milk cap, rufous milkcap and
death cap, but not established wild in New Zealand. Biota and NZOR give biostatus Exotic, Cultivated,
the Flora of New Zealand vol. IV does not treat it, NZPCN has no page, and the 36 GBIF NZ records are
plantings (Eastwoodhill, Lake Coleridge, Christchurch Botanic Gardens, FRI grounds, shelterbelts such as
CHR 706590 'planted as a shelter row'). Two wild sites only: Muriwai Regional Park, Edwin Mitchelson
Track (AK329829, AK329831 '1A- Adventive', 21/01/2012; NZFRI 34699, 19/02/2011) and Whangarei Heads
(iNaturalist 19558176 and 19558206, 'Spreading along roadside cutting'). DOC Weeds lists it as an
environmental weed (35 records) in the Northland and Greater Wellington regional pest plans. Raise again
only if more wild records turn up. The report drops it from the leads (`NOT_IN_NZ_HOSTS`).
No entry for Mexican white pine (Pinus ayacahuite; owner link round 24/11/2026, eight links): a GloBI
root-partner lead of slippery jack ('hasEctomycorrhizalHost'), but not established wild in New Zealand.
Biota (plant and fungus name records) gives biostatus Exotic, Cultivated, NZOR carries no biostatus, it
is not on the NZ Flora Online Pinus list, NZPCN has no page, and iNaturalist NZ has 2 observations, both
captive (Whakarewarewa 'Planted stand', Cashmere). Of 20 GBIF NZ herbarium sheets all but one are
pinetum, arboretum, trial-plot, nursery or park plantings (the pasted Auckland Museum record 892968 is
AK375130, Lake Coleridge 'cultivated in pinetum'); the one wild sheet (NZFRI 27621, Rotorua, 15/05/2009,
'not planted … about 100 m from a small planted stand … First record of this rare species naturalising
in New Zealand') is a single tree by its planted parents, the Japanese red pine case. DOC Weeds lists it
as a weed (20 records) in the Northland and Greater Wellington regional pest plans, which alone does not
justify a draft. Raise again only if wild records turn up. The report drops it from the leads
(`NOT_IN_NZ_HOSTS`).
No entry for Hartweg's pine (Pinus hartwegii; owner link round 24/11/2026, five links: DOC Weeds, NZFRI
cultivated-pines key, Gymnosperm Database, Temperate Plants Database, Biota): GloBI root-partner leads of
slippery jack and fly agaric ('hasEctomycorrhizalHost'), but no wild record in New Zealand at all. Biota
gives biostatus Exotic, Cultivated, it is not on the NZ Flora Online Pinus list, and the NZFRI page is a
key to cultivated pines. iNaturalist NZ has 2 observations, both captive (Lynmore, Timaru). All 17 GBIF NZ
herbarium sheets are trial-plot, nursery, arboretum, park or botanic-garden plantings (FRI Long Mile and
nursery seedlots, Gwavas trial plot, Earnscleugh trial, Eastwoodhill, McLaren Falls Park, Christchurch
Botanic Gardens); none is self-sown. DOC Weeds lists it as a weed (15 records) in the Northland and
Greater Wellington regional pest plans, which alone does not justify a draft. Raise again only if wild
records turn up. The report drops it from the leads (`NOT_IN_NZ_HOSTS`).
No entry for pinyon pine (Pinus edulis; owner link round 24/11/2026, seven links: PFAF, Biota, DOC Weeds,
Pinoli, NZFRI cultivated-pines key, The Plant Company, Forage Colorado): a GloBI root-partner lead of
slippery jack ('hasEctomycorrhizalHost'), but no wild record in New Zealand. Biota gives biostatus Exotic,
Cultivated (its record is a fungal-host name, Gadgil & Dick 2001 and Gadgil 2005), it is not on the NZ Flora
Online Pinus list, and the NZFRI page is a key to cultivated pines. iNaturalist NZ has 1 observation, captive
(Hurford). All 15 GBIF NZ herbarium sheets are plantings: Lake Coleridge Arboretum (NZFRI 6887, 8276, 22543;
AK233271, AK135647, AK375139, AK225194, all 'Exotic cult.'), Christchurch Botanic Gardens pinetum (NZFRI 6898,
8775), Eastwoodhill (NZFRI 26066, 27040) and the Rangiwahia pinetum (NZFRI 27102); the Rakaia River bank
sheet CHR 518271 is SCD 'Cultivated', 'Isolated tree almost certainly planted'. DOC Weeds lists it as a weed
(15 records) in the Northland and Greater Wellington regional pest plans, which alone does not justify a
draft. Pinoli and Forage Colorado describe its nuts overseas; The Plant Company page does not name it; PFAF
is not used. Raise again only if wild records turn up. The report drops it from the leads
(`NOT_IN_NZ_HOSTS`).
No entry for sugar pine (Pinus lambertiana; owner link round 24/11/2026, eight links: PFAF, Biota, NZFRI
cultivated-pines key, DOC Weeds, SCD CHR 419897 C, conifers.org, Theodore Payne, theferns): a GloBI host lead of
slippery jack ('hasHost'; Biota also lists it as a host, PDD and Gadgil 2005), but no wild record in New
Zealand. Biota gives biostatus Exotic, Cultivated, it is not on the NZ Flora Online Pinus list, and the NZFRI
page is a key to cultivated pines. iNaturalist NZ has 0 observations. All 15 GBIF NZ herbarium sheets are
plantings: the pasted CHR 419897 C (and its A, B, D, E parts) and NZFRI 25597 are 'Cultivated' in South Hagley
Park, NZFRI 25599 Christchurch Botanic Gardens, CHR 460722 a large tree at the Lake Coleridge Electricity Dept.
Pinetum ('Roadside'), AK260172 'Exotic cult.', and NZFRI 17560 (Naseby, 'Planted as provenance trial in 1959'),
3430 (Golden Downs, 'Planted 1930'), 1785, 2442, 2508 (Waiotapu forest compartments, seed collections) and
20033 (Rotorua) forestry plantings. DOC Weeds lists it as a weed (14 records) in the Northland and Greater
Wellington regional pest plans, which alone does not justify a draft. PFAF (seeds, sap sugar, gum),
conifers.org, Theodore Payne and theferns are overseas pages and are not used. Raise again only if wild
records turn up. The report drops it from the leads (`NOT_IN_NZ_HOSTS`).
No entry for Chinese pine (Pinus tabuliformis; owner link round 24/11/2026, seven links: PFAF, two Biota
records, DOC Weeds, NZFRI cultivated-pines key, Auckland Museum AK154340, conifers.org): a GloBI host lead of
slippery jack, fly agaric and saffron milk cap (all 'hasEctomycorrhizalHost'), but no wild record in New
Zealand. Both Biota records (plant and fungal-host names) give biostatus Exotic, Cultivated, it is not on the
NZ Flora Online Pinus list, and the NZFRI page is a key to cultivated pines. iNaturalist NZ has 3
observations, all captive (Rangiwahia, Canterbury, Auckland). All 14 GBIF NZ herbarium sheets are plantings:
the pasted AK154340 (the Auckland Museum page 403s; read via GBIF) and NZFRI 6601 Dunedin Botanic Gardens,
CHR 419892 A and B 'Cultivated' in the Lake Coleridge power station pinetum, NZFRI 6910, 6911, 7482, 25925 and
AK375149, AK391430 Eastwoodhill Arboretum, NZFRI 27064 McLaren Falls Park, NZFRI 25596 Victoria Park
(Christchurch), and NZFRI 9858 and AK260181 the FRI grounds at Long Mile, Rotorua. DOC Weeds lists it as a weed
(14 records) in the Northland and Greater Wellington regional pest plans, which alone does not justify a
draft. PFAF and conifers.org are overseas pages and are not used. Raise again only if wild records turn up.
The report drops it from the leads (`NOT_IN_NZ_HOSTS`).

No entry for Jeffrey pine (Pinus jeffreyi; owner link round 24/11/2026, seven links: NZFRI cultivated-pines
key, PFAF, Biota, DOC Weeds, Auckland Museum AK375088, conifers.org, NZFFA pine resources): a GloBI host lead of
slippery jack ('hasEctomycorrhizalHost'; porcini 'interactsWith' and common inkcap 'symbiontOf' only), but
below the owner's bar, the same case as Japanese black pine. Biota gives biostatus Exotic, Cultivated, it is
not in the Flora or on the NZ Flora Online Pinus list, and the NZFRI page is a key to cultivated pines.
iNaturalist NZ has 3 observations, all captive (Otautau NZ Forest Service planting, Christchurch, Garden of
Tane). Of 13 GBIF NZ herbarium sheets, 11 are plantings: the pasted AK375088 and AK135671 'Exotic cult.' in the
Lake Coleridge pinetum, AK356266 'Exotic cult.' Orton Bradley Park, CHR 616117 A–C 'Cultivated in small
plantation', CHR 508907 A and B 'Cultivated.', CHR 464618 'planted'. The two wild sheets are both C. Howell, 12
Feb 2020, Mackenzie Basin: CHR 658228 Twizel North West Arch (a tree of about 40 years 'presumed to have
established from shelterbelts', several saplings) and CHR 658229 Tekapo–Twizel Road roadside (saplings by trees
of about 60 years, 'Less common than P. ponderosa'). DOC Weeds lists it as a weed (24 records, 1949–2020). PFAF,
conifers.org and the NZFFA list (an FRI Bulletin 124 part 10 link on ponderosa and Jeffrey pines, not read)
are not used. Raise again if the owner wants Mackenzie Basin wildings to count, or more wild records turn up.
The report drops it from the leads (`NOT_IN_NZ_HOSTS`).

No entry for Khasi pine (Pinus kesiya; owner link round 24/11/2026, seven links: two Biota records, DOC Weeds,
NZFRI cultivated-pines key, Auckland Museum 890939, DigitalNZ 42620922, CHR 518643): a GloBI host lead of
slippery jack only ('hasEctomycorrhizalHost'), but no wild record in New Zealand. The Biota plant record gives
biostatus Exotic, Cultivated; the other Biota record is its fungal-host name (two PDD records, from Fiji and
Papua New Guinea). It is not on the NZ Flora Online Pinus list, and the NZFRI page is a key to cultivated pines
('two [subspecies] have been planted in NZ'). iNaturalist NZ has 1 observation, at Dunedin Botanic Garden. All
12 GBIF NZ herbarium sheets are plantings: the pasted CHR 518643 (duplicate NZFRI 25615, 'Cultivated' in John
Anderson's Pinetum near Albury, raised from seed ex Beijing), the pasted Auckland Museum 890939 = AK374553
'1EC- Exotic cult.' (duplicate NZFRI 23847, Holdsworth's, Puha, 'Seed from Luzon'), the pasted DigitalNZ record
= AK375148 (duplicate NZFRI 32733) and AK391445, AK224739, AK224740, NZFRI 18431 Eastwoodhill Arboretum, NZFRI
26932 and 27023 Naturally Native Nursery pinetum and Millennial Wood, and NZFRI 27721 the former Whakarua
Conifers near Rangiwaea Junction. DOC Weeds lists it as a weed with 12 records, 1989–2025, the same count and
years as the herbarium sheets. Raise again only if wild records turn up. The report drops it from the leads
(`NOT_IN_NZ_HOSTS`).
No entry for red pine (Pinus resinosa; owner link round 24/11/2026, six links: PFAF, DOC Weeds, NZFRI
cultivated-pines key, conifers.org, Biota, Fletcher Trust Archives P2000/304): a GloBI host lead of slippery
jack only ('lives on', two records; black walnut's 'interactsWith' rows are never leads), but no wild record in
New Zealand. The pasted Biota link is the genus record (Pinus, Exotic, Wild); the species record
(d62058a3…) gives biostatus Exotic, Cultivated, with vernaculars Red pine and Norway pine. It is not on the NZ
Flora Online Pinus list, and the NZFRI page is a key to cultivated pines (natural distribution E Canada, NE
USA; no NZ wild note). iNaturalist NZ has 0 observations, captive or wild. All 12 GBIF NZ herbarium sheets are
plantings: NZFRI 25929 Eastwoodhill Arboretum pinetum, NZFRI 23772 Naseby Forest ('In abandoned FRI trial.
Planted 1956'), NZFRI 17591 Berwick State Forest provenance trial (duplicate AK277820 '1EC- Exotic cult.'),
NZFRI 17592 Craigieburn research trial area, NZFRI 6923 Christchurch Botanic Gardens pinetum (duplicate
AK260200 '1EC- Exotic cult.'), NZFRI 6891 Lake Coleridge Arboretum, AK233312 and AK375141 Lake Coleridge
'1EC- Exotic cult.' ('cultivated in pinetum'), AK135656 (same date, no record returned), NZFRI 1801 Waiotapu
('From top of 40yr old tree'); Biota's two Canterbury CHR sheets are CHR 536175 A–B, W.R. Sykes 69/73, Lake
Coleridge, 'Cultivated in pinetum'. DOC Weeds lists it (as Norway pine) as a weed with 11 records, in the
Northland RPMP (Sustained Control) and Greater Wellington RPMP (Progressive Containment) only. The Fletcher
Trust photograph is a NZ State Forest Service album print, circa 1924, with no place or wild note. Not used
for food: PFAF's only edible use is vanillin flavouring from pulpwood resins; conifers.org lists ethnobotany
references (Ciesla 1998, Smith 1932) without NZ presence. Raise again only if wild records turn up. The report
drops it from the leads (`NOT_IN_NZ_HOSTS`).
No entry for Korean pine (Pinus koraiensis; owner link round 24/11/2026, six links: PFAF, DOC Weeds, two Biota
records, Te Papa SP120136/B, a Stuff garden column): a GloBI root-partner host of slippery jack and rufous
milkcap (fly agaric's row is 'interactsWith' and turkey tail is a generalist, so neither is a lead), but no wild
record in New Zealand. Biota gives biostatus Exotic, Cultivated; its fungal-host record lists three PDD rows, all
'Records from USSR'. It is not on the NZ Flora Online Pinus list. iNaturalist NZ has 2 observations, both
captive (Hāwera 2026, Lake Coleridge 2015). All 10 GBIF NZ herbarium sheets are plantings: CHR 701015 A–B
(Ohakune, 2025; 'Growing on the edge of a stream' but collection event 'Cultivated', 'Ornamental, approx. 8 m
tall'), NZFRI 27055 (Scion Long Mile Road provenance trial, 'Seed lot FRI/64/1801, from Korea, 36 trees planted
1968'), NZFRI 15248, NZFRI 6902 and AK275282 Lake Coleridge Arboretum, NZFRI 6884, NZFRI 7485 ('Cultivated
tree') and AK154336 Eastwoodhill Arboretum, NZFRI 19978 Rotorua. The Te Papa sheet was collected at Harvard,
USA ('Cultivated'). DOC Weeds lists it as a weed with 10 records, in the Northland RPMP (Sustained Control) and
Greater Wellington RPMP (Progressive Containment) only. The Stuff column says the supermarket pine nut is
P. koraiensis 'usually imported from China' — no NZ wild note. Not used for food: PFAF seeds and oil (the
commercial nut; would need an NZ presence first). Raise again only if wild records turn up. The report drops it
from the leads (`NOT_IN_NZ_HOSTS`).
No entry for eastern hemlock (Tsuga canadensis; owner 24/11/2026: "drop", from the report's Link next): a GloBI
'hasHost' lead of slippery jack and birch bolete (turkey tail is a generalist; the rest are 'interactsWith').
Not on the NZ Flora Online Tsuga list (western hemlock only). iNaturalist NZ has 2 observations, both captive
(Timaru). All 9 GBIF NZ herbarium sheets are plantings: CHR 616150 ('Cultivated in gully bottom'), NZFRI 28817
Orton Bradley Park arboretum, NZFRI 24626 Motueka ('Cultivated amongst other trees'), NZFRI 8269 Christchurch
Botanic Gardens pinetum, NZFRI 6820 Eastwoodhill Arboretum, Te Papa SP092368 ('Cultivated at Rotorua, F.R.I.'),
NZFRI 1437 Whaka Arboretum, AK230154 and AK224695 (no wild note). The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for dwarf Siberian pine (Pinus pumila; owner 24/11/2026: "drop", from the report's Link next): a GloBI
root-partner host of slippery jack and rufous milkcap. Not on the NZ Flora Online Pinus list; iNaturalist NZ has
0 observations; the one GBIF NZ herbarium sheet, NZFRI 27687 (2009), is from a nursery display garden (Cedar
Lodge Nursery, New Plymouth; 'Very small shrub 18 cm high'). The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for small-leaved lime (Tilia cordata; symbiosis-host drive 24/11/2026; owner: "if actually not in the
wild in nz and truly only cultivated then drop"): a GloBI host of birch bolete. Biota: Exotic, Cultivated (CHR
134715). iNaturalist NZ has 49 non-captive observations, all street, park, botanic-garden and school trees; the
one self-sown note (323332870) is a twig sprout in a gutter, and the 'wild seedling' notes (335578713,
146705240) are on Tilia x europaea, not cordata. All 13 GBIF NZ herbarium sheets are cultivated or park trees.
Raise again only if wild records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for hornbeam (Carpinus betulus; symbiosis-host drive 24/11/2026; owner: "if actually not in the wild in
nz and truly only cultivated then drop"): a GloBI host of bluefoot bolete, oakbug milkcap and peppery bolete.
Biota: Exotic, Cultivated (Edwards 2008). iNaturalist NZ has 17 non-captive observations, all hedges, garden and
street trees; the only seedling, 142722986 (Christchurch, 'unrecognised wild tree seedling'), is a lone plant
that commenters read as hawthorn. All 17 GBIF NZ herbarium sheets are planted, cultivated, arboretum or nursery.
Raise again only if wild records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for velvet bent (Agrostis canina; symbiosis-host drive 24/11/2026; owner: "if actually not in the wild
in nz and truly only cultivated then drop"): a GloBI host of liberty cap. Biota has a name record with no
biostatus row, and NZ Flora Online's Agrostis treatment (Edgar & Connor 2000) does not include it (the
naturalised bents are capillaris, castellana, gigantea and stolonifera). iNaturalist NZ has 0 non-captive
observations. The 19 GBIF NZ sheets named canina (CHR 1982-85 in Chionochloa grassland, Fiordland, Campbell
Island) are old determinations of native Agrostis, none marked naturalised. Raise again only if wild records
turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for quaking aspen (Populus tremuloides; symbiosis-host drive 24/11/2026; owner: "if actually not in the
wild in nz and truly only cultivated then drop"): a GloBI host of birch bolete and fly agaric. Biota: Exotic,
Cultivated (CHR 369345). iNaturalist NZ has 1 non-captive observation (145648626, Nelson, 'wild seedling of'),
whose identification is disputed in comments. Of 5 GBIF NZ sheets, two are cultivated and two (Palmerston North,
Staces Rd 4982811100; stopbank 1091318165) give habitat only, with no wild or naturalised remark. Raise again
only if wild records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for Australian myrtle beech (Lophozonia cunninghamii; symbiosis-host drive 24/11/2026; owner: "if
actually not in the wild in nz and truly only cultivated then drop"): a GloBI host of fly agaric. Biota: Exotic,
Cultivated in New Zealand (CHR 656342; indigenous in Australia). iNaturalist NZ has 2 non-captive observations:
190279795 (Dunedin North, seedlings directly under a fruiting adult, observer asks for confirmation) and
345225501 (Wellington Zoo planting). All 17 GBIF NZ sheets are botanic-garden cultivation. Raise again only if
wild records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for red-flowering gum (Corymbia ficifolia; symbiosis-host drive 24/11/2026; owner: "if actually not in
the wild in nz and truly only cultivated then drop"): a GloBI host of fly agaric. Biota: Exotic, Casual; NZ
Flora Online: Exotic (as Eucalyptus ficifolia). DOC Weeds lists 69 records and calls it no weed. Every
iNaturalist NZ and herbarium record is ornamental or plantation, with no self-sown record. Raise again only if
wild records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for Metrosideros collina (symbiosis-host drive 24/11/2026; owner: "if actually not in the wild in nz
and truly only cultivated then drop"): a GloBI host of brown oyster mushroom. Not the Kermadec pohutukawa (that
is M. kermadecensis): a Pacific species (Tahiti, Polynesia) sold in NZ as the cultivars 'Tahiti' and 'Spring
Fire'. Biota: Exotic, Casual (Heenan, de Lange, Cameron and Parris 2008; var. villosa Exotic, Cultivated), but
iNaturalist NZ has 3 non-captive observations, all planted or garden, and every GBIF NZ sheet is cultivated or
planted. Biota's fungus rows for it are Cook Islands records, not NZ. Raise again only if wild records turn up.
The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for paper birch (Betula papyrifera; symbiosis-host drive 24/11/2026; owner: "if actually not in the
wild in nz and truly only cultivated then drop"): a GloBI host of birch bolete, fly agaric and western painted
suillus. Biota: Exotic, Casual (Allan Herbarium 2015), resting on one sheet, CHR 186196 (1968, 'Adventive in
hillside shrubbery', Eastwoodhill); NZ Flora Online: Exotic. iNaturalist NZ has 3 non-captive observations, all
needing ID (paper birch or B. platyphylla/pubescens). Other GBIF notes are 'Occasional weed at this site' (NZFRI
27315, Murupara old Forest Service plant workshop) and 'orchard property next to houses' (MPN51771); the rest
are street, park and arboretum trees, with ID confusion with B. pubescens documented. Raise again only if wild
records turn up. The report drops it (`NOT_IN_NZ_HOSTS`).
No entry for coigüe (Nothofagus dombeyi; 24/11/2026, owner rule "if actually not in the wild in nz and truly only
cultivated then drop"): a GloBI root-partner host of western painted suillus. Flora of New Zealand (Ford, Heenan &
Smissen 2016) lists one Nothofagus in New Zealand, N. antarctica (Exotic: Casual); Biota of New Zealand carries
N. dombeyi only as a fungal-host name, with no plant biostatus. iNaturalist NZ has 1 non-captive observation
(411312548, Christchurch, "large, garden tree") and 4 captive. All 21 GBIF NZ herbarium sheets are cultivated or
planted (botanic gardens, FRI and DSIR grounds, estates, gardens); NZFRI 10551 (Otaki Gorge picnic area, former
farmland) gives no sign it was self-sown. Raise again only if wild records turn up. The report drops it
(`NOT_IN_NZ_HOSTS`).
No entry for the 27 further cultivated-only GloBI hosts below (symbiosis-host drive 24/11/2026; owner: "if
actually not in the wild in nz and truly only cultivated then drop"); each has no wild record. sugar maple (Acer
saccharum; birch bolete): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 7 GBIF NZ herbarium sheets
(cultivated, an open-grown station tree, nursery). subalpine fir (Abies lasiocarpa; birch bolete): Biota Exotic,
Cultivated, 0 non-captive iNaturalist NZ, 5 GBIF NZ herbarium sheets (driveways, a carpark garden, FRI nursery
seedlot). yellow birch (Betula alleghaniensis; birch bolete and coconut milkcap): Biota Exotic, Cultivated, 0
non-captive iNaturalist NZ, 5 GBIF NZ herbarium sheets (cultivated, one young tree). white alder (Alnus
rhombifolia; birch bolete and coconut milkcap): Biota Exotic, Cultivated, 2 non-captive iNaturalist NZ, 4 GBIF
NZ herbarium sheets (iNaturalist NZ two Auckland garden/amenity plantings; sheets cultivated). Erman's birch
(Betula ermanii; birch bolete and coconut milkcap): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 2
GBIF NZ herbarium sheets (cultivated). sweet birch (Betula lenta; birch bolete): Biota Exotic, Cultivated, 0
non-captive iNaturalist NZ, 2 GBIF NZ herbarium sheets (arboretum plantings). dwarf birch (Betula nana; birch
bolete and coconut milkcap): Biota has no biostatus row, 0 non-captive iNaturalist NZ, 1 GBIF NZ herbarium sheet
(one sheet, no remarks). Mongolian oak (Quercus mongolica; birch bolete, oakbug milkcap and saffron milk cap):
Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 2 GBIF NZ herbarium sheets (a street-front tree border).
sessile oak (Quercus petraea; bluefoot bolete, oakbug milkcap and slimy milkcap): Biota Exotic, Cultivated, 0
non-captive iNaturalist NZ, 15 GBIF NZ herbarium sheets (park tree, arboretum). coast live oak (Quercus
agrifolia; shaggy parasol): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 6 GBIF NZ herbarium sheets
(Eastwoodhill, nursery). Sakhalin fir (Abies sachalinensis; birch bolete, bluefoot bolete and coconut milkcap):
Biota has no biostatus row, 0 non-captive iNaturalist NZ, 1 GBIF NZ herbarium sheet (a young Dunedin Botanic
Gardens tree). Pacific silver fir (Abies amabilis; bluefoot bolete): Biota Exotic, Cultivated, 0 non-captive
iNaturalist NZ, 9 GBIF NZ herbarium sheets (FRI nursery seedlots). white spruce (Picea glauca; bluefoot bolete,
fly agaric, peppery bolete, slimy milkcap and wood blewit): Biota Exotic, Cultivated, 0 non-captive iNaturalist
NZ, 13 GBIF NZ herbarium sheets (cultivars only in Biota; cultivated, nursery, arboretum). blue spruce (Picea
pungens; fly agaric): Biota Exotic, Cultivated, 4 non-captive iNaturalist NZ, 10 GBIF NZ herbarium sheets
(iNaturalist NZ four showground/amenity plantings with no notes). Engelmann spruce (Picea engelmannii; fly
agaric and peppery bolete): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 9 GBIF NZ herbarium sheets
(nursery seedlots from Mexico). shagbark hickory (Carya ovata; bluefoot bolete, oakbug milkcap and slimy
milkcap): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 11 GBIF NZ herbarium sheets (no wild remarks).
shellbark hickory (Carya laciniosa; bluefoot bolete): Biota has no biostatus row, 0 non-captive iNaturalist NZ,
1 GBIF NZ herbarium sheet (one sheet, no remarks). sand pine (Pinus clausa; bluefoot bolete and oakbug milkcap):
Biota has no biostatus row, 0 non-captive iNaturalist NZ, 1 GBIF NZ herbarium sheet (one sheet). Masson's pine
(Pinus massoniana; saffron milk cap): Biota Exotic, Cultivated, 0 non-captive iNaturalist NZ, 10 GBIF NZ
herbarium sheets (Eastwoodhill pinetum, FRI nursery seedlot). American chestnut (Castanea dentata; coconut
milkcap, fly agaric and oakbug milkcap): Biota has no biostatus row, 0 non-captive iNaturalist NZ, 2 GBIF NZ
herbarium sheets (blight-resistant chestnut trial or garden, no wild remarks). silver lime (Tilia tomentosa;
bluefoot bolete, fly agaric and riverine bolete): Biota Exotic, Cultivated, 1 non-captive iNaturalist NZ, 24
GBIF NZ herbarium sheets (the one iNaturalist NZ is a Christchurch street tree; sheets cultivated). Dahurian
larch (Larix gmelinii; larch bolete and western painted suillus): Biota Exotic, Cultivated, 0 non-captive
iNaturalist NZ, 10 GBIF NZ herbarium sheets (no wild remarks). tamarack (Larix laricina; larch bolete): Biota
has no biostatus row, 0 non-captive iNaturalist NZ, 1 GBIF NZ herbarium sheet (one sheet). Franchet's maple
(Acer sterculiaceum subsp. franchetii; larch bolete): Biota has no biostatus row, 0 non-captive iNaturalist NZ,
2 GBIF NZ herbarium sheets (no remarks). Nootka cypress (Callitropsis nootkatensis; saffron milk cap): Biota
Exotic, Cultivated, 0 non-captive iNaturalist NZ, 18 GBIF NZ herbarium sheets (no wild remarks). Cathay poplar
(Populus cathayana; saffron milk cap): Biota has no biostatus row, 0 non-captive iNaturalist NZ, 1 GBIF NZ
herbarium sheet (one sheet). American beech (Fagus grandifolia; slimy milkcap): Biota Exotic, Cultivated, 1 non-
captive iNaturalist NZ, 1 GBIF NZ herbarium sheet (the one iNaturalist NZ is a casual undated record in a
university garden). Raise again only if wild records turn up. The report drops them (`NOT_IN_NZ_HOSTS`).
Slippery jack–heather (owner 23/11/2026, declined: one GloBI 'symbiontOf' record with no study or
place, no NZ record; heather was added for this lead and kept as a food entry). Open question for the
owner: the declines above that rest on Biota rest on its PDD rows only; Biota's literature rows
(Gadgil 2005, Fungi on Trees and Shrubs in New Zealand; Ridley & Dick 2001) name Larix decidua and
Castanea sativa as fly agaric hosts, so fly agaric–larch and fly agaric–sweet chestnut may be
linkable; all stay declined until the owner says.

**Owner link round 23/11/2026 (Pinus contorta):** contorta pine added as a draft host tree (no entry before) and linked to slippery jack (Biota: Dickie et al. 2010 mycorrhizal host, Gadgil 2005, three PDD records), fly agaric (Dickie et al. 2010, one PDD record) and rufous milkcap (one PDD record), and on the owner's word to porcini and saffron milk cap (GloBI 'hasHost' records only, no Biota record): 58 pairs. Not linked: peppery bolete (declined with trees). Slippery jack now has 2 links; the owner is working down its host list.

**Owner link round 23/11/2026 (Pinus nigra subsp. laricio):** Corsican pine added as a draft host tree (no entry before) and linked to its two GloBI leads with catalogue entries, slippery jack and fly agaric (GloBI 'hasHost'; Biota: Gadgil 2005 names Pinus nigra subsp. laricio for both): 60 pairs. GloBI's other fungi on this pine have no entry or are generalists. Slippery jack now has 3 links.

**Austrian pine 23/11/2026 (Pinus nigra subsp. nigra):** added as a draft on the owner's word (it has food uses, not only for symbiosis). No links: GloBI and Biota name no fungus with a catalogue entry on this subspecies; two slippery jack PDD records say 'Pinus nigra' with no subspecies, so neither Corsican nor Austrian pine gets them.

**Owner link round 23/11/2026 (Pinus muricata):** bishop pine added as a draft host tree (no entry before; careRequired for young cones in syrup, on genus-wide mugolio records per the owner's ruling; its seeds rest on one record only) and linked to its three GloBI leads with catalogue entries: slippery jack (GloBI 'hasHost'/'hasEctomycorrhizalHost'; Biota: Gadgil 2005 and one PDD record), fly agaric and porcini (GloBI only, no Biota record): 63 pairs. Peppery bolete not linked (DECLINED_WITH_TREES). Slippery jack now has 4 links.

**Owner link round 23/11/2026 (Pinus sylvestris):** Scots pine added as a draft host tree (no entry before; careRequired for young needles and shoots, young male cones, seeds and famine-flour inner bark) and linked to its one GloBI lead with a catalogue entry, slippery jack (GloBI 'hasHost'/'hasEctomycorrhizalHost'; no Biota record): 64 pairs. GloBI's other catalogue fungi on Scots pine have only 'symbiontOf' or untyped records, turkey tail is a generalist, and Biota's associations name no catalogue species. Slippery jack now has 5 links.

**Dwarf mountain pine and mountain pine 23/11/2026 (Pinus mugo, P. uncinata):** added as drafts on the owner's word (NZPCN names both as similar to Scots pine). Mountain pine linked to its one GloBI lead with a catalogue entry, rufous milkcap (GloBI 'hasEctomycorrhizalHost'; no Biota record): 65 pairs. Dwarf mountain pine has no GloBI host lead (slippery jack 'symbiontOf' only) and no Biota record naming a catalogue species.

**Owner link round 23/11/2026 (Pinus ponderosa):** ponderosa pine added as a draft host tree (no entry before; careRequired for seeds and inner bark, two records each; young cones and needle tea left out because ponderosa carries the genus's cattle-abortion claim) and linked to its three GloBI leads with catalogue entries: slippery jack (GloBI 'hasHost'/'hasEctomycorrhizalHost'; Biota: one PDD record and Gadgil 2005), porcini (GloBI 'hasHost'; Biota: one PDD record) and fly agaric (GloBI 'hasEctomycorrhizalHost'; no Biota record): 68 pairs. Peppery bolete not linked (DECLINED_WITH_TREES); giant puffball's 'hasHost' record is not a lead (grassland generalist). Slippery jack now has 6 links.

**Loblolly pine and slash pine 23/11/2026 (Pinus taeda, P. elliottii):** added as drafts on the owner's word (NZPCN names both as similar to ponderosa pine). Loblolly pine linked to its three GloBI leads with catalogue entries, fly agaric, saffron milk cap and rufous milkcap (GloBI 'hasEctomycorrhizalHost'; no Biota record); slash pine to slippery jack and fly agaric (GloBI 'hasEctomycorrhizalHost') and saffron milk cap (GloBI 'hasHost'), no Biota record: 74 pairs. Peppery bolete on loblolly pine not linked (DECLINED_WITH_TREES). Slippery jack now has 7 links.

**Mexican weeping pine 23/11/2026 (Pinus patula):** added as a draft from the owner's link round (seven links, no entry existed). Linked to slippery jack (GloBI 'hasEctomycorrhizalHost' and 'hasHost'; Biota PDD and Gadgil 2005 name the host) and fly agaric (GloBI 'hasEctomycorrhizalHost'; no Biota record): 76 pairs. Armillaria novae-zelandiae and turkey tail not linked (generalists). Slippery jack now has 8 links.
**Eastern white pine 23/11/2026 (Pinus strobus):** added as a draft from the owner's link round (ten links, no entry existed). Linked to slippery jack (GloBI 'hasEctomycorrhizalHost'; no Biota record), fly agaric (GloBI 'hasHost'; Biota's one record is from the United States) and death cap (GloBI 'hasHost'; no Biota record): 79 pairs. Horse mushroom (grassland generalist), Armillaria novae-zelandiae and turkey tail not linked. Biota names Suillus granulatus (weeping bolete, no entry) on it from New Zealand. Slippery jack now has 9 links.
**Aleppo pine 23/11/2026 (Pinus halepensis):** added as a draft from the owner's link round (eight links, no entry existed). Linked on GloBI 'hasEctomycorrhizalHost' records (saffron milk cap also 'hasHost'), none with a Biota record, to slippery jack, fly agaric, saffron milk cap, bluefoot bolete, oakbug milkcap and slimy milkcap (the first links for both milkcaps), and on the owner's 'add' to birch bolete (an overseas record; its New Zealand text, birch only, stands): 86 pairs. Peppery bolete declined with every tree. Slippery jack now has 10 links.
**Maritime pine 23/11/2026 (Pinus pinaster):** added as a draft on the owner's 'sure' (the Flora key's one lookalike of Aleppo pine; cards both ways). Linked to slippery jack and bluefoot bolete on Biota of New Zealand PDD records naming the host (GloBI has only an untyped record or none): 88 pairs. Fly agaric, saffron, oakbug and rufous milkcap not linked (GloBI 'symbiontOf' only); Armillaria and turkey tail generalists. Slippery jack now has 11 links.
**Jack pine 23/11/2026 (Pinus banksiana):** added as a draft from the owner's link round (seven links, no entry existed) after it passed the presence check (Flora of New Zealand treats it as naturalised; wild sheets at Naseby, Tasman Valley and Totara Park; iNaturalist NZ has none). Linked on GloBI 'hasEctomycorrhizalHost' records to slippery jack (also 'hasHost', with a Biota record: Gadgil 2005 and a New Zealand PDD record), fly agaric and rufous milkcap: 91 pairs. Common inkcap not linked ('symbiontOf' only). Slippery jack now has 12 links.
**Symbiosis hosts 24/11/2026 (owner: 'NZ plants with no entry for symbiosis'):** the 59 GloBI host leads with no entry were triaged on Biota biostatus and iNaturalist NZ (12 'Exotic, Wild', 9 'Exotic, Casual', 38 'Cultivated' or none), each then researched. On the owner's 'yeas build drafts for the food entries', three drafts with food records were added and linked on GloBI records with no study or place given and no Biota record, so every note says 'overseas': red oak (Quercus rubra; Flora of New Zealand: naturalised, self-sown near planted trees) ↔ bluefoot bolete and oakbug milkcap ('hasEctomycorrhizalHost'); grand fir (Abies grandis; adventive at Hanmer, self-sown at Bulls and Marton) ↔ saffron milk cap ('hasHost'); black cottonwood (Populus trichocarpa; one male clone suckering on riverbanks) ↔ fly agaric ('hasHost'): 95 pairs. The rest follow the owner's 24/11/2026 rulings (do-not-eat drafts for food-less hosts after an edibility re-check, drafts for one-record hosts and weeping willow as Salix ×pendulina, presence checks for the Casual hosts, drops only for hosts truly cultivated-only).
**Symbiosis hosts, second batch 24/11/2026:** on the owner's rulings ('1 yes, 2 yes, 3 sure, 4 search, 5 yes', then '1 if its unsubstanciated skip, 2 yes, 3 are they found in nz? …, 4 sure, 5 research'), 19 more drafts, each linked to its GloBI leads both ways (notes say 'overseas' unless a Biota of New Zealand record names the pair): western hemlock, Japanese larch (larch bolete, Biota NZ), Canary Island pine, Norway spruce, Atlas cedar (fly agaric, bluefoot bolete and porcini on Biota NZ records), Greek fir, Tasmanian blue gum, shining gum, snow gum (fly agaric, Biota NZ: Gadgil 2005), black alder (oakbug milkcap on the owner's 'sure'), white poplar, aspen, balm of Gilead poplar and Yunnan poplar (lookalikes of black cottonwood, no GloBI lead with an entry), weeping willow (Salix ×pendulina; riverine bolete on a GloBI row for its parent S. babylonica, said in both notes), pin oak, tulip tree, Antarctic beech and downy birch: 122 pairs. Not built (owner: 'if its unsubstanciated skip'): perennial ryegrass (its only lead, shaggy inkcap 'hasHost', a grassland decomposer with no honest partnership kind) and wavy hair-grass (birch bolete: a grass is not a bolete root partner, GloBI row with no study) — both in `DECLINED_HOSTS`; stinkwort likewise (owner '5 yes'). Declined pair: shaggy inkcap ↔ Norway spruce (GloBI 'hasEctomycorrhizalHost' with no study, a decomposer; no other source links them). Declined: shaggy parasol ↔ Norway spruce — a real litter association (Wild Food UK, Totally Wild UK: most common near conifers, especially spruce), but it lives on needle litter, not roots or dead wood, so no existing kind fits (owner 24/11/2026: 'decline'). Declined on the same ground: shaggy inkcap ↔ Greek fir (one GloBI 'hasHost' row with no study; a decomposer, no root or dead-wood kind fits). White poplar's months stay empty: no source dates its inner-bark harvest (owner 24/11/2026: 'leave').
**Last leads 25/11/2026 (owner: 'are all symbiotic species linked? if so you can delete the link next section if not link them'):** 12 open pairs and one host were left. Linked: Austrian pine ↔ slippery jack and fly agaric, on GloBI 'hasHost' rows for Pinus nigra with no subspecies given (slippery jack also on two NZ PDD records 'has host Pinus nigra'; fly agaric has no NZ record for the species, so its notes say 'overseas'); this reverses the 23/11/2026 'no links' line for Austrian pine below. Declined, as no root, parasite or dead-wood kind fits (the 24/11/2026 'no honest kind, decline' rule, applied without a fresh ruling; the owner can reopen any): shaggy inkcap ↔ black locust and Psilocybe aucklandiae ↔ radiata pine (decomposers; one GloBI row each); hound's tongue fern ↔ mātai, karamū ↔ tōtara and lemonwood ↔ tōtara (epiphytes or epiphytic seedlings; one GloBI row each); Scotch broom ↔ Aleppo, Austrian, Corsican, maritime and Scots pine (two plants, one GloBI 'lives on'/'host of' row each). Eucalyptus pauciflora subsp. pauciflora is the snow gum entry, already linked to fly agaric (`HOST_ALIASES`). With nothing left open, the report no longer prints the Link next section; it comes back by itself if a refreshed `docs/association-leads.json` brings new leads.

**Next (23/11/2026): the GloBI leads, batch by batch.** `Tools/globi_symbioses.py` writes
`docs/association-leads.json`; the catalogue report's "Link next" section splits it into batches by
kind of fungus (boletes and suillus; milkcaps, amanitas and webcaps; wood-rotters and tree parasites;
ground and litter mushrooms; plants on plants), one row per fungus with its unlinked catalogue
partners (the declined pairs above are left out, counted in a chip) and the NZ plants it is recorded with that have no
entry. GloBI is the source of the leads (owner 23/11/2026: a specialised database, and Biota may
not have caught up); each lead still needs research. Since 23/11/2026 the tool drops GloBI's
'symbiont', 'mutualist' and 'commensal' records (mostly environmental DNA with no study or place, the
source of the slippery jack–heather lead) and generalists (a fungus with no root-partner record on
more than three NZ plants, such as turkey tail, honey mushroom and velvet shank). Beside each lead it
counts the Biota of New Zealand records that already name the pair (PDD rows and NZ literature such
as Gadgil 2005), as a head start, never a filter.

Partners that are still drafts get no card in the app (their page does not exist there) but count
for the reverse-link test.

## Owner decisions (16/11/2026) — these override the sections below where they differ

- **Scope: anything that requires a specific other species.** Root partners, parasites and
  hosts, and also wood-rotting fungi *when they need one particular tree* (olive oyster on southern
  beech). A generalist on any dead wood (wood ear, velvet shank) gets no link.
- **Partners with no food use get entries anyway** — do-not-eat entries (southern beeches, fly
  agaric and the like) so the fungi have a page to link to.
- **Genus-level sources ("under beech") are researched to the species** before linking. No
  link rests on a genus line; if research can't name the species, there is no link yet.
- **Death cap shows on its hosts' pages** (oak, sweet chestnut, European beech) with its
  poisonous badge — it is a symbiotic partner like any other.

## Goal

A species page shows the living partners it depends on, as tappable cards that open the partner's
page — the way lookalike cards do. Birch bolete shows a silver birch card; the silver birch page
shows birch bolete (and every other fungus that grows with it) back. Two uses:

- **Finding food.** "Under silver birch" is the single best clue for birch bolete. From the tree's
  page the forager sees every fungus worth looking for underneath it.
- **Safety.** The oak and sweet chestnut pages would list death cap among their partners — the
  most useful warning the catalogue can give someone standing under an oak looking for porcini.

## What counts as a link

Only **living partnerships** where one species is found with the other:

| Kind | Meaning | Examples in the catalogue today |
|---|---|---|
| `mycorrhizalPartner` | Root partner; the fungus fruits only near the tree | birch bolete – silver birch, slippery jack – radiata pine, larch bolete – larch, western painted suillus – Douglas fir, tawai milkcap – beech |
| `parasiteOf` / `hostOf` | One lives off the other | peppery bolete – fly agaric (reported mycoparasite), and later mistletoes, dodder, *Dactylanthus* |
| `growsOnDeadWoodOf` / `deadWoodHostOf` | Decays the wood of one particular tree only | olive oyster – southern beech (species to research) |

**Not links:** fungi that rot the dead wood of many trees (wood ear, velvet shank, brown oyster) —
nothing specific is required, and habitat already says "on dead mānuka, kānuka, gorse…".
Pollinators, food plants of insects and companion planting are out too.

Each link is a **claim on a page**, so the same rules as lookalike cards apply: a source that
states the partnership for *this* species (NZ source preferred; overseas only when it names the
same species), recorded as a dated sources line on both entries. A genus-level line ("with
*Nothofagus*") never links on its own: research it to the species (Virtual Mycota collection
hosts, Biota/Landcare records, papers) and link only the species a source names.

## Model

```swift
public nonisolated struct Association: Codable, Sendable, Hashable {
    public let kind: AssociationKind
    /// Typed like `Lookalike.entry`: an unknown id fails to decode, so a link can only name a
    /// species the catalogue has.
    public let entry: SpeciesID
    /// One short line for the card, e.g. "Its only root partner in New Zealand."
    public let note: String
}

public nonisolated enum AssociationKind: String, Codable, Sendable {
    case mycorrhizalPartner   // symmetric
    case parasiteOf, hostOf   // each other's inverse
    case growsOnDeadWoodOf, deadWoodHostOf   // each other's inverse
}
```

`ForageSpecies` gains `associations: [Association]` (decoded with `[]` as the default so existing
JSON loads unchanged). The JSON stays the source of truth; the macOS editor gets a section like
Lookalikes.

### Validation (`SpeciesValidation` + `CatalogueTests`)

- Blocking: not its own partner; empty note.
- Blocking (catalogue-wide test): **every link has its reverse** — A `mycorrhizalPartner` B ⇔
  B `mycorrhizalPartner` A; A `parasiteOf` B ⇔ B `hostOf` A; A `growsOnDeadWoodOf` B ⇔
  B `deadWoodHostOf` A. Same idea as "cards both ways", but
  enforced by a test rather than by hand.
- Shipped entries may link to drafts (a shipped card that opens a draft is a note to self, as
  with lookalikes).

## UI

- **Species page:** a "Grows with" section after Habitat, horizontal cards reusing the lookalike
  card's layout (photo from the target entry, name, scientific name, the note) without the risk
  badge. When a partner is poisonous (death cap) the card shows the target's caution badge, so
  the danger is visible without opening it.
- Section hidden when empty. Accessibility id `association.<id>` for UI tests.
- No new tab or filter for now. Later, possibly: a "Grows with" filter on the Map's finds
  ("show my oaks, then what grows under them").

## Catalogue round — seed links from what is already written

Habitat text already names most partners. Hosts **already in the catalogue**:

| Host entry | Fungi whose habitat names it |
|---|---|
| `monterey-pine` | slippery jack, saffron milk cap, rufous milkcap, peppery bolete, porcini, bluefoot bolete |
| `larch` | larch bolete |
| `douglas-fir` | western painted suillus |
| `english-oak`, `holm-oak` | death cap, oakbug milkcap, porcini, bluefoot bolete, riverine bolete |
| `sweet-chestnut` | porcini, death cap |
| `manuka`, `kanuka` | skirt webcap |

Hosts **not in the catalogue yet** (would need entries before they can be linked):

| Host | Fungi whose habitat names it | Food records to check |
|---|---|---|
| **Silver birch** *Betula pendula* | birch bolete, porcini, bluefoot, riverine bolete, coconut milkcap, downy milk-cap, ugly milkcap | sap, young leaves (PFAF + others) |
| European beech *Fagus sylvatica* | bluefoot, death cap, slimy milkcap | beech nuts (PFAF, Knox?) |
| Southern beeches — hard, red, silver, black, mountain | tawai, umere, NZ milkcap (hard beech), chalciporus aurantiacus, skirt webcap, olive oyster | probably none → doNotEat "partner" entries; which beech each fungus needs is researched first |
| Fly agaric *Amanita muscaria* | peppery bolete | poisonous → doNotEat |
| Poplar, willow, alder | riverine bolete | check each |

**Silver birch first** (the owner's example): an introduced tree with food records for sap and
leaves, checked against the usual standards (NZ presence threshold, PFAF line, NZ-source text,
two food records, sourced months, photos). Then link the seven fungi to it.

Each linked entry gets a dated line: `Associations round <date>: <partner> — '<quote>' (<source>)`.

## Steps

1. Model + decoding default + validation + reverse-link test (unit tests first).
2. Species page section + factory model + UI test on one pair.
3. Editor section (macOS tool).
4. `catalogue_report.py`: show links per entry and flag one-way links.
5. Silver birch entry (owner reviews like any group), then the seed links above, group by group.

## Still open

- Which wood-rotting fungi in the catalogue need one particular tree — to be checked fungus by
  fungus during the round, not assumed from habitat wording.
