from align import analyse
U="/Users/pierreviviere/.claude/uploads/aebf03b8-609b-47c6-a197-db3eebdef4b1/"

A_pause = "Ce matin, j'ai commencé ma journée assez tranquillement. J'ai pris un café, puis j'ai regardé rapidement mes messages. Ensuite, je me suis mis au travail. Rien de vraiment particulier aujourd'hui, mais finalement la matinée est passée assez vite."
A_sans  = "Ce matin, j'ai commencé ma journée assez tranquillement. J'ai pris un café, puis j'ai regardé rapidement mes messages. Ensuite, je me suis mise au travail. Rien de vraiment particulier aujourd'hui, mais finalement la matinée est passée assez vite."
B_pause = "Sauf qu'on passe beaucoup de temps à vouloir aller vite, faire les choses rapidement, répondre immédiatement, passer à la suivante. Alors que parfois, prendre quelques minutes pour réfléchir permet simplement de mieux faire les choses. Ce n'est pas forcément plus long, c'est juste une autre manière de travailler."
B_sans  = "Qu'est-ce qu'on passe comme temps à vouloir aller vite, faire les choses rapidement, répondre immédiatement et passer à la suivante... Alors que parfois, prendre quelques minutes pour réfléchir permet simplement de mieux faire les choses. Ce n'est pas forcément plus long, c'est juste une autre manière de travailler."

for noise in (-25, -30):
    print("=" * 78)
    analyse("A — WITH pauses",    U+"70b36fc0-Texte_A__Pause.m4a",      A_pause, {2}, noise)
    analyse("A — WITHOUT pauses", U+"3fe63859-Texte_A__Sans_Pause.m4a", A_sans,  {1}, noise)
    analyse("B — WITH pauses",    U+"ff55064d-Texte_B__Pause.m4a",      B_pause, {1}, noise)
    analyse("B — WITHOUT pauses", U+"55675343-Texte_B__Sans_pause.m4a", B_sans,  {1}, noise)
