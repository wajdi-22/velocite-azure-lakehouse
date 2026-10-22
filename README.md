# VéloCité — pipelines Azure Data Factory

Export des objets VCT du projet EFREI Architecture Review sur Azure, le 22 octobre 2026. Les ressources Azure sont partagées avec Retail360 ; seuls les objets VéloCité sont versionnés ici.

## Contenu

- `pipeline/` : neuf pipelines ADF exportés depuis l'interface.
- `dataset/` : onze datasets paramétrés.
- `dataflow/` : deux Mapping Data Flows Delta.
- `sql/` : scripts extraits du pipeline d'initialisation.
- `docs/` : catalogue, décisions et exploitation.

## Connexions à recréer dans ADF

Les secrets et identifiants chiffrés ne sont pas exportés. Configurer `VCT_LS_SQL` (Azure SQL Database), `VCT_LS_LAKE` (ADLS Gen2, identité managée) et `VCT_LS_STATIONS_API` (REST public, jeu Paris Data Vélib disponibilité en temps réel). Renseigner les accès dans Azure, jamais dans Git. Recréer les cinq conteneurs `vct-raw`, `vct-curated`, `vct-consumption`, `vct-inbox`, `vct-quarantine`.

## Exécution et état réel

Importer les objets et leurs références, lancer `VCT_PIPE_00_INITIALISATION`, puis `VCT_PIPE_01_PILOTE_QUOTIDIEN`. Le déclencheur quotidien reste arrêté pendant la recette. Les scripts de création de tables de staging et les TRUNCATE portent exclusivement sur `vct_stage`.

Le premier essai complet a validé extraction, sources externes, staging, qualité et publication curated Delta. Les quatre dimensions qualité ont contrôlé 200000 locations avec zéro rejet sur le jeu nominal. Le calcul consommation a échoué sur un mapping de sortie absent, corrigé et publié ensuite. Le second lot a échoué sur la lecture JSON API (`UserErrorFileNotFound` : le chemin lu ne correspond pas aux sous-dossiers de pagination). L'export conserve ce dernier état publié, sans prétendre que la recette complète est terminée.

À terminer : corriger et retester le parcours des fichiers API, vérifier le mapping consommation de bout en bout, la reprise incrémentale, une correction à J-7, une anomalie en quarantaine, l'effacement RGPD et le déclenchement effectif de l'alerte. Aucun test négatif validé ne doit être déduit du seul résultat nominal sans rejet.

## Coûts

Budget commun `BUDGET_LAB_COMMUN` : 20 EUR/mois, notification à 80 %, groupe `Enterprise_Data_Lakes_Lakehouse_Foundations`. Inclut Retail360 et VéloCité ; il ne bloque pas les dépenses.
