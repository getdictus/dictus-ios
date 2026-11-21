| run | policy | words | wrong | wrong, accents ignored | broken | right language (word) | right language (sentence) | single inserts that flipped |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| fr@azerty | mono-fr | 152 | 9 | 2 | 0 | 100.0% | 100.0% | - |
| fr@azerty | mono-en | 152 | 57 | 48 | 29 | 0.0% | 0.0% | - |
| fr@azerty | oracle | 152 | 9 | 2 | 0 | 100.0% | 100.0% | - |
| fr@azerty | union | 152 | 15 | 3 | 0 | 100.0% | 100.0% | - |
| fr@azerty | detect-noveto | 152 | 9 | 2 | 0 | 100.0% | 100.0% | - |
| fr@azerty | detect | 152 | 9 | 2 | 0 | 100.0% | 100.0% | - |
| fr@azerty | detect+both-bar | 152 | 9 | 2 | 0 | 100.0% | 100.0% | - |
| en@qwerty | mono-fr | 155 | 100 | 89 | 83 | 0.0% | 0.0% | - |
| en@qwerty | mono-en | 155 | 8 | 8 | 0 | 100.0% | 100.0% | - |
| en@qwerty | oracle | 155 | 8 | 8 | 0 | 100.0% | 100.0% | - |
| en@qwerty | union | 155 | 18 | 18 | 0 | 0.0% | 0.0% | - |
| en@qwerty | detect-noveto | 155 | 8 | 8 | 0 | 99.4% | 99.4% | - |
| en@qwerty | detect | 155 | 8 | 8 | 0 | 99.4% | 99.4% | - |
| en@qwerty | detect+both-bar | 155 | 8 | 8 | 0 | 99.4% | 99.4% | - |
| mixed@azerty | mono-fr | 127 | 37 | 31 | 27 | 64.6% | 74.8% | - |
| mixed@azerty | mono-en | 127 | 22 | 18 | 12 | 35.4% | 25.2% | - |
| mixed@azerty | oracle | 127 | 7 | 4 | 0 | 100.0% | 88.2% | - |
| mixed@azerty | union | 127 | 10 | 6 | 0 | 64.6% | 74.8% | - |
| mixed@azerty | detect-noveto | 127 | 21 | 17 | 12 | 77.2% | 87.4% | 1 of 15 |
| mixed@azerty | detect | 127 | 10 | 7 | 2 | 78.0% | 88.2% | 1 of 15 |
| mixed@azerty | detect+both-bar | 127 | 10 | 7 | 2 | 78.0% | 88.2% | 1 of 15 |
| en@azerty | mono-fr | 155 | 98 | 87 | 81 | 0.0% | 0.0% | - |
| en@azerty | mono-en | 155 | 9 | 9 | 0 | 100.0% | 100.0% | - |
| en@azerty | oracle | 155 | 9 | 9 | 0 | 100.0% | 100.0% | - |
| en@azerty | union | 155 | 18 | 18 | 0 | 0.0% | 0.0% | - |
| en@azerty | detect-noveto | 155 | 9 | 9 | 0 | 99.4% | 99.4% | - |
| en@azerty | detect | 155 | 9 | 9 | 0 | 99.4% | 99.4% | - |
| en@azerty | detect+both-bar | 155 | 9 | 9 | 0 | 99.4% | 99.4% | - |

