# 🧠 Architecture du Cerveau de l'Assistant Intelligent

## Vision

Créer un système modulaire d'intelligence où chaque "neurone" (module JS) a une responsabilité spécifique.

## Architecture Neuronale

```
🧠 AI BRAIN
├── 🔍 system-diagnostics.js (Neurone de Diagnostic)
│   └── Analyse l'état du système (santé, mises à jour, espace disque)
│
├── 💡 recommendation-engine.js (Neurone de Recommandation)
│   └── Suggère des actions basées sur le contexte
│
├── 📊 predictive-analytics.js (Neurone Prédictif)
│   └── Prévoit les problèmes avant qu'ils n'arrivent
│
├── 🔧 automation-planner.js (Neurone d'Automatisation)
│   └── Planifie des tâches automatiques
│
├── 🎓 learning-module.js (Neurone d'Apprentissage)
│   └── Apprend des comportements de l'utilisateur
│
└── 🧩 decision-maker.js (Neurone de Décision)
    └── Coordonne tous les neurones et prend des décisions
```

## Modules Actuels

### ✅ system-diagnostics.js
**Statut** : Implémenté
**Responsabilité** : Analyse de l'état du système
**Fonctions** :
- `analyze(updates, services, disk)` - Analyse complète
- `generateHealthDiagnostic()` - Score de santé 0-100
- `analyzeServices()` - Analyse des services Docker
- `analyzeUpdates()` - Analyse des mises à jour
- `analyzeDisk()` - Analyse de l'espace disque

**Seuils configurables** :
```javascript
thresholds = {
    disk: { critical: 5, warning: 10, low: 20 },
    updates: { critical: 5, warning: 3 },
    services: { good: 5 }
}
```

## Modules Futurs

### 📋 recommendation-engine.js
```javascript
class RecommendationEngine {
    recommend(diagnosticData) {
        // Suggère des actions contextuelles
        // Ex: "Installez Traefik pour sécuriser vos services"
    }
}
```

### 📈 predictive-analytics.js
```javascript
class PredictiveAnalytics {
    predict(historicalData) {
        // Prévoit les problèmes
        // Ex: "Espace disque plein dans 7 jours"
    }
}
```

### ⚙️ automation-planner.js
```javascript
class AutomationPlanner {
    plan(context) {
        // Planifie des tâches automatiques
        // Ex: "Nettoyer Docker tous les lundis à 2h"
    }
}
```

### 🧠 decision-maker.js (Coordinateur)
```javascript
class DecisionMaker {
    constructor() {
        this.diagnostics = new SystemDiagnostics();
        this.recommender = new RecommendationEngine();
        this.predictor = new PredictiveAnalytics();
        this.planner = new AutomationPlanner();
    }

    analyze() {
        const diagnostic = this.diagnostics.analyze();
        const recommendations = this.recommender.recommend(diagnostic);
        const predictions = this.predictor.predict();
        const plan = this.planner.plan({ diagnostic, recommendations });

        return { diagnostic, recommendations, predictions, plan };
    }
}
```

## Principes de Design

1. **Modularité** : Chaque neurone = 1 fichier JS indépendant
2. **Responsabilité unique** : Un neurone fait une seule chose bien
3. **Composabilité** : Les neurones peuvent se combiner
4. **Testabilité** : Chaque neurone peut être testé isolément
5. **Extensibilité** : Facile d'ajouter de nouveaux neurones

## Communication entre Neurones

```javascript
// Neurone A produit des données
const diagnosticData = diagnostics.analyze();

// Neurone B consomme les données de A
const recommendations = recommender.recommend(diagnosticData);

// Neurone C combine A + B
const actions = planner.plan({ diagnosticData, recommendations });
```

## Intégration dans installation-assistant.js

```javascript
class InstallationAssistant {
    constructor() {
        // Initialiser les neurones
        this.brain = {
            diagnostics: new SystemDiagnostics(),
            recommender: new RecommendationEngine(),
            predictor: new PredictiveAnalytics(),
            planner: new AutomationPlanner(),
            decisionMaker: new DecisionMaker()
        };
    }

    async think() {
        // L'assistant "pense" en consultant son cerveau
        const analysis = this.brain.decisionMaker.analyze();
        this.displayAssistantMessages(analysis.messages);
    }
}
```

## Roadmap

- [x] ✅ Neurone de Diagnostic (system-diagnostics.js)
- [ ] 💡 Neurone de Recommandation
- [ ] 📊 Neurone Prédictif
- [ ] 🔧 Neurone d'Automatisation
- [ ] 🎓 Neurone d'Apprentissage
- [ ] 🧩 Coordinateur de Décision

## Avantages

✅ **Maintenabilité** : Code facile à maintenir
✅ **Testabilité** : Tests unitaires par neurone
✅ **Extensibilité** : Ajout de neurones sans refactoring
✅ **Performance** : Neurones peuvent s'exécuter en parallèle
✅ **Réutilisabilité** : Neurones utilisables ailleurs
