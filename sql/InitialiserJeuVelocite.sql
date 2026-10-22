IF SCHEMA_ID('vct_source') IS NULL EXEC('CREATE SCHEMA vct_source');
SET NOCOUNT ON;
IF SCHEMA_ID('vct_ops') IS NULL EXEC('CREATE SCHEMA vct_ops');
IF SCHEMA_ID('vct_stage') IS NULL EXEC('CREATE SCHEMA vct_stage');
IF SCHEMA_ID('vct_curated') IS NULL EXEC('CREATE SCHEMA vct_curated');
IF SCHEMA_ID('vct_mart') IS NULL EXEC('CREATE SCHEMA vct_mart');
IF SCHEMA_ID('vct_private') IS NULL EXEC('CREATE SCHEMA vct_private');
IF OBJECT_ID('vct_source.abonnes') IS NULL CREATE TABLE vct_source.abonnes(abonne_id INT PRIMARY KEY,nom NVARCHAR(80),email NVARCHAR(120),ville NVARCHAR(40),modifie_le DATETIME2);
IF OBJECT_ID('vct_source.stations') IS NULL CREATE TABLE vct_source.stations(station_id INT PRIMARY KEY,nom NVARCHAR(80),capacite INT);
IF OBJECT_ID('vct_source.locations') IS NULL CREATE TABLE vct_source.locations(location_id INT PRIMARY KEY,abonne_id INT,station_depart INT,station_arrivee INT,debut DATETIME2,fin DATETIME2,montant DECIMAL(6,2),modifie_le DATETIME2);
DECLARE @now DATETIME2=SYSUTCDATETIME();
IF NOT EXISTS(SELECT 1 FROM vct_source.abonnes) BEGIN
WITH n AS(SELECT TOP(5000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT vct_source.abonnes SELECT n,CONCAT('Nom',n),CONCAT('abonne',n,'@mail.test'),CHOOSE(n%4+1,'Paris','Lyon','Lille','Nantes'),DATEADD(MINUTE,-CONVERT(INT,n),@now) FROM n;
END;
IF NOT EXISTS(SELECT 1 FROM vct_source.stations) BEGIN
WITH n AS(SELECT TOP(50) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM sys.all_objects)
INSERT vct_source.stations SELECT n,CONCAT('Station ',n),10+n%30 FROM n;
END;
IF NOT EXISTS(SELECT 1 FROM vct_source.locations) BEGIN
WITH n AS(SELECT TOP(200000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT vct_source.locations SELECT n,n%5000+1,n%50+1,(n*7)%50+1,DATEADD(MINUTE,-CONVERT(INT,n),@now),DATEADD(MINUTE,10-CONVERT(INT,n),@now),1+n%9,DATEADD(MINUTE,-CONVERT(INT,n),@now) FROM n;
END;
IF OBJECT_ID('vct_ops.Watermark') IS NULL CREATE TABLE vct_ops.Watermark(entity SYSNAME PRIMARY KEY,last_success DATETIME2 NOT NULL);
INSERT vct_ops.Watermark SELECT v.entity,CAST('1900-01-01' AS DATETIME2) FROM (VALUES('abonnes'),('locations'))v(entity) WHERE NOT EXISTS(SELECT 1 FROM vct_ops.Watermark w WHERE w.entity=v.entity);
IF OBJECT_ID('vct_ops.RunLog') IS NULL CREATE TABLE vct_ops.RunLog(run_id VARCHAR(64) PRIMARY KEY,started_at DATETIME2,ended_at DATETIME2,status VARCHAR(30),upper_bound DATETIME2,rows_read INT NULL,rows_valid INT NULL,rows_rejected INT NULL,details NVARCHAR(1000));
IF OBJECT_ID('vct_ops.QualityMetric') IS NULL CREATE TABLE vct_ops.QualityMetric(run_id VARCHAR(64),entity SYSNAME,dimension VARCHAR(40),checked_rows INT,failed_rows INT,measured_at DATETIME2 DEFAULT SYSUTCDATETIME());
IF OBJECT_ID('vct_ops.Quarantine') IS NULL CREATE TABLE vct_ops.Quarantine(run_id VARCHAR(64),entity SYSNAME,business_key VARCHAR(100),reason NVARCHAR(500),payload NVARCHAR(MAX),created_at DATETIME2 DEFAULT SYSUTCDATETIME(),PRIMARY KEY(run_id,entity,business_key));
IF OBJECT_ID('vct_private.SubscriberMap') IS NULL CREATE TABLE vct_private.SubscriberMap(abonne_id INT PRIMARY KEY,abonne_token UNIQUEIDENTIFIER DEFAULT NEWID());
IF OBJECT_ID('vct_private.ErasureLedger') IS NULL CREATE TABLE vct_private.ErasureLedger(abonne_id INT PRIMARY KEY,erased_at DATETIME2 DEFAULT SYSUTCDATETIME());
SELECT DB_NAME() database_name,'abonnes' entity,COUNT_BIG(*) row_count FROM vct_source.abonnes UNION ALL SELECT DB_NAME(),'stations',COUNT_BIG(*) FROM vct_source.stations UNION ALL SELECT DB_NAME(),'locations',COUNT_BIG(*) FROM vct_source.locations;
SELECT entity,last_success FROM vct_ops.Watermark;