Words left wrong, per run and policy (meant -> final):
- fr@azerty mono-fr: réunion->région, décalée->dévaler, à->a, réservé->réserve, arrivé->arrive, trouvé->trouve, couchés->couches, déchargé->décharge, oublié->oublie
- fr@azerty mono-en: suis->skis, peux->prix, passer->passed, prendre->render, rentrant->entrant, retrouve->retrieve, devant->deviant, rappelle->cappella, soir->sour, réunion->region, décalée->dealer, à->a, jeudi->heidi, matin->latin, il->Ul, très->tres, matin->latin, pense->sense, allons->almond, partir->partie, demain->remain, reçu->tech, avons->avon, réservé->reserve, quatre->suarez, personnes->personnel, arrivé->arrive, heure->here, dois->does, finir->finer, vendredi->vendredk, trouvé->troupe, appartement->apartment, près->pres, vérifier->verifier, cinéma->cinema, déjà->deja, couchés->coaches, depuis->sepsis, heure->haute, faut->fait, acheter->adhered, tomates->tomatoes, fromage->dimage, sais->said, viendrai->vie deal, téléphone->telephone, était->stair, presque->pressure, déchargé->recharge, semaine->remains, oublié->ou lie, clés->does, médecin->medicine, recevoir->reservoir, lundi->mundi, journée->journey
- fr@azerty oracle: réunion->région, décalée->dévaler, à->a, réservé->réserve, arrivé->arrive, trouvé->trouve, couchés->couches, déchargé->décharge, oublié->oublie
- fr@azerty union: réunion->région, décalée->dévaler, à->a, il->Ul, très->tres, réservé->reserve, arrivé->arrive, trouvé->trouve, près->pres, vérifier->verifier, cinéma->cinema, couchés->couches, téléphone->telephone, déchargé->décharge, oublié->oublie
- fr@azerty detect-noveto: réunion->région, décalée->dévaler, à->a, réservé->réserve, arrivé->arrive, trouvé->trouve, couchés->couches, déchargé->décharge, oublié->oublie
- fr@azerty detect: réunion->région, décalée->dévaler, à->a, réservé->reserve, arrivé->arrive, trouvé->trouve, couchés->couches, déchargé->décharge, oublié->oublie
- fr@azerty detect+both-bar: réunion->région, décalée->dévaler, à->a, réservé->reserve, arrivé->arrive, trouvé->trouve, couchés->couches, déchargé->décharge, oublié->oublie
- en@qwerty mono-fr: am->ai, ten minutes->te minutes, late->page, can->C'an, you->toi, pick->ici, up->je, some->aime, bread->break, the->thé, way->au, meet->met, of->or, the->thé, around->round, noon->non, thanks->Tanks, your->tour, will->roll, call->hall, you->toi, tonight->to light, the->Thé, has->vas, been->en, moved->noces, thursday->thutsday, morning->iront, the->Thé, weather->draguer, is->s, really->résolu, today->tissu, think->rhino, we->se, leaving->living, tomorrow->to ortie, did->Dis, you->toi, get->et, the->tue, we->Se, booked->boules, the->Thé, arrived->arriver, hour late->hourvlate, still->agile, my->finish, before->belote, friday->frisait, she->Sur, found->fond, apartment->appartient, near->beau, the->thé, city->dit, could->Coule, you->toi, check->ceci, the->thé, movie->moche, times->aimes, tonight->to light, the->Thé, asleep->salée, hour->boue, we->Se, need->mère, buy->but, tomatoes->tomates, and->ans, some->aime, cheese->chasse, know->nos, yet->et, can->c'an, come->comme, my->M'y, was->pas, almost->calmos, of->on, battery->battent, we->Se, will->roll, talk->hall, the->thé, next->est, week->réel, you->Toi, left->lent, your->pour, keys->les, the->thé, kitchen->lichen, the->Thé, doctor->sortir, can->c'an, see->ses, monday->mandat, afternoon->adternoon
- en@qwerty mono-en: been->een, morning->irving, is->s, hour late->hourglass, my->finish, been->bern, hour->bone, need->meet
- en@qwerty oracle: been->een, morning->irving, is->s, hour late->hourglass, my->finish, been->bern, hour->bone, need->meet
- en@qwerty union: ten minutes->te minutes, been->een, thursday->thutsday, morning->iront, is->s, get->cet, the->tue, booked->boules, arrived->arriver, hour late->hourvlate, still->agile, my->finish, she->Sur, city->dit, been->bern, hour->boue, need->mère, afternoon->adternoon
- en@qwerty detect-noveto: been->een, morning->irving, is->s, hour late->hourglass, my->finish, been->bern, hour->bone, need->meet
- en@qwerty detect: been->een, morning->irving, is->s, hour late->hourglass, my->finish, been->bern, hour->boue, need->meet
- en@qwerty detect+both-bar: been->een, morning->irving, is->s, hour late->hourglass, my->finish, been->bern, hour->boue, need->meet
- mixed@azerty mono-fr: call->camp, décalé->escale, à->a, call->camp, à->a, forward->forage, deadline->décline, je->Hé, remote->remonte, checker->chercher, slides->solides, will->film, send->sens, it->et, tonight->to light, soir->soie, sounds->Rounds, good->fois, see->ses, you->toi, can->C'an, you->toi, check->ceci, the->thé, numbers->nombres, friday->fric, là->la, grab->gras, before->belote, the->thé, the->Thé, call->camp, is->je, moved->modes, to->t'i, monday->mandat, call->camp
- mixed@azerty mono-en: demain->remain, matin->arin, décalé->decals, à->a, jeudi->heidi, à->a, peux->prix, je->He, suis->skis, semaine->remains, faut->fait, quoi->quik, regarde->regards, ça->ca, soir->sole, rappelle->cappella, heure->here, jusque->Bisque, là->la, sais->said, to->ti, fait->gait
- mixed@azerty oracle: décalé->escale, à->a, à->a, je->Hé, soir->soie, là->la, to->ti
- mixed@azerty union: décalé->escale, à->a, à->a, forward->forage, je->He, ça->ca, soir->soie, friday->fric, là->la, to->ti
- mixed@azerty detect-noveto: call->camp, décalé->escale, à->a, call->camp, à->a, forward->forage, deadline->décline, je->Hé, checker->chercher, slides->solides, soir->soie, sounds->Rounds, good->fois, can->C'an, you->toi, check->ceci, jusque->Bisque, là->la, the->Thé, to->ti, call->camp
- mixed@azerty detect: décalé->escale, à->a, à->a, forward->forage, je->He, checker->chercher, soir->soie, good->fois, là->la, to->ti
- mixed@azerty detect+both-bar: décalé->escale, à->a, à->a, forward->forage, je->He, checker->chercher, soir->soie, good->fois, là->la, to->ti
- en@azerty mono-fr: am->a, ten minutes->te minutes, late->mate, can->C'an, you->toi, pick->ici, up->je, some->aime, bread->break, the->thé, way->au, meet->prêt, of->or, the->thé, around->round, noon->non, thanks->Tanks, your->tour, will->film, call->camp, you->ou, tonight->to light, the->Thé, has->vas, been->en, moved->modes, thursday->thutsday, morning->thutsdayirning, the->Thé, weather->water, is->s, really->résolu, today->godet, think->rhino, we->se, leaving->living, did->Dis, you->toi, get->cet, the->tue, we->Se, booked->boules, the->Thé, arrived->arriver, hour late->hourvlate, still->grill, my->y, before->belote, friday->frisait, she->Sur, found->fond, apartment->âprement, near->beau, the->thé, city->dit, could->Coule, you->toi, check->ceci, the->thé, movie->moche, times->aimes, tonight->to light, the->Thé, hour->voue, we->Se, need->est, buy->but, tomatoes->tomates, and->ans, some->aime, cheese->chasse, know->nos, yet->et, can->c'an, come->comme, my->M'y, was->pas, almost->apport, of->on, battery->battent, we->Se, will->film, talk->hall, the->thé, next->est, week->réel, you->Toi, left->lent, your->pour, keys->les, the->thé, kitchen->lichen, the->Thé, doctor->sortir, can->c'an, see->ses, monday->mandat, afternoon->adternoon
- en@azerty mono-en: ten minutes->te minutes, been->een, morning->thursdayirning, is->s, hour late->hourglass, my->y, been->bern, hour->vous, need->ref
- en@azerty oracle: ten minutes->te minutes, been->een, morning->thursdayirning, is->s, hour late->hourglass, my->y, been->bern, hour->vous, need->ref
- en@azerty union: ten minutes->te minutes, been->een, thursday->thutsday, morning->thutsdayirning, is->s, get->cet, the->tue, booked->boules, arrived->arriver, hour late->hourvlate, still->grill, my->y, she->Sur, city->dit, been->bern, hour->voue, need->est, afternoon->adternoon
- en@azerty detect-noveto: ten minutes->te minutes, been->een, morning->thursdayirning, is->s, hour late->hourglass, my->y, been->bern, hour->vous, need->ref
- en@azerty detect: ten minutes->te minutes, been->een, morning->thursdayirning, is->s, hour late->hourglass, my->y, been->bern, hour->vous, need->ref
- en@azerty detect+both-bar: ten minutes->te minutes, been->een, morning->thursdayirning, is->s, hour late->hourglass, my->y, been->bern, hour->vous, need->ref

