commit: d1ababbcacf565d536b8a2ad14cd0097bcdc4290
[AOSPTrieEngine] N-grams fr: loaded (5903 KiB)
[AOSPTrieEngine] Loaded fr_spellcheck.dict (39622 words)
[AOSPTrieEngine] N-grams fr: loaded (5903 KiB)
[AOSPTrieEngine] N-grams fr: loaded (5903 KiB)
[AOSPTrieEngine] Loaded fr_spellcheck.dict (39622 words)
[AOSPTrieEngine] Loaded fr_spellcheck.dict (39622 words)
loaded fr: layout=azerty
[AOSPTrieEngine] N-grams en: loaded (6010 KiB)
[AOSPTrieEngine] N-grams en: loaded (6010 KiB)
[AOSPTrieEngine] Loaded en_spellcheck.dict (40000 words)
[AOSPTrieEngine] Loaded en_spellcheck.dict (40000 words)
loaded en: layout=qwerty
[AOSPTrieEngine] N-grams de: loaded (6884 KiB)
[AOSPTrieEngine] N-grams de: loaded (6884 KiB)
[AOSPTrieEngine] Loaded de_spellcheck.dict (39847 words)
[AOSPTrieEngine] Loaded de_spellcheck.dict (39847 words)
loaded de: layout=qwertz
[AOSPTrieEngine] N-grams es: loaded (6289 KiB)
[AOSPTrieEngine] N-grams es: loaded (6289 KiB)
[AOSPTrieEngine] Loaded es_spellcheck.dict (49585 words)
[AOSPTrieEngine] Loaded es_spellcheck.dict (49585 words)
loaded es: layout=qwerty

# Split-pass bench, 678 cases

## Mid-sentence (lowercase, isAtSentenceStart false): the headline

| lang | category | cases | split correct | wrong correction (replaced / wrong split) | nothing | kept (legit) | false split | false replacement |
|---|---|---|---|---|---|---|---|---|
| fr | observed | 8 | 5 (62%) | 2 (25%): 2 / 0 | 1 (12%) | | | |
| fr | missed-space | 150 | 41 (27%) | 56 (37%): 51 / 5 | 53 (35%) | | | |
| fr | neighbour-key | 75 | 55 (73%) | 11 (15%): 9 / 2 | 9 (12%) | | | |
| fr | legit-compound | 50 | | | | 50 (100%) | 0 (0%) | 0 (0%) |
| fr | legit-rare | 50 | | | | 27 (54%) | 0 (0%) | 23 (46%) |
| en | missed-space | 50 | 21 (42%) | 17 (34%): 13 / 4 | 12 (24%) | | | |
| en | neighbour-key | 25 | 23 (92%) | 0 (0%): 0 / 0 | 2 (8%) | | | |
| en | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| en | legit-rare | 20 | | | | 7 (35%) | 3 (15%) | 10 (50%) |
| de | missed-space | 50 | 16 (32%) | 17 (34%): 13 / 4 | 17 (34%) | | | |
| de | neighbour-key | 25 | 22 (88%) | 3 (12%): 1 / 2 | 0 (0%) | | | |
| de | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| de | legit-rare | 20 | | | | 7 (35%) | 2 (10%) | 11 (55%) |
| es | missed-space | 50 | 15 (30%) | 21 (42%): 17 / 4 | 14 (28%) | | | |
| es | neighbour-key | 25 | 16 (64%) | 4 (16%): 3 / 1 | 5 (20%) | | | |
| es | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| es | legit-rare | 20 | | | | 5 (25%) | 4 (20%) | 11 (55%) |

## Start of field (autocapitalised, isAtSentenceStart true)

