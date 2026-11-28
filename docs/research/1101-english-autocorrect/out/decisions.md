# Decision logs for every word a Dictus variant got wrong (#1101)

The typing journal (#1001) of the DEBUG replay, `run.sh --journal` on develop `a5ef8a71`, switches off and then `--spatial`: for each word of the list below, its `TJ WORD` line (what the space bar did) and its `TJ WHY` lines (the branch, and the trie's ranked candidates with cost, frequency and bigram context). The replayed text is byte-identical to the Release replay's (`out/develop-off`, `out/develop-spatial`). Corpus text only: no user text.

## Switches off

```
TJ WORD #25 typed="Ill" prev=nil final="I'll" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #25 AUTOCORRECT branch=contextual-contraction orig="Ill" corr="I'll" prev=nil
TJ WHY #25 AUTOCORRECT-APPLY-BEFORE word="Ill" corr="I'll" prev=nil ctx="Ill"
TJ WHY #25 MIRROR-PROBE seq=9 ev=autocorrect-deleted off=-5 mir="" mlen=0 pred="CYou'" plen=5
TJ WHY #25 MIRROR-PROBE seq=10 ev=autocorrect-applied off=0 mir="I'll " mlen=5 pred="CYou'I'll " plen=10
TJ WHY #25 MIRROR-RECONVERGE seq=10 was=-5 after=autocorrect-deleted ev=autocorrect-applied
TJ WHY #25 APPLIED orig="Ill" → "I'll" prev=nil
TJ WORD #35 typed="ill" prev="is" final="ill" outcome=kept by=space previews=3
TJ WHY #35 AUTOCORRECT-SKIP word="ill" reason=already-valid
TJ WORD #40 typed="Its" prev=nil final="It's" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #40 AUTOCORRECT branch=contextual-contraction orig="Its" corr="It's" prev=nil
TJ WHY #40 AUTOCORRECT-APPLY-BEFORE word="Its" corr="It's" prev=nil ctx="Its"
TJ WHY #40 MIRROR-PROBE seq=13 ev=autocorrect-deleted off=? mir="" mlen=0 pred="My grandma is ill so i" plen=22
TJ WHY #40 MIRROR-ADOPT seq=13 ev=autocorrect-deleted reason=unaligned tail="" len=0
TJ WHY #40 MIRROR-PROBE seq=14 ev=autocorrect-applied off=0 mir="It's " mlen=5 pred="It's " plen=5
TJ WHY #40 APPLIED orig="Its" → "It's" prev=nil
TJ WORD #43 typed="were" prev="so" final="were" outcome=kept by=space previews=4
TJ WHY #43 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #50 typed="its" prev="hurt" final="its" outcome=kept by=space previews=3
TJ WHY #50 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #56 typed="were" prev="We" final="were" outcome=kept by=space previews=4
TJ WHY #56 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #78 typed="venmo" prev="you" final="venom" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #78 TRIE-CANDIDATES word="venmo" winner="venom" ranked=["venom"(cost=0.70 freq=39677 ctx=0), "demo"(cost=1.72 freq=46344 ctx=0), "enom"(cost=1.70 freq=41905 ctx=0), "banjo"(cost=1.65 freq=39759 ctx=0), "nemo"(cost=1.70 freq=39464 ctx=0)]
TJ WHY #78 AUTOCORRECT branch=trie orig="venmo" corr="venom" prev="you"
TJ WHY #78 AUTOCORRECT-APPLY-BEFORE word="venmo" corr="venom" prev="you" ctx="Can you venmo"
TJ WHY #78 MIRROR-PROBE seq=25 ev=autocorrect-deleted off=? mir="Can you " mlen=8 pred="i didn't even like the m" plen=28
TJ WHY #78 MIRROR-ADOPT seq=25 ev=autocorrect-deleted reason=unaligned tail="Can you " len=8
TJ WHY #78 MIRROR-PROBE seq=26 ev=autocorrect-applied off=0 mir="Can you venom " mlen=14 pred="Can you venom " plen=14
TJ WHY #78 APPLIED orig="venmo" → "venom" prev="you"
TJ WORD #94 typed="ro" prev="go" final="ro" outcome=kept by=space previews=2
TJ WHY #94 AUTOCORRECT-SKIP word="ro" reason=already-valid
TJ WORD #103 typed="strat" prev="game" final="strat" outcome=kept by=space previews=6
TJ WHY #103 AUTOCORRECT-SKIP word="strat" reason=already-valid
TJ WORD #121 typed="coworker" prev="My" final="coworkers" outcome=autocorrected by=space branch=trie previews=13
TJ WHY #121 TRIE-CANDIDATES word="coworker" winner="coworkers" ranked=["coworkers"(cost=1.00 freq=36959 ctx=0), "worker"(cost=2.00 freq=45565 ctx=0), "cooker"(cost=2.00 freq=41844 ctx=0)]
TJ WHY #121 AUTOCORRECT branch=trie orig="coworker" corr="coworkers" prev="My"
TJ WHY #121 AUTOCORRECT-APPLY-BEFORE word="coworker" corr="coworkers" prev="My" ctx="My coworker"
TJ WHY #121 MIRROR-PROBE seq=39 ev=autocorrect-deleted off=? mir="My " mlen=3 pred="That's def" plen=10
TJ WHY #121 MIRROR-ADOPT seq=39 ev=autocorrect-deleted reason=unaligned tail="My " len=3
TJ WHY #121 MIRROR-PROBE seq=40 ev=autocorrect-applied off=0 mir="My coworkers " mlen=13 pred="My coworkers " plen=13
TJ WHY #121 APPLIED orig="coworker" → "coworkers" prev="My"
TJ WORD #122 typed="jaxon" prev="coworkers" final="jax on" outcome=autocorrected by=space branch=split-bigram previews=8
TJ WHY #122 SPLIT word="jaxon" boundary=nil bigram="jax on" → "jax on"
TJ WHY #122 AUTOCORRECT branch=split-bigram orig="jaxon" corr="jax on" prev="coworkers"
TJ WHY #122 NOTE bigram-rerank skipped (no evidence) for "jaxon" prev="coworkers", keeping "jax on"
TJ WHY #122 AUTOCORRECT-APPLY-BEFORE word="jaxon" corr="jax on" prev="coworkers" ctx="My coworkers jaxon"
TJ WHY #122 MIRROR-PROBE seq=41 ev=autocorrect-deleted off=+5 mir="My coworkers " mlen=13 pred="My cowor" plen=8
TJ WHY #122 MIRROR-PROBE seq=42 ev=autocorrect-applied off=? mir="My coworkers jax on " mlen=20 pred="My coworjax on " plen=15
TJ WHY #122 MIRROR-ADOPT seq=42 ev=autocorrect-applied reason=unaligned tail="My coworkers jax on " len=20
TJ WHY #122 APPLIED orig="jaxon" → "jax on" prev="coworkers"
TJ WORD #145 typed="ill" prev="Ok" final="I'll" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #145 AUTOCORRECT branch=contextual-contraction orig="ill" corr="I'll" prev="Ok"
TJ WHY #145 AUTOCORRECT-APPLY-BEFORE word="ill" corr="I'll" prev="Ok" ctx="Ok ill"
TJ WHY #145 MIRROR-PROBE seq=47 ev=autocorrect-deleted off=? mir="Ok " mlen=3 pred="Kayla is comi" plen=13
TJ WHY #145 MIRROR-ADOPT seq=47 ev=autocorrect-deleted reason=unaligned tail="Ok " len=3
TJ WHY #145 MIRROR-PROBE seq=48 ev=autocorrect-applied off=0 mir="Ok I'll " mlen=8 pred="Ok I'll " plen=8
TJ WHY #145 APPLIED orig="ill" → "I'll" prev="Ok"
TJ WORD #151 typed="hime" prev="get" final="home" outcome=autocorrected by=space branch=trie previews=5
TJ WHY #151 TRIE-CANDIDATES word="hime" winner="home" ranked=["home"(cost=0.40 freq=57579 ctx=0), "time"(cost=0.64 freq=56645 ctx=0), "hike"(cost=0.45 freq=41619 ctx=0), "hume"(cost=0.40 freq=39026 ctx=0), "him"(cost=1.00 freq=52744 ctx=33645)]
TJ WHY #151 AUTOCORRECT branch=trie orig="hime" corr="home" prev="get"
TJ WHY #151 AUTOCORRECT-APPLY-BEFORE word="hime" corr="home" prev="get" ctx=" I'll call you when i get hime"
TJ WHY #151 MIRROR-PROBE seq=49 ev=autocorrect-deleted off=? mir="'ll call you when i get " mlen=28 pred="Ok I" plen=4
TJ WHY #151 MIRROR-ADOPT seq=49 ev=autocorrect-deleted reason=unaligned tail="'ll call you when i get " len=28
TJ WHY #151 MIRROR-PROBE seq=50 ev=autocorrect-applied off=0 mir="all you when i get home " mlen=33 pred="all you when i get home " plen=33
TJ WHY #151 APPLIED orig="hime" → "home" prev="get"
TJ WORD #196 typed="Lets" prev=nil final="Lets" outcome=kept by=space previews=4
TJ WHY #196 AUTOCORRECT-SKIP word="Lets" reason=already-valid
TJ WORD #203 typed="lets" prev="He" final="lets" outcome=kept by=space previews=4
TJ WHY #203 AUTOCORRECT-SKIP word="lets" reason=already-valid
TJ WORD #210 typed="wont" prev="I" final="wont" outcome=kept by=space previews=4
TJ WHY #210 AUTOCORRECT-SKIP word="wont" reason=already-valid
TJ WORD #217 typed="Id" prev=nil final="Id" outcome=kept by=space previews=2
TJ WHY #217 AUTOCORRECT-SKIP word="Id" reason=already-valid
TJ WORD #225 typed="Well" prev=nil final="Well" outcome=kept by=space previews=4
TJ WHY #225 AUTOCORRECT-SKIP word="Well" reason=already-valid
TJ WORD #232 typed="Well" prev=nil final="Well" outcome=kept by=space previews=4
TJ WHY #232 AUTOCORRECT-SKIP word="Well" reason=already-valid
TJ WORD #237 typed="expectd" prev="than" final="expects" outcome=autocorrected by=space branch=trie previews=10
TJ WHY #237 TRIE-CANDIDATES word="expectd" winner="expects" ranked=["expects"(cost=0.40 freq=42442 ctx=0), "expected"(cost=1.00 freq=48910 ctx=0), "expect"(cost=1.00 freq=47676 ctx=0), "experts"(cost=1.21 freq=47449 ctx=0), "aspects"(cost=1.65 freq=47126 ctx=0)]
TJ WHY #237 AUTOCORRECT branch=trie orig="expectd" corr="expects" prev="than"
TJ WHY #237 AUTOCORRECT-APPLY-BEFORE word="expectd" corr="expects" prev="than" ctx=" that went better than expectd"
TJ WHY #237 MIRROR-PROBE seq=69 ev=autocorrect-deleted off=? mir="l that went better than " mlen=27 pred="That's so" plen=9
TJ WHY #237 MIRROR-ADOPT seq=69 ev=autocorrect-deleted reason=unaligned tail="l that went better than " len=27
TJ WHY #237 MIRROR-PROBE seq=70 ev=autocorrect-applied off=0 mir="ent better than expects " mlen=35 pred="ent better than expects " plen=35
TJ WHY #237 APPLIED orig="expectd" → "expects" prev="than"
TJ WORD #246 typed="Idk" prev=nil final="Idl" outcome=autocorrected by=space branch=trie previews=4
TJ WHY #246 TRIE-CANDIDATES word="Idk" winner="idl" ranked=["idl"(cost=0.40 freq=38347 ctx=0), "id"(cost=1.00 freq=51085 ctx=0), "isk"(cost=0.40 freq=37199 ctx=0), "idm"(cost=0.45 freq=37440 ctx=0), "jdk"(cost=0.50 freq=38056 ctx=0)]
TJ WHY #246 AUTOCORRECT branch=trie orig="Idk" corr="Idl" prev=nil
TJ WHY #246 AUTOCORRECT-APPLY-BEFORE word="Idk" corr="Idl" prev=nil ctx="Idk"
TJ WHY #246 MIRROR-PROBE seq=73 ev=autocorrect-deleted off=? mir="" mlen=0 pred=" hear about the new iPho" plen=35
TJ WHY #246 MIRROR-ADOPT seq=73 ev=autocorrect-deleted reason=unaligned tail="" len=0
TJ WHY #246 MIRROR-PROBE seq=74 ev=autocorrect-applied off=0 mir="Idl " mlen=4 pred="Idl " plen=4
TJ WHY #246 APPLIED orig="Idk" → "Idl" prev=nil
TJ WORD #249 typed="wnats" prev="he" final="whats" outcome=autocorrected by=space branch=trie previews=8
TJ WHY #249 TRIE-CANDIDATES word="wnats" winner="whats" ranked=["whats"(cost=0.45 freq=43063 ctx=0), "wants"(cost=0.70 freq=47502 ctx=0), "what"(cost=1.45 freq=56337 ctx=0), "ways"(cost=1.40 freq=49094 ctx=0), "stats"(cost=1.41 freq=47548 ctx=0)]
TJ WHY #249 AUTOCORRECT branch=trie orig="wnats" corr="whats" prev="he"
TJ WHY #249 AUTOCORRECT-APPLY-BEFORE word="wnats" corr="whats" prev="he" ctx="Idl what he wnats"
TJ WHY #249 MIRROR-PROBE seq=75 ev=autocorrect-deleted off=? mir="Idl what he " mlen=12 pred="" plen=0
TJ WHY #249 MIRROR-ADOPT seq=75 ev=autocorrect-deleted reason=unaligned tail="Idl what he " len=12
TJ WHY #249 MIRROR-PROBE seq=76 ev=autocorrect-applied off=0 mir="Idl what he whats " mlen=18 pred="Idl what he whats " plen=18
TJ WHY #249 APPLIED orig="wnats" → "whats" prev="he"
TJ WORD #257 typed="were" prev="people" final="were" outcome=kept by=space previews=4
TJ WHY #257 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #276 typed="mon" prev="My" final="mon" outcome=kept by=space previews=3
TJ WHY #276 AUTOCORRECT-SKIP word="mon" reason=already-valid
TJ WORD #296 typed="Wher" prev=nil final="Wher" outcome=offered by=space previews=6
TJ WHY #296 TRIE-CANDIDATES word="Wher" kept ranked=["when"(cost=1.00 freq=55728 ctx=0), "her"(cost=1.00 freq=54336 ctx=0), "where"(cost=1.00 freq=54106 ctx=0), "what"(cost=1.21 freq=56337 ctx=0), "sher"(cost=0.41 freq=36093 ctx=0)]
TJ WHY #296 AUTOCORRECT-SKIP word="Wher" reason=ambiguous-candidates
TJ WORD #312 typed="its" prev="think" final="its" outcome=kept by=space previews=3
TJ WHY #312 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #327 typed="st" prev="you" final="st" outcome=kept by=space previews=2
TJ WHY #327 AUTOCORRECT-SKIP word="st" reason=already-valid
TJ WORD #339 typed="its" prev="believe" final="its" outcome=kept by=space previews=3
TJ WHY #339 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #346 typed="jn" prev="is" final="jn" outcome=kept by=space previews=2
TJ WHY #346 AUTOCORRECT-SKIP word="jn" reason=already-valid
TJ WORD #357 typed="hulu" prev="on" final="july" outcome=autocorrected by=space branch=trie previews=6
TJ WHY #357 TRIE-CANDIDATES word="hulu" winner="july" ranked=["july"(cost=0.80 freq=51818 ctx=0), "hulk"(cost=0.64 freq=39992 ctx=0), "bulk"(cost=1.09 freq=45880 ctx=0), "hull"(cost=0.98 freq=43180 ctx=0), "holy"(cost=1.20 freq=46630 ctx=0)]
TJ WHY #357 AUTOCORRECT branch=trie orig="hulu" corr="july" prev="on"
TJ WHY #357 AUTOCORRECT-APPLY-BEFORE word="hulu" corr="july" prev="on" ctx="ant to watch something on hulu"
TJ WHY #357 MIRROR-PROBE seq=103 ev=autocorrect-deleted off=? mir="t to watch something on " mlen=34 pred="you want to watch someth" plen=27
TJ WHY #357 MIRROR-ADOPT seq=103 ev=autocorrect-deleted reason=unaligned tail="t to watch something on " len=34
TJ WHY #357 MIRROR-PROBE seq=104 ev=autocorrect-applied off=0 mir="watch something on july " mlen=39 pred="watch something on july " plen=39
TJ WHY #357 APPLIED orig="hulu" → "july" prev="on"
TJ WORD #375 typed="were" prev="you" final="were" outcome=kept by=space previews=4
TJ WHY #375 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #385 typed="goood" prev="so" final="goood" outcome=offered by=space previews=7
TJ WHY #385 TRIE-CANDIDATES word="goood" kept ranked=["good"(cost=1.00 freq=54146 ctx=0), "blood"(cost=0.86 freq=49243 ctx=0), "flood"(cost=0.81 freq=45182 ctx=0), "tools"(cost=1.22 freq=52282 ctx=0), "books"(cost=1.35 freq=54007 ctx=0)]
TJ WHY #385 AUTOCORRECT-SKIP word="goood" reason=ambiguous-candidates
TJ WORD #389 typed="texted" prev="just" final="tested" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #389 TRIE-CANDIDATES word="texted" winner="tested" ranked=["tested"(cost=0.45 freq=46467 ctx=0), "tester"(cost=0.95 freq=41272 ctx=0), "rested"(cost=0.85 freq=38655 ctx=0), "tented"(cost=1.00 freq=37498 ctx=0), "texte"(cost=1.00 freq=36860 ctx=0)]
TJ WHY #389 AUTOCORRECT branch=trie orig="texted" corr="tested" prev="just"
TJ WHY #389 AUTOCORRECT-APPLY-BEFORE word="texted" corr="tested" prev="just" ctx="Ur sister just texted"
TJ WHY #389 MIRROR-PROBE seq=111 ev=autocorrect-deleted off=? mir="Ur sister just " mlen=15 pred="I didn't know you were c" plen=24
TJ WHY #389 MIRROR-ADOPT seq=111 ev=autocorrect-deleted reason=unaligned tail="Ur sister just " len=15
TJ WHY #389 MIRROR-PROBE seq=112 ev=autocorrect-applied off=0 mir="Ur sister just tested " mlen=22 pred="Ur sister just tested " plen=22
TJ WHY #389 APPLIED orig="texted" → "tested" prev="just"
TJ WORD #391 typed="Hwy" prev=nil final="Hwy" outcome=kept by=space previews=3
TJ WHY #391 AUTOCORRECT-SKIP word="Hwy" reason=already-valid
TJ WORD #397 typed="Were" prev=nil final="Were" outcome=kept by=space previews=4
TJ WHY #397 AUTOCORRECT-SKIP word="Were" reason=already-valid
TJ WORD #402 typed="priya" prev="with" final="prima" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #402 TRIE-CANDIDATES word="priya" winner="prima" ranked=["prius"(cost=0.80 freq=37122 ctx=0), "prima"(cost=1.00 freq=41073 ctx=0), "rita"(cost=1.40 freq=42336 ctx=0), "proud"(cost=1.60 freq=45746 ctx=0), "praha"(cost=1.41 freq=37678 ctx=0)]
TJ WHY #402 AUTOCORRECT branch=trie orig="priya" corr="prima" prev="with"
TJ WHY #402 AUTOCORRECT-APPLY-BEFORE word="priya" corr="prima" prev="with" ctx=" going to coachella with priya"
TJ WHY #402 MIRROR-PROBE seq=113 ev=autocorrect-deleted off=? mir="going to coachella with " mlen=29 pred="Ur sister just te" plen=17
TJ WHY #402 MIRROR-ADOPT seq=113 ev=autocorrect-deleted reason=unaligned tail="going to coachella with " len=29
TJ WHY #402 MIRROR-PROBE seq=114 ev=autocorrect-applied off=0 mir="to coachella with prima " mlen=35 pred="to coachella with prima " plen=35
TJ WHY #402 APPLIED orig="priya" → "prima" prev="with"
TJ WORD #414 typed="doidn" prev="you're" final="doidn" outcome=offered by=space previews=7
TJ WHY #414 TRIE-CANDIDATES word="doidn" kept ranked=["found"(cost=1.50 freq=52896 ctx=0), "sound"(cost=1.50 freq=50585 ctx=0), "doin"(cost=1.00 freq=38365 ctx=0), "down"(cost=1.64 freq=52811 ctx=0), "didn"(cost=1.00 freq=37495 ctx=0)]
TJ WHY #414 AUTOCORRECT-SKIP word="doidn" reason=ambiguous-candidates
TJ WORD #415 typed="well" prev="doidn" final="well" outcome=kept by=space previews=4
TJ WHY #415 AUTOCORRECT-SKIP word="well" reason=already-valid
```

## Spatial on

```
TJ WORD #25 typed="Ill" prev=nil final="I'll" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #25 AUTOCORRECT branch=contextual-contraction orig="Ill" corr="I'll" prev=nil
TJ WHY #25 AUTOCORRECT-APPLY-BEFORE word="Ill" corr="I'll" prev=nil ctx="Ill"
TJ WHY #25 MIRROR-PROBE seq=9 ev=autocorrect-deleted off=-5 mir="" mlen=0 pred="CYou'" plen=5
TJ WHY #25 MIRROR-PROBE seq=10 ev=autocorrect-applied off=0 mir="I'll " mlen=5 pred="CYou'I'll " plen=10
TJ WHY #25 MIRROR-RECONVERGE seq=10 was=-5 after=autocorrect-deleted ev=autocorrect-applied
TJ WHY #25 APPLIED orig="Ill" → "I'll" prev=nil
TJ WORD #35 typed="ill" prev="is" final="ill" outcome=kept by=space previews=3
TJ WHY #35 AUTOCORRECT-SKIP word="ill" reason=already-valid
TJ WORD #40 typed="Its" prev=nil final="It's" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #40 AUTOCORRECT branch=contextual-contraction orig="Its" corr="It's" prev=nil
TJ WHY #40 AUTOCORRECT-APPLY-BEFORE word="Its" corr="It's" prev=nil ctx="Its"
TJ WHY #40 MIRROR-PROBE seq=13 ev=autocorrect-deleted off=? mir="" mlen=0 pred="My grandma is ill so i" plen=22
TJ WHY #40 MIRROR-ADOPT seq=13 ev=autocorrect-deleted reason=unaligned tail="" len=0
TJ WHY #40 MIRROR-PROBE seq=14 ev=autocorrect-applied off=0 mir="It's " mlen=5 pred="It's " plen=5
TJ WHY #40 APPLIED orig="Its" → "It's" prev=nil
TJ WORD #43 typed="were" prev="so" final="were" outcome=kept by=space previews=4
TJ WHY #43 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #50 typed="its" prev="hurt" final="its" outcome=kept by=space previews=3
TJ WHY #50 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #56 typed="were" prev="We" final="were" outcome=kept by=space previews=4
TJ WHY #56 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #78 typed="venmo" prev="you" final="venom" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #78 TRIE-CANDIDATES word="venmo" winner="venom" ranked=["venom"(cost=0.70 freq=39677 ctx=0), "demo"(cost=1.72 freq=46344 ctx=0), "enom"(cost=1.70 freq=41905 ctx=0), "banjo"(cost=1.65 freq=39759 ctx=0), "nemo"(cost=1.70 freq=39464 ctx=0)]
TJ WHY #78 AUTOCORRECT branch=trie orig="venmo" corr="venom" prev="you"
TJ WHY #78 AUTOCORRECT-APPLY-BEFORE word="venmo" corr="venom" prev="you" ctx="Can you venmo"
TJ WHY #78 MIRROR-PROBE seq=25 ev=autocorrect-deleted off=? mir="Can you " mlen=8 pred="i didn't even like the m" plen=28
TJ WHY #78 MIRROR-ADOPT seq=25 ev=autocorrect-deleted reason=unaligned tail="Can you " len=8
TJ WHY #78 MIRROR-PROBE seq=26 ev=autocorrect-applied off=0 mir="Can you venom " mlen=14 pred="Can you venom " plen=14
TJ WHY #78 APPLIED orig="venmo" → "venom" prev="you"
TJ WORD #94 typed="ro" prev="go" final="to" outcome=autocorrected by=space branch=spatial previews=2
TJ WHY #94 AUTOCORRECT-SKIP word="ro" reason=already-valid
TJ WHY #94 AUTOCORRECT branch=spatial orig="ro" corr="to" prev="go"
TJ WHY #94 AUTOCORRECT-APPLY-BEFORE word="ro" corr="to" prev="go" ctx="I have to go ro"
TJ WHY #94 MIRROR-PROBE seq=31 ev=autocorrect-deleted off=? mir="I have to go " mlen=13 pred="I hav" plen=5
TJ WHY #94 MIRROR-ADOPT seq=31 ev=autocorrect-deleted reason=unaligned tail="I have to go " len=13
TJ WHY #94 MIRROR-PROBE seq=32 ev=autocorrect-applied off=0 mir="I have to go to " mlen=16 pred="I have to go to " plen=16
TJ WHY #94 APPLIED orig="ro" → "to" prev="go"
TJ WORD #103 typed="strat" prev="game" final="strat" outcome=kept by=space previews=6
TJ WHY #103 AUTOCORRECT-SKIP word="strat" reason=already-valid
TJ WORD #121 typed="coworker" prev="My" final="coworkers" outcome=autocorrected by=space branch=trie previews=13
TJ WHY #121 TRIE-CANDIDATES word="coworker" winner="coworkers" ranked=["coworkers"(cost=1.00 freq=36959 ctx=0), "worker"(cost=2.00 freq=45565 ctx=0), "cooker"(cost=2.00 freq=41844 ctx=0)]
TJ WHY #121 AUTOCORRECT branch=trie orig="coworker" corr="coworkers" prev="My"
TJ WHY #121 AUTOCORRECT-APPLY-BEFORE word="coworker" corr="coworkers" prev="My" ctx="My coworker"
TJ WHY #121 MIRROR-PROBE seq=41 ev=autocorrect-deleted off=? mir="My " mlen=3 pred="That's def" plen=10
TJ WHY #121 MIRROR-ADOPT seq=41 ev=autocorrect-deleted reason=unaligned tail="My " len=3
TJ WHY #121 MIRROR-PROBE seq=42 ev=autocorrect-applied off=0 mir="My coworkers " mlen=13 pred="My coworkers " plen=13
TJ WHY #121 APPLIED orig="coworker" → "coworkers" prev="My"
TJ WORD #122 typed="jaxon" prev="coworkers" final="jax on" outcome=autocorrected by=space branch=split-bigram previews=8
TJ WHY #122 SPLIT word="jaxon" boundary=nil bigram="jax on" → "jax on"
TJ WHY #122 AUTOCORRECT branch=split-bigram orig="jaxon" corr="jax on" prev="coworkers"
TJ WHY #122 NOTE bigram-rerank skipped (no evidence) for "jaxon" prev="coworkers", keeping "jax on"
TJ WHY #122 AUTOCORRECT-APPLY-BEFORE word="jaxon" corr="jax on" prev="coworkers" ctx="My coworkers jaxon"
TJ WHY #122 MIRROR-PROBE seq=43 ev=autocorrect-deleted off=+5 mir="My coworkers " mlen=13 pred="My cowor" plen=8
TJ WHY #122 MIRROR-PROBE seq=44 ev=autocorrect-applied off=? mir="My coworkers jax on " mlen=20 pred="My coworjax on " plen=15
TJ WHY #122 MIRROR-ADOPT seq=44 ev=autocorrect-applied reason=unaligned tail="My coworkers jax on " len=20
TJ WHY #122 APPLIED orig="jaxon" → "jax on" prev="coworkers"
TJ WORD #145 typed="ill" prev="Ok" final="I'll" outcome=autocorrected by=space branch=contextual-contraction previews=3
TJ WHY #145 AUTOCORRECT branch=contextual-contraction orig="ill" corr="I'll" prev="Ok"
TJ WHY #145 AUTOCORRECT-APPLY-BEFORE word="ill" corr="I'll" prev="Ok" ctx="Ok ill"
TJ WHY #145 MIRROR-PROBE seq=49 ev=autocorrect-deleted off=? mir="Ok " mlen=3 pred="Kayla is comi" plen=13
TJ WHY #145 MIRROR-ADOPT seq=49 ev=autocorrect-deleted reason=unaligned tail="Ok " len=3
TJ WHY #145 MIRROR-PROBE seq=50 ev=autocorrect-applied off=0 mir="Ok I'll " mlen=8 pred="Ok I'll " plen=8
TJ WHY #145 APPLIED orig="ill" → "I'll" prev="Ok"
TJ WORD #151 typed="hime" prev="get" final="home" outcome=autocorrected by=space branch=trie previews=5
TJ WHY #151 TRIE-CANDIDATES word="hime" winner="home" ranked=["home"(cost=0.40 freq=57579 ctx=0), "time"(cost=0.64 freq=56645 ctx=0), "hike"(cost=0.45 freq=41619 ctx=0), "hume"(cost=0.40 freq=39026 ctx=0), "him"(cost=1.00 freq=52744 ctx=33645)]
TJ WHY #151 AUTOCORRECT branch=trie orig="hime" corr="home" prev="get"
TJ WHY #151 AUTOCORRECT-APPLY-BEFORE word="hime" corr="home" prev="get" ctx=" I'll call you when i get hime"
TJ WHY #151 MIRROR-PROBE seq=51 ev=autocorrect-deleted off=? mir="'ll call you when i get " mlen=28 pred="Ok I" plen=4
TJ WHY #151 MIRROR-ADOPT seq=51 ev=autocorrect-deleted reason=unaligned tail="'ll call you when i get " len=28
TJ WHY #151 MIRROR-PROBE seq=52 ev=autocorrect-applied off=0 mir="all you when i get home " mlen=33 pred="all you when i get home " plen=33
TJ WHY #151 APPLIED orig="hime" → "home" prev="get"
TJ WORD #196 typed="Lets" prev=nil final="Lets" outcome=kept by=space previews=4
TJ WHY #196 AUTOCORRECT-SKIP word="Lets" reason=already-valid
TJ WORD #203 typed="lets" prev="He" final="lets" outcome=kept by=space previews=4
TJ WHY #203 AUTOCORRECT-SKIP word="lets" reason=already-valid
TJ WORD #210 typed="wont" prev="I" final="wont" outcome=kept by=space previews=4
TJ WHY #210 AUTOCORRECT-SKIP word="wont" reason=already-valid
TJ WORD #217 typed="Id" prev=nil final="Id" outcome=kept by=space previews=2
TJ WHY #217 AUTOCORRECT-SKIP word="Id" reason=already-valid
TJ WORD #225 typed="Well" prev=nil final="Well" outcome=kept by=space previews=4
TJ WHY #225 AUTOCORRECT-SKIP word="Well" reason=already-valid
TJ WORD #232 typed="Well" prev=nil final="Well" outcome=kept by=space previews=4
TJ WHY #232 AUTOCORRECT-SKIP word="Well" reason=already-valid
TJ WORD #237 typed="expectd" prev="than" final="expected" outcome=autocorrected by=space branch=trie,spatial previews=10
TJ WHY #237 TRIE-CANDIDATES word="expectd" winner="expects" ranked=["expects"(cost=0.40 freq=42442 ctx=0), "expected"(cost=1.00 freq=48910 ctx=0), "expect"(cost=1.00 freq=47676 ctx=0), "experts"(cost=1.21 freq=47449 ctx=0), "aspects"(cost=1.65 freq=47126 ctx=0)]
TJ WHY #237 AUTOCORRECT branch=trie orig="expectd" corr="expects" prev="than"
TJ WHY #237 AUTOCORRECT branch=spatial orig="expectd" corr="expected" prev="than"
TJ WHY #237 AUTOCORRECT-APPLY-BEFORE word="expectd" corr="expected" prev="than" ctx=" that went better than expectd"
TJ WHY #237 MIRROR-PROBE seq=71 ev=autocorrect-deleted off=? mir="l that went better than " mlen=27 pred="That's so" plen=9
TJ WHY #237 MIRROR-ADOPT seq=71 ev=autocorrect-deleted reason=unaligned tail="l that went better than " len=27
TJ WHY #237 MIRROR-PROBE seq=72 ev=autocorrect-applied off=0 mir="nt better than expected " mlen=36 pred="nt better than expected " plen=36
TJ WHY #237 APPLIED orig="expectd" → "expected" prev="than"
TJ WORD #246 typed="Idk" prev=nil final="Idl" outcome=autocorrected by=space branch=trie previews=4
TJ WHY #246 TRIE-CANDIDATES word="Idk" winner="idl" ranked=["idl"(cost=0.40 freq=38347 ctx=0), "id"(cost=1.00 freq=51085 ctx=0), "isk"(cost=0.40 freq=37199 ctx=0), "idm"(cost=0.45 freq=37440 ctx=0), "jdk"(cost=0.50 freq=38056 ctx=0)]
TJ WHY #246 AUTOCORRECT branch=trie orig="Idk" corr="Idl" prev=nil
TJ WHY #246 AUTOCORRECT-APPLY-BEFORE word="Idk" corr="Idl" prev=nil ctx="Idk"
TJ WHY #246 MIRROR-PROBE seq=75 ev=autocorrect-deleted off=? mir="" mlen=0 pred=" hear about the new iPho" plen=35
TJ WHY #246 MIRROR-ADOPT seq=75 ev=autocorrect-deleted reason=unaligned tail="" len=0
TJ WHY #246 MIRROR-PROBE seq=76 ev=autocorrect-applied off=0 mir="Idl " mlen=4 pred="Idl " plen=4
TJ WHY #246 APPLIED orig="Idk" → "Idl" prev=nil
TJ WORD #249 typed="wnats" prev="he" final="whats" outcome=autocorrected by=space branch=trie previews=8
TJ WHY #249 TRIE-CANDIDATES word="wnats" winner="whats" ranked=["whats"(cost=0.45 freq=43063 ctx=0), "wants"(cost=0.70 freq=47502 ctx=0), "what"(cost=1.45 freq=56337 ctx=0), "ways"(cost=1.40 freq=49094 ctx=0), "stats"(cost=1.41 freq=47548 ctx=0)]
TJ WHY #249 AUTOCORRECT branch=trie orig="wnats" corr="whats" prev="he"
TJ WHY #249 AUTOCORRECT-APPLY-BEFORE word="wnats" corr="whats" prev="he" ctx="Idl what he wnats"
TJ WHY #249 MIRROR-PROBE seq=77 ev=autocorrect-deleted off=? mir="Idl what he " mlen=12 pred="" plen=0
TJ WHY #249 MIRROR-ADOPT seq=77 ev=autocorrect-deleted reason=unaligned tail="Idl what he " len=12
TJ WHY #249 MIRROR-PROBE seq=78 ev=autocorrect-applied off=0 mir="Idl what he whats " mlen=18 pred="Idl what he whats " plen=18
TJ WHY #249 APPLIED orig="wnats" → "whats" prev="he"
TJ WORD #257 typed="were" prev="people" final="were" outcome=kept by=space previews=4
TJ WHY #257 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #276 typed="mon" prev="My" final="mom" outcome=autocorrected by=space branch=spatial previews=3
TJ WHY #276 AUTOCORRECT-SKIP word="mon" reason=already-valid
TJ WHY #276 AUTOCORRECT branch=spatial orig="mon" corr="mom" prev="My"
TJ WHY #276 AUTOCORRECT-APPLY-BEFORE word="mon" corr="mom" prev="My" ctx="My mon"
TJ WHY #276 MIRROR-PROBE seq=87 ev=autocorrect-deleted off=? mir="My " mlen=3 pred="Can y" plen=5
TJ WHY #276 MIRROR-ADOPT seq=87 ev=autocorrect-deleted reason=unaligned tail="My " len=3
TJ WHY #276 MIRROR-PROBE seq=88 ev=autocorrect-applied off=0 mir="My mom " mlen=7 pred="My mom " plen=7
TJ WHY #276 APPLIED orig="mon" → "mom" prev="My"
TJ WORD #296 typed="Wher" prev=nil final="Where" outcome=autocorrected by=space branch=spatial previews=6
TJ WHY #296 TRIE-CANDIDATES word="Wher" kept ranked=["when"(cost=1.00 freq=55728 ctx=0), "her"(cost=1.00 freq=54336 ctx=0), "where"(cost=1.00 freq=54106 ctx=0), "what"(cost=1.21 freq=56337 ctx=0), "sher"(cost=0.41 freq=36093 ctx=0)]
TJ WHY #296 AUTOCORRECT-SKIP word="Wher" reason=ambiguous-candidates
TJ WHY #296 AUTOCORRECT branch=spatial orig="Wher" corr="Where" prev=nil
TJ WHY #296 AUTOCORRECT-APPLY-BEFORE word="Wher" corr="Where" prev=nil ctx="Wher"
TJ WHY #296 MIRROR-PROBE seq=93 ev=autocorrect-deleted off=? mir="" mlen=0 pred="Ngl that test was rea" plen=21
TJ WHY #296 MIRROR-ADOPT seq=93 ev=autocorrect-deleted reason=unaligned tail="" len=0
TJ WHY #296 MIRROR-PROBE seq=94 ev=autocorrect-applied off=0 mir="Where " mlen=6 pred="Where " plen=6
TJ WHY #296 APPLIED orig="Wher" → "Where" prev=nil
TJ WORD #312 typed="its" prev="think" final="its" outcome=kept by=space previews=3
TJ WHY #312 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #327 typed="st" prev="you" final="at" outcome=autocorrected by=space branch=spatial previews=2
TJ WHY #327 AUTOCORRECT-SKIP word="st" reason=already-valid
TJ WHY #327 AUTOCORRECT branch=spatial orig="st" corr="at" prev="you"
TJ WHY #327 AUTOCORRECT-APPLY-BEFORE word="st" corr="at" prev="you" ctx="Sounds good see you st"
TJ WHY #327 MIRROR-PROBE seq=99 ev=autocorrect-deleted off=? mir="Sounds good see you " mlen=20 pred="Is netflix down for yo" plen=22
TJ WHY #327 MIRROR-ADOPT seq=99 ev=autocorrect-deleted reason=unaligned tail="Sounds good see you " len=20
TJ WHY #327 MIRROR-PROBE seq=100 ev=autocorrect-applied off=0 mir="Sounds good see you at " mlen=23 pred="Sounds good see you at " plen=23
TJ WHY #327 APPLIED orig="st" → "at" prev="you"
TJ WORD #339 typed="its" prev="believe" final="its" outcome=kept by=space previews=3
TJ WHY #339 AUTOCORRECT-SKIP word="its" reason=already-valid
TJ WORD #346 typed="jn" prev="is" final="in" outcome=autocorrected by=space branch=spatial previews=2
TJ WHY #346 AUTOCORRECT-SKIP word="jn" reason=already-valid
TJ WHY #346 AUTOCORRECT branch=spatial orig="jn" corr="in" prev="is"
TJ WHY #346 AUTOCORRECT-APPLY-BEFORE word="jn" corr="in" prev="is" ctx="My brother mike is jn"
TJ WHY #346 MIRROR-PROBE seq=107 ev=autocorrect-deleted off=? mir="My brother mike is " mlen=19 pred="I just can't believ" plen=19
TJ WHY #346 MIRROR-ADOPT seq=107 ev=autocorrect-deleted reason=unaligned tail="My brother mike is " len=19
TJ WHY #346 MIRROR-PROBE seq=108 ev=autocorrect-applied off=0 mir="My brother mike is in " mlen=22 pred="My brother mike is in " plen=22
TJ WHY #346 APPLIED orig="jn" → "in" prev="is"
TJ WORD #357 typed="hulu" prev="on" final="july" outcome=autocorrected by=space branch=trie previews=6
TJ WHY #357 TRIE-CANDIDATES word="hulu" winner="july" ranked=["july"(cost=0.80 freq=51818 ctx=0), "hulk"(cost=0.64 freq=39992 ctx=0), "bulk"(cost=1.09 freq=45880 ctx=0), "hull"(cost=0.98 freq=43180 ctx=0), "holy"(cost=1.20 freq=46630 ctx=0)]
TJ WHY #357 AUTOCORRECT branch=trie orig="hulu" corr="july" prev="on"
TJ WHY #357 AUTOCORRECT-APPLY-BEFORE word="hulu" corr="july" prev="on" ctx="ant to watch something on hulu"
TJ WHY #357 MIRROR-PROBE seq=113 ev=autocorrect-deleted off=? mir="t to watch something on " mlen=34 pred="you want to watch someth" plen=27
TJ WHY #357 MIRROR-ADOPT seq=113 ev=autocorrect-deleted reason=unaligned tail="t to watch something on " len=34
TJ WHY #357 MIRROR-PROBE seq=114 ev=autocorrect-applied off=0 mir="watch something on july " mlen=39 pred="watch something on july " plen=39
TJ WHY #357 APPLIED orig="hulu" → "july" prev="on"
TJ WORD #375 typed="were" prev="you" final="were" outcome=kept by=space previews=4
TJ WHY #375 AUTOCORRECT-SKIP word="were" reason=already-valid
TJ WORD #385 typed="goood" prev="so" final="good" outcome=autocorrected by=space branch=spatial previews=7
TJ WHY #385 TRIE-CANDIDATES word="goood" kept ranked=["good"(cost=1.00 freq=54146 ctx=0), "blood"(cost=0.86 freq=49243 ctx=0), "flood"(cost=0.81 freq=45182 ctx=0), "tools"(cost=1.22 freq=52282 ctx=0), "books"(cost=1.35 freq=54007 ctx=0)]
TJ WHY #385 AUTOCORRECT-SKIP word="goood" reason=ambiguous-candidates
TJ WHY #385 AUTOCORRECT branch=spatial orig="goood" corr="good" prev="so"
TJ WHY #385 AUTOCORRECT-APPLY-BEFORE word="goood" corr="good" prev="so" ctx="ood at that place was so goood"
TJ WHY #385 MIRROR-PROBE seq=121 ev=autocorrect-deleted off=? mir="od at that place was so " mlen=30 pred=" didn't know you were co" plen=25
TJ WHY #385 MIRROR-ADOPT seq=121 ev=autocorrect-deleted reason=unaligned tail="od at that place was so " len=30
TJ WHY #385 MIRROR-PROBE seq=122 ev=autocorrect-applied off=0 mir=" that place was so good " mlen=35 pred=" that place was so good " plen=35
TJ WHY #385 APPLIED orig="goood" → "good" prev="so"
TJ WORD #389 typed="texted" prev="just" final="tested" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #389 TRIE-CANDIDATES word="texted" winner="tested" ranked=["tested"(cost=0.45 freq=46467 ctx=0), "tester"(cost=0.95 freq=41272 ctx=0), "rested"(cost=0.85 freq=38655 ctx=0), "tented"(cost=1.00 freq=37498 ctx=0), "texte"(cost=1.00 freq=36860 ctx=0)]
TJ WHY #389 AUTOCORRECT branch=trie orig="texted" corr="tested" prev="just"
TJ WHY #389 AUTOCORRECT-APPLY-BEFORE word="texted" corr="tested" prev="just" ctx="Ur sister just texted"
TJ WHY #389 MIRROR-PROBE seq=123 ev=autocorrect-deleted off=? mir="Ur sister just " mlen=15 pred="ood at that place was so" plen=29
TJ WHY #389 MIRROR-ADOPT seq=123 ev=autocorrect-deleted reason=unaligned tail="Ur sister just " len=15
TJ WHY #389 MIRROR-PROBE seq=124 ev=autocorrect-applied off=0 mir="Ur sister just tested " mlen=22 pred="Ur sister just tested " plen=22
TJ WHY #389 APPLIED orig="texted" → "tested" prev="just"
TJ WORD #391 typed="Hwy" prev=nil final="Hwy" outcome=kept by=space previews=3
TJ WHY #391 AUTOCORRECT-SKIP word="Hwy" reason=already-valid
TJ WORD #397 typed="Were" prev=nil final="Were" outcome=kept by=space previews=4
TJ WHY #397 AUTOCORRECT-SKIP word="Were" reason=already-valid
TJ WORD #402 typed="priya" prev="with" final="prima" outcome=autocorrected by=space branch=trie previews=7
TJ WHY #402 TRIE-CANDIDATES word="priya" winner="prima" ranked=["prius"(cost=0.80 freq=37122 ctx=0), "prima"(cost=1.00 freq=41073 ctx=0), "rita"(cost=1.40 freq=42336 ctx=0), "proud"(cost=1.60 freq=45746 ctx=0), "praha"(cost=1.41 freq=37678 ctx=0)]
TJ WHY #402 AUTOCORRECT branch=trie orig="priya" corr="prima" prev="with"
TJ WHY #402 AUTOCORRECT-APPLY-BEFORE word="priya" corr="prima" prev="with" ctx=" going to coachella with priya"
TJ WHY #402 MIRROR-PROBE seq=125 ev=autocorrect-deleted off=? mir="going to coachella with " mlen=29 pred="Ur sister just te" plen=17
TJ WHY #402 MIRROR-ADOPT seq=125 ev=autocorrect-deleted reason=unaligned tail="going to coachella with " len=29
TJ WHY #402 MIRROR-PROBE seq=126 ev=autocorrect-applied off=0 mir="to coachella with prima " mlen=35 pred="to coachella with prima " plen=35
TJ WHY #402 APPLIED orig="priya" → "prima" prev="with"
TJ WORD #414 typed="doidn" prev="you're" final="doidn" outcome=offered by=space previews=7
TJ WHY #414 TRIE-CANDIDATES word="doidn" kept ranked=["found"(cost=1.50 freq=52896 ctx=0), "sound"(cost=1.50 freq=50585 ctx=0), "doin"(cost=1.00 freq=38365 ctx=0), "down"(cost=1.64 freq=52811 ctx=0), "didn"(cost=1.00 freq=37495 ctx=0)]
TJ WHY #414 AUTOCORRECT-SKIP word="doidn" reason=ambiguous-candidates
TJ WORD #415 typed="well" prev="doidn" final="well" outcome=kept by=space previews=4
TJ WHY #415 AUTOCORRECT-SKIP word="well" reason=already-valid
```