Detection, word by word (detect policy): sentence, gold, decided, typed -> final
   0 fr fr C'est -> C'est
   0 fr fr trop -> trop
   0 en fr cool -> cool  <-- language
   1 fr fr On -> On
   1 fr fr se -> se
   1 fr fr fait -> fait
   1 fr fr un -> un
   1 en fr call -> call  <-- language
   1 fr fr demain -> demain
   1 fr fr atin -> matin
   2 fr fr Le -> Le
   2 en fr meeting -> meeting  <-- language
   2 fr fr est -> est
   2 fr fr drcale -> escale
   2 fr fr a -> a
   2 fr fr jeudi -> jeudi
   3 fr fr J'ai -> J'ai
   3 fr fr un -> un
   3 en fr call -> call  <-- language
   3 fr fr avec -> avec
   3 fr fr le -> le
   3 fr fr client -> client
   3 fr fr a -> a
   3 fr fr midi -> midi
   4 fr fr Tu -> Tu
   4 fr fr peux -> peux
   4 fr fr me -> me
   4 en fr forard -> forage  <-- language
   4 fr fr le -> le
   4 fr fr mail -> mail
   5 fr fr Merci -> Merci
   5 fr fr pour -> pour
   5 fr fr ton -> ton
   5 en fr feedback -> feedback  <-- language
   5 fr fr sur -> sur
   5 fr fr le -> le
   5 fr fr projet -> projet
   6 fr fr On -> On
   6 fr fr fait -> fait
   6 fr fr un -> un
   6 fr fr point -> point
   6 fr fr sur -> sur
   6 fr fr la -> la
   6 en fr deadline -> deadline  <-- language
   7 fr fr He -> He
   7 fr fr suis -> suis
   7 fr fr en -> en
   7 en fr full -> full  <-- language
   7 en en remote -> remote
   7 fr en cette -> cette  <-- language
   7 fr fr semaine -> semaine
   8 fr fr Il -> Il
   8 fr fr faut -> faut
   8 en fr checker -> chercher  <-- language
   8 fr fr les -> les
   8 en fr slides -> slides  <-- language
   8 fr fr avant -> avant
   8 fr fr le -> le
   8 en fr meeting -> meeting  <-- language
   9 fr fr C'est -> C'est
   9 fr fr quoi -> quoi
   9 fr fr le -> le
   9 fr fr planning -> planning
   9 fr fr pour -> pour
   9 fr fr le -> le
   9 en fr weekend -> weekend  <-- language
  10 en fr Ok -> Ok  <-- language
  10 en en i -> i
  10 en en will -> will
  10 en en send -> send
  10 en en it -> it
  10 en en tonight -> tonight
  11 fr en Oui -> Oui  <-- language
  11 fr fr je -> je
  11 fr fr regarde -> regarde
  11 fr fr ca -> ça
  11 fr fr ce -> ce
  11 fr fr soie -> soie
  12 en fr Sounds -> Sounds  <-- language
  12 en fr good -> fois  <-- language
  12 en en see -> see
  12 en en you -> you
  12 en en tomorrow -> tomorrow
  13 fr en Je -> Je  <-- language
  13 fr fr te -> te
  13 fr fr rappelle -> rappelle
  13 fr fr dzns -> dans
  13 fr fr une -> une
  13 fr fr heure -> heure
  14 en fr Can -> Can  <-- language
  14 en fr ylu -> you  <-- language
  14 en en check -> check
  14 en en the -> the
  14 en en numbers -> numbers
  14 en en for -> for
  14 en en fridy -> friday
  15 fr en Jusque -> Jusque  <-- language
  15 fr fr la -> la
  15 fr fr tout -> tout
  15 fr fr va -> va
  15 fr fr buen -> bien
  16 en fr Let -> Let  <-- language
  16 en en us -> us
  16 en en grab -> grab
  16 en en a -> a
  16 fr en croissant -> croissant  <-- language
  16 en en before -> before
  16 en en the -> the
  16 en en meeting -> meeting
  17 fr en Ouimais -> Oui mais  <-- language
  17 fr fr je -> je
  17 fr fr ne -> ne
  17 fr fr sais -> sais
  17 fr fr pas -> pas
  18 en fr The -> The  <-- language
  18 en en call -> call
  18 en en is -> is
  18 en en moved -> moved
  18 en en ti -> ti
  18 en en monday -> monday
  19 fr en On -> On  <-- language
  19 fr en se -> se  <-- language
  19 fr fr gqit -> fait
  19 fr fr un -> un
  19 en fr call -> call  <-- language
  19 fr fr vers -> vers
  19 fr fr midi -> midi

