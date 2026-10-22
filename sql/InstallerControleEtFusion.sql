CREATE OR ALTER PROCEDURE vct_ops.usp_ControlerEtFusionner @BatchId VARCHAR(64) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
 DELETE FROM vct_ops.QualityMetric WHERE run_id=@BatchId;
 DELETE FROM vct_ops.Quarantine WHERE run_id=@BatchId;
 INSERT vct_private.SubscriberMap(abonne_id)
 SELECT DISTINCT TRY_CONVERT(INT,a.abonne_id) FROM vct_stage.abonnes a
 WHERE TRY_CONVERT(INT,a.abonne_id) IS NOT NULL AND NOT EXISTS(SELECT 1 FROM vct_private.SubscriberMap m WHERE m.abonne_id=TRY_CONVERT(INT,a.abonne_id)) AND NOT EXISTS(SELECT 1 FROM vct_private.ErasureLedger e WHERE e.abonne_id=TRY_CONVERT(INT,a.abonne_id));
 ;WITH a AS(SELECT CONVERT(VARCHAR(36),m.abonne_token) abonne_token,LEFT(s.ville,40) ville,TRY_CONVERT(DATETIME2,s.modifie_le) modifie_le,ROW_NUMBER() OVER(PARTITION BY s.abonne_id ORDER BY TRY_CONVERT(DATETIME2,s.modifie_le) DESC) rn FROM vct_stage.abonnes s JOIN vct_private.SubscriberMap m ON m.abonne_id=TRY_CONVERT(INT,s.abonne_id) WHERE TRY_CONVERT(DATETIME2,s.modifie_le) IS NOT NULL AND NOT EXISTS(SELECT 1 FROM vct_private.ErasureLedger e WHERE e.abonne_id=m.abonne_id))
 MERGE vct_curated.abonnes WITH(HOLDLOCK) t USING(SELECT * FROM a WHERE rn=1)s ON t.abonne_token=s.abonne_token
 WHEN MATCHED AND s.modifie_le>=t.modifie_le THEN UPDATE SET ville=s.ville,modifie_le=s.modifie_le,latest_run=@BatchId
 WHEN NOT MATCHED THEN INSERT(abonne_token,ville,modifie_le,latest_run)VALUES(s.abonne_token,s.ville,s.modifie_le,@BatchId);
 ;WITH s AS(SELECT TRY_CONVERT(INT,station_id) station_id,LEFT(nom,80)nom,TRY_CONVERT(INT,capacite)capacite,ROW_NUMBER() OVER(PARTITION BY station_id ORDER BY nom)rn FROM vct_stage.stations)
 MERGE vct_curated.stations WITH(HOLDLOCK)t USING(SELECT * FROM s WHERE rn=1 AND station_id IS NOT NULL AND capacite>0)s ON t.station_id=s.station_id
 WHEN MATCHED THEN UPDATE SET nom=s.nom,capacite=s.capacite,latest_run=@BatchId
 WHEN NOT MATCHED THEN INSERT(station_id,nom,capacite,latest_run)VALUES(s.station_id,s.nom,s.capacite,@BatchId);
 SELECT s.*,TRY_CONVERT(INT,s.location_id)id,TRY_CONVERT(INT,s.abonne_id)aid,TRY_CONVERT(INT,s.station_depart)sd,TRY_CONVERT(INT,s.station_arrivee)sa,TRY_CONVERT(DATETIME2,s.debut)dt_debut,TRY_CONVERT(DATETIME2,s.fin)dt_fin,TRY_CONVERT(DECIMAL(6,2),s.montant)mt,TRY_CONVERT(DATETIME2,s.modifie_le)dt_modif,ROW_NUMBER() OVER(PARTITION BY s.location_id ORDER BY TRY_CONVERT(DATETIME2,s.modifie_le) DESC)rn INTO #Parsed FROM vct_stage.locations s;
 SELECT p.*,CASE
 WHEN NULLIF(LTRIM(RTRIM(location_id)),'') IS NULL OR NULLIF(LTRIM(RTRIM(abonne_id)),'') IS NULL OR NULLIF(LTRIM(RTRIM(debut)),'') IS NULL THEN 'completude: champ obligatoire absent'
 WHEN id IS NULL OR aid IS NULL OR sd IS NULL OR sa IS NULL OR dt_debut IS NULL OR dt_modif IS NULL OR mt IS NULL OR (fin IS NOT NULL AND dt_fin IS NULL) THEN 'validite: conversion impossible'
 WHEN rn>1 THEN 'unicite: doublon dans le lot'
 WHEN mt<0 OR dt_fin<dt_debut THEN 'validite: montant ou chronologie'
 WHEN NOT EXISTS(SELECT 1 FROM vct_private.SubscriberMap m WHERE m.abonne_id=p.aid) OR NOT EXISTS(SELECT 1 FROM vct_curated.stations st WHERE st.station_id=p.sd) OR NOT EXISTS(SELECT 1 FROM vct_curated.stations st WHERE st.station_id=p.sa) THEN 'coherence: reference absente'
 WHEN EXISTS(SELECT 1 FROM vct_private.ErasureLedger e WHERE e.abonne_id=p.aid) THEN 'confidentialite: abonne efface'
 END reason INTO #Checked FROM #Parsed p;
 INSERT vct_ops.Quarantine(run_id,entity,business_key,reason,payload)
 SELECT @BatchId,'locations',CONCAT(COALESCE(location_id,'NULL'),'#',rn),reason,(SELECT c.location_id,c.abonne_id,c.station_depart,c.station_arrivee,c.debut,c.fin,c.montant,c.modifie_le FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM #Checked c WHERE reason IS NOT NULL;
 INSERT vct_ops.QualityMetric(run_id,entity,dimension,checked_rows,failed_rows)
 SELECT @BatchId,'locations',d.dimension,COUNT(*),COALESCE(SUM(CASE WHEN reason LIKE d.dimension+':%' THEN 1 ELSE 0 END),0) FROM #Checked CROSS JOIN(VALUES('completude'),('validite'),('unicite'),('coherence'))d(dimension) GROUP BY d.dimension;
 MERGE vct_curated.locations WITH(HOLDLOCK)t USING(SELECT c.id location_id,CONVERT(VARCHAR(36),m.abonne_token)abonne_token,c.sd station_depart,c.sa station_arrivee,c.dt_debut debut,c.dt_fin fin,c.mt montant,c.dt_modif modifie_le FROM #Checked c JOIN vct_private.SubscriberMap m ON m.abonne_id=c.aid WHERE reason IS NULL)s ON t.location_id=s.location_id
 WHEN MATCHED AND s.modifie_le>=t.modifie_le THEN UPDATE SET abonne_token=s.abonne_token,station_depart=s.station_depart,station_arrivee=s.station_arrivee,debut=s.debut,fin=s.fin,montant=s.montant,modifie_le=s.modifie_le,latest_run=@BatchId
 WHEN NOT MATCHED THEN INSERT(location_id,abonne_token,station_depart,station_arrivee,debut,fin,montant,modifie_le,latest_run)VALUES(s.location_id,s.abonne_token,s.station_depart,s.station_arrivee,s.debut,s.fin,s.montant,s.modifie_le,@BatchId);
 IF (SELECT COUNT(*) FROM #Checked)<>(SELECT COUNT(*) FROM #Checked WHERE reason IS NULL)+(SELECT COUNT(*) FROM #Checked WHERE reason IS NOT NULL) THROW 51001,'Reconciliation du lot impossible',1;
 ;WITH m AS(SELECT TRY_CONVERT(DATE,date_meteo)date_meteo,LEFT(ville,40)ville,TRY_CONVERT(DECIMAL(5,2),temperature)temperature,TRY_CONVERT(DECIMAL(5,2),precipitation)precipitation,ROW_NUMBER() OVER(PARTITION BY date_meteo,ville ORDER BY date_meteo)rn FROM vct_stage.meteo)
 MERGE vct_curated.meteo WITH(HOLDLOCK)t USING(SELECT * FROM m WHERE rn=1 AND date_meteo IS NOT NULL AND temperature IS NOT NULL AND precipitation>=0)s ON t.date_meteo=s.date_meteo AND t.ville=s.ville
 WHEN MATCHED THEN UPDATE SET temperature=s.temperature,precipitation=s.precipitation,latest_run=@BatchId
 WHEN NOT MATCHED THEN INSERT(date_meteo,ville,temperature,precipitation,latest_run)VALUES(s.date_meteo,s.ville,s.temperature,s.precipitation,@BatchId);
 ;WITH a AS(SELECT stationcode,nom,TRY_CONVERT(INT,capacite)capacite,TRY_CONVERT(INT,velos_disponibles)velos_disponibles,TRY_CONVERT(INT,bornes_disponibles)bornes_disponibles,CONVERT(DATETIME2,TRY_CONVERT(DATETIMEOFFSET,observe_le))observe_le,ROW_NUMBER() OVER(PARTITION BY stationcode,observe_le ORDER BY stationcode)rn FROM vct_stage.disponibilite)
 MERGE vct_curated.disponibilite WITH(HOLDLOCK)t USING(SELECT * FROM a WHERE rn=1 AND stationcode IS NOT NULL AND observe_le IS NOT NULL AND capacite>0 AND velos_disponibles>=0 AND bornes_disponibles>=0)s ON t.stationcode=s.stationcode AND t.observe_le=s.observe_le
 WHEN MATCHED THEN UPDATE SET nom=s.nom,capacite=s.capacite,velos_disponibles=s.velos_disponibles,bornes_disponibles=s.bornes_disponibles,latest_run=@BatchId
 WHEN NOT MATCHED THEN INSERT(stationcode,nom,capacite,velos_disponibles,bornes_disponibles,observe_le,latest_run)VALUES(s.stationcode,s.nom,s.capacite,s.velos_disponibles,s.bornes_disponibles,s.observe_le,@BatchId);
 UPDATE vct_ops.RunLog SET rows_read=(SELECT COUNT(*) FROM #Checked),rows_valid=(SELECT COUNT(*) FROM #Checked WHERE reason IS NULL),rows_rejected=(SELECT COUNT(*) FROM #Checked WHERE reason IS NOT NULL),status='Validated' WHERE run_id=@BatchId;
 COMMIT;
 SELECT dimension,checked_rows,failed_rows FROM vct_ops.QualityMetric WHERE run_id=@BatchId;
 SELECT 'locations_curated' entity,COUNT_BIG(*) row_count FROM vct_curated.locations;
END;