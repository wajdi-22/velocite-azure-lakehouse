# Cinq décisions d'architecture

## ADR 1 — Batch incrémental
Contexte : tableau de bord quotidien et budget limité. Décision : ADF en batch incrémental. Alternative : Event Hubs et streaming. Conséquence : orchestration plus simple ; pas de garantie temps réel.

## ADR 2 — Fusion transactionnelle
Contexte : corrections et doublons lors des relances. Décision : clé métier, modifie_le, MERGE et upsert Delta. Alternative : append seul ou DELETE/INSERT. Conséquence : reprise déterministe à tester et checkpoint après publication complète.

## ADR 3 — Organisation des fichiers
Contexte : Parquet de 400 Ko et filtre abonné lent. Décision : compaction, partition temporelle seulement si justifiée et clustering à étudier sur token abonné. Alternative : partitionnement par abonné. Conséquence : moins de fragmentation ; mesurer avant optimisation supplémentaire.

## ADR 4 — Pseudonymisation
Contexte : identités en clair et déplacements personnels. Décision : token aléatoire et correspondance privée. Alternative : exposer les identités ou considérer un hash simple comme anonyme. Conséquence : données toujours personnelles et effacement à propager aux copies et versions.

## ADR 5 — Services partagés
Contexte : laboratoire Retail360 disponible. Décision : réutiliser ADF, SQL et ADLS avec noms VCT séparés, SQL et Mapping Data Flows, budget commun. Alternative : Databricks ou services dédiés. Conséquence : moins de ressources à gérer, coûts non isolés entre exercices.