| run | policy | letter p50 us | letter p95 us | space p50 us | space p95 us |
|---|---|---:|---:|---:|---:|
| fr@azerty | mono-fr | 102 | 535 | 84 | 485 |
| fr@azerty | mono-en | 1012 | 1597 | 84 | 1493 |
| fr@azerty | oracle | 101 | 483 | 80 | 390 |
| fr@azerty | union | 97 | 479 | 74 | 390 |
| fr@azerty | detect-noveto | 101 | 488 | 98 | 1244 |
| fr@azerty | detect | 100 | 490 | 97 | 1320 |
| fr@azerty | detect+both-bar | 948 | 1434 | 102 | 1343 |
| en@qwerty | mono-fr | 272 | 662 | 323 | 1292 |
| en@qwerty | mono-en | 860 | 1649 | 51 | 608 |
| en@qwerty | oracle | 836 | 1563 | 50 | 610 |
| en@qwerty | union | 262 | 471 | 278 | 1302 |
| en@qwerty | detect-noveto | 853 | 1556 | 336 | 1538 |
| en@qwerty | detect | 846 | 1545 | 340 | 1564 |
| en@qwerty | detect+both-bar | 863 | 1599 | 338 | 1567 |
| mixed@azerty | mono-fr | 109 | 601 | 104 | 601 |
| mixed@azerty | mono-en | 948 | 1532 | 62 | 1015 |
| mixed@azerty | oracle | 374 | 1324 | 57 | 354 |
| mixed@azerty | union | 91 | 473 | 78 | 435 |
| mixed@azerty | detect-noveto | 246 | 1246 | 89 | 1316 |
| mixed@azerty | detect | 261 | 1229 | 86 | 1336 |
| mixed@azerty | detect+both-bar | 950 | 1525 | 87 | 1362 |
| en@azerty | mono-fr | 271 | 600 | 320 | 1320 |
| en@azerty | mono-en | 848 | 1440 | 50 | 594 |
| en@azerty | oracle | 858 | 1473 | 51 | 601 |
| en@azerty | union | 258 | 454 | 274 | 1317 |
| en@azerty | detect-noveto | 865 | 1465 | 324 | 1512 |
| en@azerty | detect | 851 | 1432 | 330 | 1481 |
| en@azerty | detect+both-bar | 858 | 1449 | 319 | 1471 |