| lang | category | cases | split correct | wrong correction (replaced / wrong split) | nothing | kept (legit) | false split | false replacement |
|---|---|---|---|---|---|---|---|---|
| fr | observed | 8 | 5 (62%) | 2 (25%): 2 / 0 | 1 (12%) | | | |
| fr | missed-space | 150 | 41 (27%) | 56 (37%): 51 / 5 | 53 (35%) | | | |
| fr | neighbour-key | 75 | 55 (73%) | 11 (15%): 9 / 2 | 9 (12%) | | | |
| fr | legit-compound | 50 | | | | 50 (100%) | 0 (0%) | 0 (0%) |
| fr | legit-rare | 50 | | | | 27 (54%) | 0 (0%) | 23 (46%) |
| en | missed-space | 50 | 21 (42%) | 17 (34%): 13 / 4 | 12 (24%) | | | |
| en | neighbour-key | 25 | 23 (92%) | 0 (0%): 0 / 0 | 2 (8%) | | | |
| en | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| en | legit-rare | 20 | | | | 7 (35%) | 3 (15%) | 10 (50%) |
| de | missed-space | 50 | 16 (32%) | 17 (34%): 13 / 4 | 17 (34%) | | | |
| de | neighbour-key | 25 | 22 (88%) | 3 (12%): 1 / 2 | 0 (0%) | | | |
| de | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| de | legit-rare | 20 | | | | 7 (35%) | 2 (10%) | 11 (55%) |
| es | missed-space | 50 | 15 (30%) | 21 (42%): 17 / 4 | 14 (28%) | | | |
| es | neighbour-key | 25 | 16 (64%) | 4 (16%): 3 / 1 | 5 (20%) | | | |
| es | legit-compound | 20 | | | | 20 (100%) | 0 (0%) | 0 (0%) |
| es | legit-rare | 20 | | | | 5 (25%) | 4 (20%) | 11 (55%) |

## Glued cases that failed, by cause (mid-sentence)

| lang | category | failures | no bigram | correction preferred | lexicon | other | detail |
|---|---|---|---|---|---|---|---|
| fr | observed | 3 | 1 | 0 | 0 | 2 | other:needs-more-than-a-space 2, no-bigram:left-word-followers-full 1 |
| fr | missed-space | 109 | 73 | 0 | 0 | 36 | no-bigram:left-word-followers-full 66, part-too-short 31, no-bigram:left-word-has-room 7, part-not-in-dictionary 5 |
| fr | neighbour-key | 20 | 0 | 1 | 0 | 19 | part-too-short 16, part-not-in-dictionary 3, correction-preferred 1 |
| en | missed-space | 29 | 21 | 0 | 0 | 8 | no-bigram:left-word-followers-full 21, part-too-short 8 |
| en | neighbour-key | 2 | 0 | 0 | 0 | 2 | part-too-short 2 |
| de | missed-space | 34 | 26 | 0 | 0 | 8 | no-bigram:left-word-followers-full 24, part-too-short 6, no-bigram:left-word-has-room 2, other:another-split-won 1, part-not-in-dictionary 1 |
| de | neighbour-key | 3 | 0 | 0 | 0 | 3 | other:another-split-won 1, part-too-short 1, part-not-in-dictionary 1 |
| es | missed-space | 35 | 17 | 0 | 0 | 18 | part-too-short 16, no-bigram:left-word-followers-full 16, part-not-in-dictionary 2, no-bigram:left-word-has-room 1 |
| es | neighbour-key | 9 | 0 | 0 | 0 | 9 | part-too-short 7, part-not-in-dictionary 1, other:another-split-won 1 |

## Bigram coverage of the expected pairs (glued cases)

| lang | category | pairs | bigram > 0 |
|---|---|---|---|
| fr | observed | 8 | 5 (62%) |
| fr | missed-space | 150 | 57 (38%) |
| fr | neighbour-key | 75 | 34 (45%) |
| en | missed-space | 50 | 22 (44%) |
| en | neighbour-key | 25 | 14 (56%) |
| de | missed-space | 50 | 19 (38%) |
| de | neighbour-key | 25 | 7 (28%) |
| es | missed-space | 50 | 22 (44%) |
| es | neighbour-key | 25 | 6 (24%) |

## Every case that did not come out right (mid-sentence)

