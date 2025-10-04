# 📐 Templates pour Nouvelles Stacks

Ce dossier contient les templates standardisés pour créer de nouvelles stacks de manière cohérente.

## 📋 Templates Disponibles

### 1. **GUIDE-DEBUTANT-TEMPLATE.md**
Guide pédagogique pour expliquer une stack aux débutants.

**À remplir** :
- Description simple (analogies du monde réel)
- Use cases concrets
- Exemples pas-à-pas
- Commandes utiles
- Troubleshooting courant
- Ressources d'apprentissage

**Où le mettre** : `pi5-[stack-name]-stack/GUIDE-DEBUTANT.md`

---

## 🏗️ Structure Standard d'une Stack

Chaque nouvelle stack doit suivre cette structure :

```
pi5-[nom]-stack/
├── README.md                      # Vue d'ensemble technique
├── GUIDE-DEBUTANT.md             # Guide pédagogique (utiliser template)
├── INSTALL.md                     # Instructions installation SSH
├── CHANGELOG.md                   # Historique versions
├── scripts/
│   ├── 01-[nom]-deploy.sh        # Script installation principal
│   ├── 02-[optional]-setup.sh    # Scripts additionnels
│   ├── maintenance/
│   │   ├── README.md             # Guide maintenance
│   │   ├── _[stack]-common.sh    # Config wrapper
│   │   ├── [stack]-backup.sh
│   │   ├── [stack]-healthcheck.sh
│   │   ├── [stack]-logs.sh
│   │   ├── [stack]-restore.sh
│   │   ├── [stack]-scheduler.sh
│   │   └── [stack]-update.sh
│   └── utils/
│       ├── diagnostic-[stack].sh
│       ├── get-[stack]-info.sh
│       └── clean-[stack].sh
├── compose/
│   └── docker-compose.yml        # Configuration Docker
├── config/
│   └── [fichiers config]
├── commands/
│   ├── README.md
│   ├── 00-Initial-Setup.md
│   └── 01-Quick-Start.md
└── docs/
    ├── README.md
    ├── 01-GETTING-STARTED/
    ├── 02-CONFIGURATION/
    ├── 03-TROUBLESHOOTING/
    └── 04-ADVANCED/
```

---

## 📝 Checklist Création Nouvelle Stack

### Phase 1 : Planification
- [ ] Stack documentée dans [ROADMAP.md](../ROADMAP.md)
- [ ] Use cases identifiés
- [ ] Choix technologies (100% open source & gratuit)
- [ ] Estimation RAM/CPU
- [ ] Dépendances identifiées (autres stacks requises)

### Phase 2 : Création Structure
- [ ] Créer dossier `pi5-[nom]-stack/`
- [ ] Copier template GUIDE-DEBUTANT.md et remplir
- [ ] Créer README.md technique
- [ ] Créer INSTALL.md avec curl/wget one-liners

### Phase 3 : Scripts
- [ ] Script `01-[nom]-deploy.sh` (wrapper vers common-scripts si possible)
- [ ] Scripts maintenance (backup, healthcheck, etc.)
- [ ] Config `_[stack]-common.sh` pour variables
- [ ] Scripts utils (diagnostic, info, clean)

### Phase 4 : Configuration
- [ ] docker-compose.yml testé sur Pi 5 ARM64
- [ ] Fichiers config avec valeurs par défaut sécurisées
- [ ] Intégration Traefik (labels Docker) si Phase 2+ terminée

### Phase 5 : Documentation
- [ ] GUIDE-DEBUTANT.md complet
- [ ] README.md avec guide technique
- [ ] INSTALL.md avec instructions SSH
- [ ] commands/ avec toutes les commandes utiles
- [ ] docs/ avec troubleshooting

### Phase 6 : Tests
- [ ] Installation propre sur Pi 5 neuf
- [ ] Tous les services healthy
- [ ] Backup/restore testé
- [ ] Healthcheck fonctionnel
- [ ] Documentation validée (quelqu'un d'autre peut installer)

### Phase 7 : Publication
- [ ] Commit avec message détaillé
- [ ] Push vers GitHub
- [ ] Mise à jour [README.md principal](../README.md)
- [ ] Mise à jour [ROADMAP.md](../ROADMAP.md) (phase marquée ✅)

---

## 🎨 Standards de Nommage

### Dossiers
- `pi5-[nom]-stack/` (ex: `pi5-traefik-stack/`, `pi5-gitea-stack/`)
- Nom en minuscules, tirets, pas d'underscores

### Scripts
- `01-[nom]-deploy.sh` - Script principal installation
- `[stack]-[action].sh` - Scripts maintenance (ex: `traefik-healthcheck.sh`)
- `_[stack]-common.sh` - Config wrapper (ex: `_traefik-common.sh`)

### Fichiers
- `GUIDE-DEBUTANT.md` - Toujours en majuscules
- `README.md`, `INSTALL.md`, `CHANGELOG.md` - Majuscules
- Config/compose : minuscules

---

## 💡 Exemples de Référence

### Stack Complète (Référence)
Voir [pi5-supabase-stack/](../pi5-supabase-stack/) pour structure complète exemplaire.

### GUIDE-DEBUTANT Exemplaire
Voir [pi5-supabase-stack/GUIDE-DEBUTANT.md](../pi5-supabase-stack/GUIDE-DEBUTANT.md)

---

## 🤝 Contribution

Pour contribuer une nouvelle stack :

1. **Fork** le repo
2. **Créer branche** : `git checkout -b feature/stack-[nom]`
3. **Utiliser templates** de ce dossier
4. **Tester** sur Pi 5 ARM64 réel
5. **Documenter** (GUIDE-DEBUTANT obligatoire)
6. **Pull Request** avec description détaillée

### Critères d'Acceptation
- ✅ 100% Open Source & Gratuit
- ✅ Testé sur Raspberry Pi 5 ARM64
- ✅ Structure conforme aux templates
- ✅ GUIDE-DEBUTANT.md complet
- ✅ Scripts de maintenance (backup, healthcheck minimum)
- ✅ Documentation complète

---

**Questions ?** Ouvre une [issue GitHub](https://github.com/iamaketechnology/pi5-setup/issues) ou contacte [@iamaketechnology](https://github.com/iamaketechnology).
