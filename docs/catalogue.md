# Catalogue et lineage VéloCité

Catalogue documenté, sans déploiement Purview. Propriétaires proposés : équipe exploitation pour les sources et le brut ; équipe data pour curated et qualité ; métier pour les agrégats ; DPO pour les règles de conservation et d'effacement. Ces responsabilités sont proposées dans le cadre de l'exercice.

| Actif | Grain et clé | Classification | Origine et traitement |
|---|---|---|---|
| vct_source.abonnes | un abonné, abonne_id | personnel | SQL fictif, modifie_le |
| vct_source.stations | une station, station_id | interne | SQL fictif |
| vct_source.locations | une location, location_id | déplacement personnel | SQL fictif, modifie_le |
| vct-inbox/meteo/meteo_demo.csv | date et ville | interne fictif | huit observations de démonstration |
| API Vélib | stationcode et observe_le | public | deux pages de 25 stations ; référentiel distinct des stations fictives SQL |
| vct-raw | fichier et lot_id | restreint si personnel | archives des trois sources |
| vct_curated puis vct-curated | clés métier | pseudonymisé pour abonnés et locations | typage, règles qualité, MERGE SQL puis upsert Delta |
| vct_ops.Quarantine | lot, entité et clé | restreint | données rejetées et motif ; conteneur de quarantaine réservé |
| vct_private.SubscriberMap | abonne_id et token | très restreint | table de correspondance privée |
| vct-consumption/activite_quotidienne | jour | agrégé | nombre de locations, recettes, abonnés actifs, durée moyenne |

Lineage : SQL -> PIPE_10 -> raw/Parquet -> PIPE_20 -> stage ; CSV et API -> PIPE_15 -> raw puis stage ; stage -> PIPE_30 -> SQL curated et métriques/rejets ; SQL curated -> PIPE_40/FLOW_40 -> Delta curated ; Delta locations -> PIPE_50/FLOW_50 -> Delta consommation.

Glossaire : jour métier = date de début en Europe/Paris ; watermark = dernière borne haute publiée avec succès ; complétude = champs requis présents ; validité = types et valeurs admissibles ; unicité = clé location non dupliquée ; cohérence = dates et références compatibles.