id	typed	expected	result	outcome	cause
fr-observed-004	cavient	ça vient	devient	replaced	other:needs-more-than-a-space
fr-observed-005	motsuivant	mot suivant	poursuivant	replaced	no-bigram:left-word-followers-full
fr-observed-008	surtoutdune	surtout d'une	-	nothing	other:needs-more-than-a-space
fr-missed-space-001	decette	de cette	recette	replaced	part-too-short
fr-missed-space-002	unebalayeuse	une balayeuse	-	nothing	part-not-in-dictionary
fr-missed-space-003	sensvraiment	sens vraiment	se vraiment	wrong-split	no-bigram:left-word-followers-full
fr-missed-space-004	lapiscine	la piscine	piscine	replaced	no-bigram:left-word-followers-full
fr-missed-space-005	pasrater	pas rater	partager	replaced	no-bigram:left-word-followers-full
fr-missed-space-007	lesrecherches	les recherches	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-008	enmeilleure	en meilleure	meilleure	replaced	no-bigram:left-word-followers-full
fr-missed-space-009	ellevous	elle vous	enlevons	replaced	no-bigram:left-word-followers-full
fr-missed-space-010	lasemaine	la semaine	semaine	replaced	no-bigram:left-word-followers-full
fr-missed-space-011	celate	cela te	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-012	pascru	pas cru	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-013	mêmede	même de	-	nothing	part-too-short
fr-missed-space-016	prendscomme	prends comme	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-018	ditmon	dit mon	citron	replaced	no-bigram:left-word-followers-full
fr-missed-space-019	appeléleur	appelé leur	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-020	corpssain	corps sain	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-021	dufrançais	du français	français	replaced	no-bigram:left-word-followers-full
fr-missed-space-022	despluies	des pluies	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-023	mauvaisgarçon	mauvais garçon	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-024	ilpense	il pense	immense	replaced	no-bigram:left-word-followers-full
fr-missed-space-025	avendu	a vendu	vendu	replaced	part-too-short
fr-missed-space-028	lacompassion	la compassion	compassion	replaced	no-bigram:left-word-followers-full
fr-missed-space-029	unbain	un bain	urbain	replaced	no-bigram:left-word-followers-full
fr-missed-space-030	frissonnaà	frissonna à	frissonna	replaced	part-too-short
fr-missed-space-031	leraconter	le raconter	raconter	replaced	no-bigram:left-word-followers-full
fr-missed-space-032	àcette	à cette	cette	replaced	part-too-short
fr-missed-space-034	suisallé	suis allé	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-039	autennis	au tennis	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-041	conseillede	conseille de	conseillère	replaced	part-too-short
fr-missed-space-042	étédifficile	été difficile	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-043	plutoute	plu toute	moumoute	replaced	no-bigram:left-word-has-room
fr-missed-space-045	grêlonsont	grêlons ont	-	nothing	no-bigram:left-word-has-room
fr-missed-space-046	mehâte	me hâte	ménage	replaced	no-bigram:left-word-followers-full
fr-missed-space-047	doitregretter	doit regretter	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-048	àtout	à tout	tout	replaced	part-too-short
fr-missed-space-050	ungénocide	un génocide	génocide	replaced	no-bigram:left-word-followers-full
fr-missed-space-051	necompte	ne compte	compte	replaced	no-bigram:left-word-followers-full
fr-missed-space-052	allergiqueaux	allergique aux	-	nothing	no-bigram:left-word-has-room
fr-missed-space-053	montexte	mon texte	contexte	replaced	no-bigram:left-word-followers-full
fr-missed-space-054	unmessage	un message	message	replaced	no-bigram:left-word-followers-full
fr-missed-space-056	ditespeut	dites peut	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-060	unrhume	un rhume	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-061	revenude	revenu de	revenue	replaced	part-too-short
fr-missed-space-063	arendu	a rendu	rendu	replaced	part-too-short
fr-missed-space-064	vousprêter	vous prêter	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-066	pluridisciplinaireset	pluridisciplinaires et	-	nothing	part-not-in-dictionary
fr-missed-space-067	vosfaiblesses	vos faiblesses	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-068	refouléset	refoulés et	-	nothing	part-not-in-dictionary
fr-missed-space-069	dubruit	du bruit	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-070	aucrayon	au crayon	crayon	replaced	no-bigram:left-word-followers-full
fr-missed-space-071	vagabondantpar	vagabondant par	-	nothing	part-not-in-dictionary
fr-missed-space-075	estégalement	est également	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-076	àprendre	à prendre	prendre	replaced	part-too-short
fr-missed-space-079	voixsuave	voix suave	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-080	danston	dans ton	caneton	replaced	no-bigram:left-word-followers-full
fr-missed-space-081	sureux	sur eux	heureux	replaced	no-bigram:left-word-followers-full
fr-missed-space-082	plusde	plus de	pousse	replaced	part-too-short
fr-missed-space-083	estde	est de	être	replaced	part-too-short
fr-missed-space-084	mâchédes	mâché des	-	nothing	no-bigram:left-word-has-room
fr-missed-space-085	proprefils	propre fils	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-086	avonsde	avons de	avons	replaced	part-too-short
fr-missed-space-087	véritablemotif	véritable motif	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-088	mepermets	me permets	permets	replaced	no-bigram:left-word-followers-full
fr-missed-space-092	deharicots	de haricots	haricots	replaced	part-too-short
fr-missed-space-093	detéléphone	de téléphone	téléphone	replaced	part-too-short
fr-missed-space-095	rique	ri que	risque	replaced	part-too-short
fr-missed-space-097	accourenttous	accourent tous	-	nothing	no-bigram:left-word-has-room
fr-missed-space-098	retourneraià	retournerai à	-	nothing	part-too-short
fr-missed-space-099	detemps	de temps	temps	replaced	part-too-short
fr-missed-space-100	retientéveillé	retient éveillé	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-101	chosesous	chose sous	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-102	nesommes	ne sommes	sommes	replaced	no-bigram:left-word-followers-full
fr-missed-space-103	monentendement	mon entendement	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-104	lebardot	le bardot	le argot	wrong-split	part-not-in-dictionary
fr-missed-space-105	prêtsà	prêts à	prêts	replaced	part-too-short
fr-missed-space-106	samémoire	sa mémoire	mémoire	replaced	part-too-short
fr-missed-space-108	tempsde	temps de	temps	replaced	part-too-short
fr-missed-space-109	estdans	est dans	dedans	replaced	no-bigram:left-word-followers-full
fr-missed-space-110	jeparle	je parle	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-112	cachéça	caché ça	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-113	hurlenttoujours	hurlent toujours	hurle toujours	wrong-split	no-bigram:left-word-has-room
fr-missed-space-114	soufflaitdans	soufflait dans	-	nothing	no-bigram:left-word-has-room
fr-missed-space-121	enterminale	en terminale	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-122	planeest	plane est	plantes	replaced	no-bigram:left-word-followers-full
fr-missed-space-123	demal	de mal	-	nothing	part-too-short
fr-missed-space-124	besoinde	besoin de	besoin	replaced	part-too-short
fr-missed-space-125	lamanière	la manière	manière	replaced	no-bigram:left-word-followers-full
fr-missed-space-126	copiesde	copies de	-	nothing	part-too-short
fr-missed-space-127	rarementà	rarement à	rarement	replaced	part-too-short
fr-missed-space-128	villefurent	ville furent	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-131	contentde	content de	conte de	wrong-split	part-too-short
fr-missed-space-132	partirde	partir de	partirez	replaced	part-too-short
fr-missed-space-133	toutà	tout à	tout	replaced	part-too-short
fr-missed-space-134	poupéeà	poupée à	poupée	replaced	part-too-short
fr-missed-space-135	moinsde	moins de	moi de	wrong-split	part-too-short
fr-missed-space-136	douleurlorsque	douleur lorsque	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-137	agirà	agir à	agira	replaced	part-too-short
fr-missed-space-138	cetélève	cet élève	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-139	toujoursfatigué	toujours fatigué	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-140	sonoisiveté	son oisiveté	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-141	adolescentsi	adolescent si	adolescents	replaced	no-bigram:left-word-followers-full
fr-missed-space-143	icipour	ici pour	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-144	sonparapluie	son parapluie	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-145	pourraitorganiser	pourrait organiser	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-146	leursparapluies	leurs parapluies	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-147	hontequand	honte quand	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-148	unehistoire	une histoire	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-149	pasdire	pas dire	-	nothing	no-bigram:left-word-followers-full
fr-missed-space-150	étaitinterdit	était interdit	-	nothing	no-bigram:left-word-followers-full
fr-neighbour-key-001	unnde	un de	-	nothing	part-too-short
fr-neighbour-key-004	debvotre	de votre	renvoyer	replaced	part-too-short
fr-neighbour-key-005	demandenà	demande à	-	nothing	part-too-short
fr-neighbour-key-009	anfélicité	a félicité	félicité	replaced	part-too-short
fr-neighbour-key-016	debchose	de chose	-	nothing	part-too-short
fr-neighbour-key-019	ancouvert	a couvert	-	nothing	part-too-short
fr-neighbour-key-021	lanrue	la rue	langue	replaced	correction-preferred
fr-neighbour-key-022	êtrebpréservés	être préservés	être préservée	wrong-split	part-not-in-dictionary
fr-neighbour-key-024	contrariezbpas	contrariez pas	-	nothing	part-not-in-dictionary
fr-neighbour-key-036	debserre	de serre	-	nothing	part-too-short
fr-neighbour-key-038	absentbà	absent à	-	nothing	part-too-short
fr-neighbour-key-041	parlernà	parler à	parlera	replaced	part-too-short
fr-neighbour-key-053	jamaisnà	jamais à	jamais	replaced	part-too-short
fr-neighbour-key-058	pasbà	pas à	passa	replaced	part-too-short
fr-neighbour-key-059	denla	de la	cela	replaced	part-too-short
fr-neighbour-key-061	denmerveilleux	de merveilleux	-	nothing	part-too-short
fr-neighbour-key-062	donnébde	donné de	-	nothing	part-too-short
fr-neighbour-key-064	sontbhabitées	sont habitées	sont habites	wrong-split	part-not-in-dictionary
fr-neighbour-key-068	abquelques	a quelques	quelques	replaced	part-too-short
fr-neighbour-key-069	pasnde	pas de	passe	replaced	part-too-short
fr-legit-rare-001	agenouillés	agenouillés	agenouillée	false-replacement	single-word-correction
fr-legit-rare-002	sainfoin	sainfoin	saindoux	false-replacement	single-word-correction
fr-legit-rare-005	plateformes	plateformes	plateforme	false-replacement	single-word-correction
fr-legit-rare-007	effrontément	effrontément	affrontement	false-replacement	single-word-correction
fr-legit-rare-009	segments	segments	serments	false-replacement	single-word-correction
fr-legit-rare-011	courriel	courriel	courrier	false-replacement	single-word-correction
fr-legit-rare-012	corrigée	corrigée	corriger	false-replacement	single-word-correction
fr-legit-rare-013	mendiait	mendiait	mendiant	false-replacement	single-word-correction
fr-legit-rare-015	basketball	basketball	baseball	false-replacement	single-word-correction
fr-legit-rare-016	copierez	copierez	coopérez	false-replacement	single-word-correction
fr-legit-rare-018	optiques	optiques	optique	false-replacement	single-word-correction
fr-legit-rare-019	psychanalystes	psychanalystes	psychanalyste	false-replacement	single-word-correction
fr-legit-rare-021	renommés	renommés	renommée	false-replacement	single-word-correction
fr-legit-rare-023	blanquette	blanquette	banquette	false-replacement	single-word-correction
fr-legit-rare-024	permuter	permuter	percuter	false-replacement	single-word-correction
fr-legit-rare-025	décapités	décapités	décapitée	false-replacement	single-word-correction
fr-legit-rare-027	fureteur	fureteur	directeur	false-replacement	single-word-correction
fr-legit-rare-028	exportateur	exportateur	explorateur	false-replacement	single-word-correction
fr-legit-rare-029	dégourdi	dégourdi	dégourdir	false-replacement	single-word-correction
fr-legit-rare-033	dévastatrices	dévastatrices	dévastatrice	false-replacement	single-word-correction
fr-legit-rare-044	réutilisation	réutilisation	utilisation	false-replacement	single-word-correction
fr-legit-rare-047	intoxications	intoxications	intoxication	false-replacement	single-word-correction
fr-legit-rare-050	attirants	attirants	attirante	false-replacement	single-word-correction
en-missed-space-001	aproblem	a problem	problem	replaced	part-too-short
en-missed-space-003	isgoing	is going	ongoing	replaced	no-bigram:left-word-followers-full
en-missed-space-004	hasabsolutely	has absolutely	-	nothing	no-bigram:left-word-followers-full
en-missed-space-006	itnow	it now	know	replaced	part-too-short
en-missed-space-007	iscold	is cold	-	nothing	no-bigram:left-word-followers-full
en-missed-space-008	ofstuff	of stuff	stuff	replaced	part-too-short
en-missed-space-011	adozen	a dozen	dozen	replaced	part-too-short
en-missed-space-013	ofconduct	of conduct	conduct	replaced	part-too-short
en-missed-space-016	themyet	them yet	the yet	wrong-split	no-bigram:left-word-followers-full
en-missed-space-017	tostop	to stop	-	nothing	no-bigram:left-word-followers-full
en-missed-space-018	costof	cost of	costly	replaced	part-too-short
en-missed-space-021	makeothers	make others	-	nothing	no-bigram:left-word-followers-full
en-missed-space-024	ofbread	of bread	thread	replaced	part-too-short
en-missed-space-026	thepolitician	the politician	-	nothing	no-bigram:left-word-followers-full
en-missed-space-027	fromkindergarten	from kindergarten	fro kindergarten	wrong-split	no-bigram:left-word-followers-full
en-missed-space-028	sameperiod	same period	-	nothing	no-bigram:left-word-followers-full
en-missed-space-029	threechildren	three children	-	nothing	no-bigram:left-word-followers-full
en-missed-space-030	everhappening	ever happening	-	nothing	no-bigram:left-word-followers-full
en-missed-space-032	touristseverywhere	tourists everywhere	-	nothing	no-bigram:left-word-followers-full
en-missed-space-035	yourmoney	your money	your obey	wrong-split	no-bigram:left-word-followers-full
en-missed-space-036	inpain	in pain	indian	replaced	no-bigram:left-word-followers-full
en-missed-space-037	cardtricks	card tricks	-	nothing	no-bigram:left-word-followers-full
en-missed-space-040	tovisit	to visit	visit	replaced	no-bigram:left-word-followers-full
en-missed-space-041	womenlove	women love	-	nothing	no-bigram:left-word-followers-full
en-missed-space-042	thatas	that as	thats	replaced	part-too-short
en-missed-space-043	darkchocolate	dark chocolate	-	nothing	no-bigram:left-word-followers-full
en-missed-space-046	doingthat	doing that	doi that	wrong-split	no-bigram:left-word-followers-full
en-missed-space-048	hadyour	had your	harbour	replaced	no-bigram:left-word-followers-full
en-missed-space-050	tohold	to hold	tools	replaced	no-bigram:left-word-followers-full
en-neighbour-key-004	sonfluently	so fluently	-	nothing	part-too-short
en-neighbour-key-021	ifmwe	if we	-	nothing	part-too-short
en-legit-rare-002	consonants	consonants	consonant	false-replacement	single-word-correction
en-legit-rare-003	artemisinin	artemisinin	arte simon	false-split	split-pass
en-legit-rare-004	coolness	coolness	cool ess	false-split	split-pass
en-legit-rare-005	sleeplessness	sleeplessness	sleepless ess	false-split	split-pass
en-legit-rare-006	uncovers	uncovers	uncover	false-replacement	single-word-correction
en-legit-rare-007	exorcise	exorcise	exercise	false-replacement	single-word-correction
en-legit-rare-008	squirmed	squirmed	squires	false-replacement	single-word-correction
en-legit-rare-010	consoled	consoled	consoles	false-replacement	single-word-correction
en-legit-rare-013	worshippers	worshippers	worshipped	false-replacement	single-word-correction
en-legit-rare-014	apathetic	apathetic	pathetic	false-replacement	single-word-correction
en-legit-rare-015	digitize	digitize	digitized	false-replacement	single-word-correction
en-legit-rare-017	parachutes	parachutes	parachute	false-replacement	single-word-correction
en-legit-rare-018	baptised	baptised	baptized	false-replacement	single-word-correction
de-missed-space-001	alleinesein	alleine sein	alleinsein	replaced	no-bigram:left-word-followers-full
de-missed-space-002	aufhörenzu	aufhören zu	aufhören	replaced	part-too-short
de-missed-space-003	weißnicht	weiß nicht	weiß ich	wrong-split	other:another-split-won
de-missed-space-005	wenigerhäufig	weniger häufig	-	nothing	no-bigram:left-word-followers-full
de-missed-space-006	gingins	ging ins	-	nothing	no-bigram:left-word-followers-full
de-missed-space-007	nichtden	nicht den	nichten	replaced	no-bigram:left-word-followers-full
de-missed-space-008	kennenkeine	kennen keine	kenne keine	wrong-split	no-bigram:left-word-followers-full
de-missed-space-010	dasaussah	das aussah	-	nothing	no-bigram:left-word-followers-full
de-missed-space-011	esjetzt	es jetzt	jetzt	replaced	no-bigram:left-word-followers-full
de-missed-space-013	inein	in ein	nein	replaced	no-bigram:left-word-followers-full
de-missed-space-015	mirgeraten	mir geraten	-	nothing	no-bigram:left-word-followers-full
de-missed-space-016	dereinzige	der einzige	-	nothing	no-bigram:left-word-followers-full
de-missed-space-017	michschon	mich schon	muchachos	replaced	no-bigram:left-word-followers-full
de-missed-space-018	vondeinen	von deinen	-	nothing	no-bigram:left-word-followers-full
de-missed-space-019	daßjemand	daß jemand	-	nothing	no-bigram:left-word-followers-full
de-missed-space-020	istzu	ist zu	jetzt	replaced	part-too-short
de-missed-space-024	einerjapanische	einer japanische	-	nothing	no-bigram:left-word-followers-full
de-missed-space-025	abersobald	aber sobald	-	nothing	no-bigram:left-word-followers-full
de-missed-space-026	vielefrischgebackene	viele frischgebackene	-	nothing	part-not-in-dictionary
de-missed-space-027	jagesagt	ja gesagt	gesagt	replaced	part-too-short
de-missed-space-028	ihrenrichtigen	ihren richtigen	ihre richtigen	wrong-split	no-bigram:left-word-followers-full
de-missed-space-031	duso	du so	also	replaced	part-too-short
de-missed-space-032	nichtgeweint	nicht geweint	-	nothing	no-bigram:left-word-followers-full
de-missed-space-033	zuarbeiten	zu arbeiten	arbeiten	replaced	part-too-short
de-missed-space-034	istkein	ist kein	-	nothing	no-bigram:left-word-followers-full
de-missed-space-037	mitgehensollen	mitgehen sollen	-	nothing	no-bigram:left-word-has-room
de-missed-space-040	mirso	mir so	wieso	replaced	part-too-short
de-missed-space-041	duschlägst	du schlägst	schlägst	replaced	no-bigram:left-word-followers-full
de-missed-space-042	bewohntdiesen	bewohnt diesen	-	nothing	no-bigram:left-word-has-room
de-missed-space-043	kamherunter	kam herunter	-	nothing	no-bigram:left-word-followers-full
de-missed-space-044	oderschlechte	oder schlechte	-	nothing	no-bigram:left-word-followers-full
de-missed-space-045	esfünf	es fünf	fünf	replaced	no-bigram:left-word-followers-full
de-missed-space-047	sollenkünftig	sollen künftig	solle künftig	wrong-split	no-bigram:left-word-followers-full
de-missed-space-049	mehrausruhen	mehr ausruhen	-	nothing	no-bigram:left-word-followers-full
de-neighbour-key-010	einennhier	einen hier	eine hier	wrong-split	other:another-split-won
de-neighbour-key-022	führtenzu	führte zu	führten	replaced	part-too-short
de-neighbour-key-024	frommanxiety	from anxiety	from society	wrong-split	part-not-in-dictionary
de-legit-rare-003	ausdenkt	ausdenkt	auskennt	false-replacement	single-word-correction
de-legit-rare-004	informierter	informierter	informierte	false-replacement	single-word-correction
de-legit-rare-006	entgegnen	entgegnen	entfernen	false-replacement	single-word-correction
de-legit-rare-007	etlichen	etlichen	etliche	false-replacement	single-word-correction
de-legit-rare-008	merklich	merklich	wirklich	false-replacement	single-word-correction
de-legit-rare-009	literarischen	literarischen	literarische	false-replacement	single-word-correction
de-legit-rare-010	erkämpft	erkämpft	gekämpft	false-replacement	single-word-correction
de-legit-rare-012	aufbekommen	aufbekommen	aufgenommen	false-replacement	single-word-correction
de-legit-rare-014	schüchternes	schüchternes	schüchterne	false-replacement	single-word-correction
de-legit-rare-016	verbessere	verbessere	ver bessere	false-split	split-pass
de-legit-rare-017	edelsten	edelsten	edelstein	false-replacement	single-word-correction
de-legit-rare-018	zusammenhängenden	zusammenhängenden	zusammenhänge den	false-split	split-pass
de-legit-rare-019	europäisch	europäisch	europäische	false-replacement	single-word-correction
es-missed-space-001	yasentir	y asentir	asentir	replaced	part-too-short
es-missed-space-004	simbolizanla	simbolizan la	simboliza la	wrong-split	part-not-in-dictionary
es-missed-space-005	miausencia	mi ausencia	ausencia	replaced	no-bigram:left-word-followers-full
es-missed-space-006	penséisde	penséis de	penséis	replaced	part-too-short
es-missed-space-007	altransporte	al transporte	transporte	replaced	part-too-short
es-missed-space-008	dehaber	de haber	-	nothing	part-too-short
es-missed-space-009	nobaja	no baja	-	nothing	part-too-short
es-missed-space-011	queno	que no	bueno	replaced	part-too-short
es-missed-space-012	fuerobado	fue robado	-	nothing	no-bigram:left-word-followers-full
es-missed-space-014	trazamosla	trazamos la	traza isla	wrong-split	part-not-in-dictionary
es-missed-space-017	quecasi	que casi	quedado	replaced	no-bigram:left-word-followers-full
es-missed-space-019	aoler	a oler	oler	replaced	part-too-short
es-missed-space-020	eseentonces	ese entonces	-	nothing	no-bigram:left-word-followers-full
es-missed-space-021	consejosabio	consejo sabio	-	nothing	no-bigram:left-word-followers-full
es-missed-space-022	todassean	todas sean	-	nothing	no-bigram:left-word-followers-full
es-missed-space-023	deinformación	de información	desinformación	replaced	part-too-short
es-missed-space-024	sabercuanto	saber cuanto	-	nothing	no-bigram:left-word-followers-full
es-missed-space-025	tienetreinta	tiene treinta	tie treinta	wrong-split	no-bigram:left-word-followers-full
es-missed-space-026	componenel	componen el	-	nothing	part-too-short
es-missed-space-027	despuésde	después de	después	replaced	part-too-short
es-missed-space-028	lagustaba	la gustaba	gustaba	replaced	no-bigram:left-word-followers-full
es-missed-space-031	puedecomer	puede comer	-	nothing	no-bigram:left-word-followers-full
es-missed-space-032	elperro	el perro	experto	replaced	part-too-short
es-missed-space-033	dealegría	de alegría	alegría	replaced	part-too-short
es-missed-space-035	unsentido	un sentido	sentido	replaced	no-bigram:left-word-followers-full
es-missed-space-037	unpaso	un paso	-	nothing	no-bigram:left-word-followers-full
es-missed-space-039	estánburlando	están burlando	está burlando	wrong-split	no-bigram:left-word-followers-full
es-missed-space-041	viel	vi el	bien	replaced	part-too-short
es-missed-space-042	nosconocíamos	nos conocíamos	-	nothing	no-bigram:left-word-followers-full
es-missed-space-044	estadoallí	estado allí	-	nothing	no-bigram:left-word-followers-full
es-missed-space-045	gustael	gusta el	gustado	replaced	part-too-short
es-missed-space-046	laenergía	la energía	energía	replaced	no-bigram:left-word-followers-full
es-missed-space-047	pulserade	pulsera de	pulseras	replaced	part-too-short
es-missed-space-048	deflauta	de flauta	-	nothing	part-too-short
es-missed-space-049	leítres	leí tres	-	nothing	no-bigram:left-word-has-room
es-neighbour-key-001	denmí	de mí	denme	replaced	part-too-short
es-neighbour-key-010	reescribirnel	reescribir el	-	nothing	part-too-short
es-neighbour-key-014	ybasí	y así	-	nothing	part-too-short
es-neighbour-key-018	demtres	de tres	demores	replaced	part-too-short
es-neighbour-key-019	dencenar	de cenar	centenar	replaced	part-too-short
es-neighbour-key-020	debidiotas	de idiotas	-	nothing	part-too-short
es-neighbour-key-021	formaranmpequeñas	formaran pequeñas	-	nothing	part-not-in-dictionary
es-neighbour-key-022	vasonde	vaso de	-	nothing	part-too-short
es-neighbour-key-025	producennmuchos	producen muchos	produce muchos	wrong-split	other:another-split-won
es-legit-rare-001	neonazis	neonazis	neo aziz	false-split	split-pass
es-legit-rare-002	pronombres	pronombres	pro hombres	false-split	split-pass
es-legit-rare-003	incentivar	incentivar	investigar	false-replacement	single-word-correction
es-legit-rare-006	andantes	andantes	andante	false-replacement	single-word-correction
es-legit-rare-007	chubasquero	chubasquero	chu arquero	false-split	split-pass
es-legit-rare-008	rehusaron	rehusaron	revisaron	false-replacement	single-word-correction
es-legit-rare-011	oculista	oculista	oculta	false-replacement	single-word-correction
es-legit-rare-012	soleados	soleados	soldados	false-replacement	single-word-correction
es-legit-rare-013	atosigada	atosigada	arraigada	false-replacement	single-word-correction
es-legit-rare-014	mensualmente	mensualmente	me usualmente	false-split	split-pass
es-legit-rare-016	enseñáis	enseñáis	enseñas	false-replacement	single-word-correction
es-legit-rare-017	alborozados	alborozados	alborotador	false-replacement	single-word-correction
es-legit-rare-018	colibríes	colibríes	colibrí	false-replacement	single-word-correction
es-legit-rare-019	polleras	polleras	pollera	false-replacement	single-word-correction
es-legit-rare-020	ambiguas	ambiguas	antiguas	false-replacement	single-word-correction
