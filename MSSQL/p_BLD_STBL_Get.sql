CREATE PROCEDURE [dbo].[p_BLD_STBL_Get] (
    @ObjectName VARCHAR(200)
    , @Parameters VARCHAR(100) = '[SELECT][REL][TPL][ALT]'
    )
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : [p_BLD_STBL_Get]
-- DateTime       : 2014-10-30
-- Author         : Martin Scheepers
-- Purpose        : Script out SQL Table Definition to CREATE or ALTER Script for Target Database
-- Ver            : 1.2
----------------------------------------------------------------------------------------------------
-- Changes        : 1.1 MJS 20150511 - [VAR] Create VARiable Table on Definition
--                  1.2 MJS 20160830 - Create Table Definition From SQL View
----------------------------------------------------------------------------------------------------
/*
EXEC [dbo].p_BLD_STBL_Get 'ScanDocumentData','[SELECT][ALT][REL][DEP][TPL]'
*/
----------------------------------------------------------------------------------------------------
SET NOCOUNT ON
DECLARE @Rollback BIT   = 0 -- 1 = ROLLBACK TRAN, 0 =  COMMIT TRAN.
DECLARE @UseDB SMALLINT = 0 -- 1 = CFG , 2 = DAT, 0 = ALL
DECLARE @AsAtDate VARCHAR(10)     = Convert(VARCHAR(10),GETDATE(),120)
DECLARE @PROCName VARCHAR(128)= isnull(OBJECT_NAME(@@PROCID),'NONAME')
IF @ObjectName = '?' OR @ObjectName = '' OR @Parameters = '?' OR @Parameters = '' GOTO USAGE_INFO
---------------------------------- >>> BEGIN TANSACTION / TRY >>> ----------------------------------
BEGIN TRANSACTION T1
BEGIN TRY
    ---------------------------------- << DEBUG SECTION >> ---------------------------------------------
    --DECLARE @ObjectName VARCHAR(200) = 'Employment'
    --DECLARE @Parameters VARCHAR(100) = '[SELECT][DEP][REL][TPL][ALT]'
    ------------------------------- << General Variable Declarations >> -------------------------------
    DECLARE @SUserID VARCHAR(50)     = 'NONE'
    DECLARE @ObjType VARCHAR(10)
    --------------------------------- << Declare Exec Line For Proc >> --------------------------------
    DECLARE @ExecLine VARCHAR(MAX)
    SET @ExecLine = '-- EXEC ' + @PROCName + ' ' + '''' +
    @ObjectName + '''' +
    ',' + '''' + Replace(isnull(@Parameters,''),'''','''''') + ''''
    ----------------------------- << Define and Set Paramter Variables >> -----------------------------
    DECLARE @DEBUG TINYINT = 0, @PRINT TINYINT = 0, @SELECT TINYINT = 0
    DECLARE @REL TINYINT = 0, @TPL TINYINT = 0, @VWC TINYINT = 0
    IF isnull(@Parameters,'') = '' SET @Parameters = '[SELECT][DEP][REL][TPL][ALT]'
    IF @Parameters LIKE '%DEBUG%' SET @DEBUG = 1
    IF @Parameters LIKE '%PRINT%' SET @PRINT = 1
    IF @Parameters LIKE '%SELECT%' SET @SELECT = 1
    IF @Parameters LIKE '%REL%' SET @REL = 1
    --IF @Parameters LIKE '%DEP%' SET @DEP = 1
    IF @Parameters LIKE '%TPL%' SET @TPL = 1
    DECLARE @ALT TINYINT = 0, @CRE TINYINT = 0, @TRH TINYINT = 0, @TRF TINYINT = 0, @VAR TINYINT = 0
    IF @Parameters LIKE '%ALT%' SET @ALT = 1
    IF @Parameters LIKE '%CRE%' SET @CRE = 1
    IF @Parameters LIKE '%TRH%' SET @TRH = 1
    IF @Parameters LIKE '%TRF%' SET @TRF = 1
    IF @Parameters LIKE '%VAR%' SET @VAR = 1 -- 1.1
    IF @Parameters LIKE '%VWC%' SET @VWC = 1 -- Convert View to Table DEF
    ------------------- << SET Variable Defaults to Eliminate Conflicting Options >> -------------------
    IF @PRINT = 0 AND @SELECT = 0 SET @SELECT = 1
    IF @SELECT = 1 SET @PRINT = 0
    IF @DEBUG = 1 SET @PRINT = 1
    IF @PRINT = 1 SET @SELECT = 0
    IF @VWC = 1 SET @CRE = 1
    IF @VWC = 1 SET @ALT = 0
    IF @ALT = 1 AND @CRE = 1 SET @CRE = 0
    IF @ALT = 0 AND @CRE = 0 SET @ALT = 1
    IF @VAR = 1 -- 1.1
    BEGIN
	   SET @CRE = 0
	   SET @ALT = 0
    END
    IF @TRH = 1 SET @TRF = 1  
    ---------------------------------- >>> Dependant Object Check >>> ----------------------------------
    IF  NOT EXISTS (Select * From sysobjects WHERE id = OBJECT_ID(N'[dbo].[' + @ObjectName + ']') AND type in (N'U')) AND @VWC = 0
    BEGIN
       PRINT '-- -- >> ERROR: Required Object Does Not Exist : [dbo].[' + @ObjectName + '] : ' + @AsAtDate
       SET @Rollback = 1
    END
    -------------------------------------- >>> BEGIN PROCESS >>> --------------------------------------
    IF @Rollback = 0
    BEGIN
        ----------------------------- << Define and Set Paramter Variables >> -----------------------------
        DECLARE @TPLParms VARCHAR(100) = '[NC][AE][RB][TR]'
        IF @CRE = 1 SET @TPLParms = '[NC]'
        IF @ALT = 1 SET @TPLParms = '[NC][AE][RB][TR]'
        ------------------------- << Declare and Create Variable OUTPUT Tables >> -------------------------
        DECLARE @OUT_RETURN TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        INSERT INTO @OUT_RETURN (ReturnData)
        SELECT '-- ------- >> Execution: ' + @ExecLine -- + ' -- BY SQL USER :' + @SUserID + ' : ' + @AsAtDate
        ----------------------------------------------------------------------------------------------------
        -------------------------------------- << Start Work Here >> ---------------------------------------
        ----------------------------------------------------------------------------------------------------
       ------- Declare Temp Table to Store Source Tables INFORMATION SCHEMA and Load From SQL View --------
       DECLARE @TABLE_SRC TABLE (ID INT IDENTITY,TABLE_NAME NVARCHAR(128), COLUMN_NAME NVARCHAR(128), ORDINAL_POSITION SMALLINT, DATA_TYPE NVARCHAR(128)
       , CHARACTER_MAXIMUM_LENGTH INT, NUMERIC_PRECISION TINYINT, NUMERIC_SCALE SMALLINT, COLUMN_DEFAULT NVARCHAR(4000), IS_NULLABLE NVARCHAR(3)
       , IS_PRIMARY BIT, PK_ORD SMALLINT, PK_DESC TINYINT, SEED_OBJECTID INT, SEED_VALUE SQL_VARIANT, SEED_INCREMENT SQL_VARIANT, CALC_OBJECTID INT, CALC_PERSISTED BIT
       , CALC_DEFINITION NVARCHAR(MAX), DEF_DATATYPE NVARCHAR(MAX), DEF_COLADD NVARCHAR(MAX), DEF_COLALTER NVARCHAR(MAX), DEF_COLDROP NVARCHAR(MAX), R_ACTION VARCHAR(15)
       )
       -- Insert Table Definition into Temp Table From SQL View
       INSERT INTO @TABLE_SRC
       (TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT
       , IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE, DEF_COLADD, DEF_COLALTER, DEF_COLDROP)
       SELECT
       TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT
       , IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE, DEF_COLADD, DEF_COLALTER, DEF_COLDROP
       FROM (
       SELECT
[ST].TABLE_NAME AS TABLE_NAME
,[COL].COLUMN_NAME AS COLUMN_NAME
,[COL].ORDINAL_POSITION AS ORDINAL_POSITION
,[COL].DATA_TYPE AS DATA_TYPE
,[COL].CHARACTER_MAXIMUM_LENGTH AS CHARACTER_MAXIMUM_LENGTH
,[COL].NUMERIC_PRECISION AS NUMERIC_PRECISION
,[COL].NUMERIC_SCALE AS NUMERIC_SCALE
,[COL].COLUMN_DEFAULT AS COLUMN_DEFAULT
,CASE isnull([COL].IS_NULLABLE,'NO') WHEN 'YES' THEN 1 ELSE 0 END AS IS_NULLABLE
,[COL].DATATYPE AS DEF_DATATYPE
, CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].object_id, '') <> '' THEN 1 ELSE 0 END AS IS_PRIMARY
, CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].key_ordinal, 0) <> 0 THEN [SIC].key_ordinal ELSE 0 END AS PK_ORD
, CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].is_descending_key, 0) <> 0 THEN [SIC].is_descending_key ELSE 0 END AS PK_DESC
, isnull([SID].object_id,0) AS SEED_OBJECTID
, isnull([SID].seed_value,0) AS SEED_VALUE
, isnull([SID].increment_value,0) AS SEED_INCREMENT  
, isnull([SCC].object_id,0) AS CALC_OBJECTID
, isnull([SCC].is_persisted,0) AS CALC_PERSISTED
, isnull([SCC].[definition],0) AS CALC_DEFINITION
, 'ALTER TABLE [dbo].[' +  isnull([ST].TABLE_NAME,NULL) + '] ADD [' + isnull([COL].COLUMN_NAME,NULL) + '] ' +
CASE isnull([SCC].object_id, 0)
    WHEN 0 THEN [COL].DATATYPE + ' ' 
    + CASE isnull([SID].object_id, 0) WHEN 0 THEN '' ELSE 'IDENTITY ' END
    + CASE isnull([COL].IS_NULLABLE,'NO') WHEN 'YES' THEN '' ELSE 'NOT NULL' END
    ELSE 'AS ' + isnull([SCC].[definition], NULL) + ' '
    END + ';' AS DEF_COLADD
, 'ALTER TABLE [dbo].[' +  isnull([ST].TABLE_NAME,NULL) + '] ALTER COLUMN [' + isnull([COL].COLUMN_NAME,NULL) + '] ' +
CASE isnull([SCC].object_id, 0)
    WHEN 0 THEN [COL].DATATYPE + ' ' 
    + CASE isnull([SID].object_id, 0) WHEN 0 THEN '' ELSE 'IDENTITY ' END
    + CASE isnull([COL].IS_NULLABLE,'NO') WHEN 'YES' THEN '' ELSE 'NOT NULL' END
    ELSE 'AS ' + isnull([SCC].[definition], NULL) + ' '
    END + ';' AS DEF_COLALTER   
, 'ALTER TABLE [dbo].[' +  isnull([ST].TABLE_NAME,NULL) + '] DROP COLUMN [' + isnull([COL].COLUMN_NAME,NULL) + '] ' + ';' AS DEF_COLDROP
,ST.TABLE_TYPE as TABLE_TYPE
FROM
INFORMATION_SCHEMA.TABLES [ST] WITH (NOLOCK,READUNCOMMITTED)
LEFT JOIN  
    (SELECT
      isnull([COLS].TABLE_NAME,NULL) AS TABLE_NAME
    , isnull([COLS].COLUMN_NAME,NULL) AS COLUMN_NAME
    , isnull([COLS].ORDINAL_POSITION,0) AS ORDINAL_POSITION
    , isnull([COLS].DATA_TYPE,NULL) AS DATA_TYPE
    , isnull([COLS].CHARACTER_MAXIMUM_LENGTH,0) AS CHARACTER_MAXIMUM_LENGTH
    , isnull([COLS].NUMERIC_PRECISION,0) AS NUMERIC_PRECISION
    , isnull([COLS].NUMERIC_SCALE,0) AS NUMERIC_SCALE
    , isnull([COLS].COLUMN_DEFAULT,NULL) AS COLUMN_DEFAULT
    , isnull([COLS].IS_NULLABLE,'0') AS IS_NULLABLE
    , CASE [COLS].DATA_TYPE
        WHEN 'binary' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'char' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'nchar' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'nvarchar' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'varbinary' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'varchar' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN 'MAX' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + ')'
        WHEN 'float' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + ')'
        WHEN 'decimal' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + ',' + cast([COLS].NUMERIC_SCALE AS VARCHAR(10)) + ')'
        WHEN 'numeric' THEN '[' + upper([COLS].DATA_TYPE) + ']' + '(' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + ',' + cast([COLS].NUMERIC_SCALE AS VARCHAR(10)) + ')'
        ELSE '[' + upper([COLS].DATA_TYPE) + ']'
        END AS DATATYPE
    FROM INFORMATION_SCHEMA.COLUMNS [COLS] WITH (NOLOCK,READUNCOMMITTED)) [COL] 
    ON [ST].TABLE_NAME = [COL].TABLE_NAME
LEFT JOIN sys.indexes [SI] WITH (NOLOCK,READUNCOMMITTED) 
    ON OBJECT_ID([ST].TABLE_NAME) = SI.object_id AND SI.is_primary_key = 1
LEFT JOIN sys.index_columns [SIC] WITH (NOLOCK,READUNCOMMITTED) 
    ON SI.object_id = SIC.object_id AND SI.index_id = SIC.index_id AND [COL].COLUMN_NAME = COL_NAME(SIC.object_id,SIC.column_id)
LEFT JOIN sys.identity_columns [SID] WITH (NOLOCK,READUNCOMMITTED) 
    ON OBJECT_ID([ST].TABLE_NAME) = SID.object_id AND [COL].COLUMN_NAME = COL_NAME(SID.object_id,SID.column_id)
LEFT JOIN sys.computed_columns [SCC] WITH (NOLOCK,READUNCOMMITTED) 
    ON OBJECT_ID([ST].TABLE_NAME) = SCC.object_id AND [COL].COLUMN_NAME = COL_NAME(SCC.object_id,SCC.column_id)) v_BLD_STBL_Get
       WHERE TABLE_NAME = @ObjectName 
       ORDER BY ORDINAL_POSITION
       ----------------------------------------------------------------------------------------------------
       DECLARE @Spaces VARCHAR(10)
       SET @Spaces = ''
       SET @Spaces = Space(4)   
       ----------------------------------------------------------------------------------------------------
       IF @ALT = 1
       BEGIN
          INSERT INTO @OUT_RETURN (ReturnData)
          SELECT '    DECLARE @Params VARCHAR(100) '
          UNION ALL SELECT '    DECLARE @ObjectName VARCHAR(200)'
          UNION ALL SELECT '    SET @Params = ''[UA][SELECT]''--[PRINT][SELECT] ([UA]=UNION ALL)'
          UNION ALL SELECT '    SET @ObjectName =  ''' + isnull(@ObjectName,'') + ''''
          UNION ALL SELECT '    /* ------------------------------- <<< SCRIPT TOOLS AND DECLARATIONS >>> --------------*/'
          UNION ALL SELECT '    DECLARE @OUT_RETURN TABLE (ID INT IDENTITY, ReturnData VARCHAR(MAX), InfoType VARCHAR(20))'
          UNION ALL SELECT '    DECLARE @TMP_DEFCONDROP TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_PKCONDROP TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_PKCONCREATE TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGCREATE TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGCOLADD TABLE (ID INT IDENTITY , ColName VARCHAR(128), ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGCOLALT TABLE (ID INT IDENTITY , ColName VARCHAR(128), ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGCOLDROP TABLE (ID INT IDENTITY , ColName VARCHAR(128), ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGDEFADD TABLE (ID INT IDENTITY , ColName VARCHAR(128), ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    DECLARE @TMP_TRGDEFSET TABLE (ID INT IDENTITY , ColName VARCHAR(128), ReturnData VARCHAR(max), InfoType SMALLINT)'
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    -------------------------- <<<< Build Source Table Definition [' + @ObjectName + '] >>>> -------------------------------------'
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    DECLARE @TABLE_SRC TABLE (ID INT IDENTITY,TABLE_NAME NVARCHAR(128), COLUMN_NAME NVARCHAR(128), ORDINAL_POSITION SMALLINT, DATA_TYPE NVARCHAR(128)'
          UNION ALL SELECT '        , CHARACTER_MAXIMUM_LENGTH INT, NUMERIC_PRECISION TINYINT, NUMERIC_SCALE SMALLINT, COLUMN_DEFAULT NVARCHAR(4000), IS_NULLABLE NVARCHAR(3)'
          UNION ALL SELECT '        , IS_PRIMARY BIT, PK_ORD SMALLINT, PK_DESC TINYINT, SEED_OBJECTID INT, SEED_VALUE SQL_VARIANT, SEED_INCREMENT SQL_VARIANT, CALC_OBJECTID INT, CALC_PERSISTED BIT'
          UNION ALL SELECT '        , CALC_DEFINITION NVARCHAR(MAX), DEF_DATATYPE NVARCHAR(MAX), DEF_COLADD NVARCHAR(MAX), DEF_COLALTER NVARCHAR(MAX), DEF_COLDROP NVARCHAR(MAX), R_ACTION VARCHAR(15))'
          UNION ALL SELECT '    INSERT INTO @TABLE_SRC '
          UNION ALL SELECT '        (TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT '
          UNION ALL SELECT '        , IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE, DEF_COLADD, DEF_COLALTER, DEF_COLDROP)'
          -- Add Source Table information (Row 1)
          INSERT INTO @OUT_RETURN (ReturnData)
          SELECT  REPLACE('    SELECT @ObjectName'
          + ',' + '''' + ISNULL(COLUMN_NAME,'NULL') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(ORDINAL_POSITION,'0')) + '''' + ''
          + ',' + '''' + ISNULL(DATA_TYPE,'NULL') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CHARACTER_MAXIMUM_LENGTH,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(NUMERIC_PRECISION,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(NUMERIC_SCALE,'0')) + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(COLUMN_DEFAULT,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + ISNULL(IS_NULLABLE,'0') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(IS_PRIMARY,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(PK_ORD,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(PK_DESC,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(SEED_OBJECTID,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(MAX),ISNULL(SEED_VALUE,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(MAX),ISNULL(SEED_INCREMENT,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CALC_OBJECTID,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CALC_PERSISTED,'0')) + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(CALC_DEFINITION,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_DATATYPE,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLADD,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLALTER,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLDROP,'NULL'),'''','''''') + '''' + '','''NULL''','NULL')
          FROM @TABLE_SRC
          WHERE ID = 1
          -- Add Source Table information (Rest of Rows)
          INSERT INTO @OUT_RETURN (ReturnData)
          SELECT  REPLACE('    UNION ALL SELECT @ObjectName'
          + ',' + '''' + ISNULL(COLUMN_NAME,'NULL') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(ORDINAL_POSITION,'0')) + '''' + ''
          + ',' + '''' + ISNULL(DATA_TYPE,'NULL') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CHARACTER_MAXIMUM_LENGTH,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(NUMERIC_PRECISION,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(NUMERIC_SCALE,'0')) + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(COLUMN_DEFAULT,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + ISNULL(IS_NULLABLE,'0') + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(IS_PRIMARY,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(PK_ORD,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(PK_DESC,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(SEED_OBJECTID,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(MAX),ISNULL(SEED_VALUE,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(MAX),ISNULL(SEED_INCREMENT,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CALC_OBJECTID,'0')) + '''' + ''
          + ',' + '''' + CONVERT(VARCHAR(20),ISNULL(CALC_PERSISTED,'0')) + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(CALC_DEFINITION,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_DATATYPE,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLADD,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLALTER,'NULL'),'''','''''') + '''' + ''
          + ',' + '''' + REPLACE(ISNULL(DEF_COLDROP,'NULL'),'''','''''') + '''' + '','''NULL''','NULL')
          FROM @TABLE_SRC
          WHERE ID > 1
          ORDER BY ID
          ----------------------------------------------------------------------------------------------------
          INSERT INTO @OUT_RETURN (ReturnData)
          SELECT ''
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    -------------------------- <<<< Build Target Table Definition [' + @ObjectName + '] >>>> -------------------------------------'
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    DECLARE @EXIST_TRG BIT = 0'
          UNION ALL SELECT '    DECLARE @PK VARCHAR(max)'
          UNION ALL SELECT '    DECLARE @TABLE_TRG TABLE (ID INT IDENTITY,TABLE_NAME NVARCHAR(128), COLUMN_NAME NVARCHAR(128), ORDINAL_POSITION SMALLINT, DATA_TYPE NVARCHAR(128)'
          UNION ALL SELECT '        , CHARACTER_MAXIMUM_LENGTH INT, NUMERIC_PRECISION TINYINT, NUMERIC_SCALE SMALLINT, COLUMN_DEFAULT NVARCHAR(4000), IS_NULLABLE NVARCHAR(3)'
          UNION ALL SELECT '        , IS_PRIMARY BIT, PK_ORD SMALLINT, PK_DESC TINYINT, SEED_OBJECTID INT, SEED_VALUE SQL_VARIANT, SEED_INCREMENT SQL_VARIANT, CALC_OBJECTID INT, CALC_PERSISTED BIT'
          UNION ALL SELECT '        , CALC_DEFINITION NVARCHAR(MAX), DEF_DATATYPE NVARCHAR(MAX), DEF_COLADD NVARCHAR(MAX), DEF_COLALTER NVARCHAR(MAX), DEF_COLDROP NVARCHAR(MAX), R_ACTION VARCHAR(15))'
          UNION ALL SELECT '    IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''''+ @ObjectName) AND type in (N''U''))'
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        SET @EXIST_TRG = 1'
          UNION ALL SELECT '        INSERT INTO @TABLE_TRG'
          UNION ALL SELECT '        (TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT'
          UNION ALL SELECT '        , IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE, DEF_COLADD, DEF_COLALTER, DEF_COLDROP)'
          UNION ALL SELECT '        SELECT'
          UNION ALL SELECT '        TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT'
          UNION ALL SELECT '        , IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE, DEF_COLADD, DEF_COLALTER, DEF_COLDROP'
          UNION ALL SELECT '        FROM ('
          UNION ALL SELECT '               SELECT'
          UNION ALL SELECT '        [ST].TABLE_NAME AS TABLE_NAME'
          UNION ALL SELECT '        ,[COL].COLUMN_NAME AS COLUMN_NAME'
          UNION ALL SELECT '        ,[COL].ORDINAL_POSITION AS ORDINAL_POSITION'
          UNION ALL SELECT '        ,[COL].DATA_TYPE AS DATA_TYPE'
          UNION ALL SELECT '        ,[COL].CHARACTER_MAXIMUM_LENGTH AS CHARACTER_MAXIMUM_LENGTH'
          UNION ALL SELECT '        ,[COL].NUMERIC_PRECISION AS NUMERIC_PRECISION'
          UNION ALL SELECT '        ,[COL].NUMERIC_SCALE AS NUMERIC_SCALE'
          UNION ALL SELECT '        ,[COL].COLUMN_DEFAULT AS COLUMN_DEFAULT'
          UNION ALL SELECT '        ,CASE isnull([COL].IS_NULLABLE,''NO'') WHEN ''YES'' THEN 1 ELSE 0 END AS IS_NULLABLE'
          UNION ALL SELECT '        ,[COL].DATATYPE AS DEF_DATATYPE'
          UNION ALL SELECT '        , CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].object_id, '''') <> '''' THEN 1 ELSE 0 END AS IS_PRIMARY'
          UNION ALL SELECT '        , CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].key_ordinal, 0) <> 0 THEN [SIC].key_ordinal ELSE 0 END AS PK_ORD'
          UNION ALL SELECT '        , CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SIC].is_descending_key, 0) <> 0 THEN [SIC].is_descending_key ELSE 0 END AS PK_DESC'
          UNION ALL SELECT '        , isnull([SID].object_id,0) AS SEED_OBJECTID'
          UNION ALL SELECT '        , isnull([SID].seed_value,0) AS SEED_VALUE'
          UNION ALL SELECT '        , isnull([SID].increment_value,0) AS SEED_INCREMENT  '
          UNION ALL SELECT '        , isnull([SCC].object_id,0) AS CALC_OBJECTID'
          UNION ALL SELECT '        , isnull([SCC].is_persisted,0) AS CALC_PERSISTED'
          UNION ALL SELECT '        , isnull([SCC].[definition],0) AS CALC_DEFINITION'
          UNION ALL SELECT '        , ''ALTER TABLE [dbo].['' +  isnull([ST].TABLE_NAME,NULL) + ''] ADD ['' + isnull([COL].COLUMN_NAME,NULL) + ''] '' +'
          UNION ALL SELECT '        CASE isnull([SCC].object_id, 0)'
          UNION ALL SELECT '            WHEN 0 THEN [COL].DATATYPE + '' '' '
          UNION ALL SELECT '            + CASE isnull([SID].object_id, 0) WHEN 0 THEN '''' ELSE ''IDENTITY '' END'
          UNION ALL SELECT '            + CASE isnull([COL].IS_NULLABLE,''NO'') WHEN ''YES'' THEN '''' ELSE ''NOT NULL'' END'
          UNION ALL SELECT '            ELSE ''AS '' + isnull([SCC].[definition], NULL) + '' '''
          UNION ALL SELECT '            END + '';'' AS DEF_COLADD'
          UNION ALL SELECT '        , ''ALTER TABLE [dbo].['' +  isnull([ST].TABLE_NAME,NULL) + ''] ALTER COLUMN ['' + isnull([COL].COLUMN_NAME,NULL) + ''] '' +'
          UNION ALL SELECT '        CASE isnull([SCC].object_id, 0)'
          UNION ALL SELECT '            WHEN 0 THEN [COL].DATATYPE + '' '' '
          UNION ALL SELECT '            + CASE isnull([SID].object_id, 0) WHEN 0 THEN '''' ELSE ''IDENTITY '' END'
          UNION ALL SELECT '            + CASE isnull([COL].IS_NULLABLE,''NO'') WHEN ''YES'' THEN '''' ELSE ''NOT NULL'' END'
          UNION ALL SELECT '           ELSE ''AS '' + isnull([SCC].[definition], NULL) + '' '''
          UNION ALL SELECT '            END + '';'' AS DEF_COLALTER   '
          UNION ALL SELECT '        , ''ALTER TABLE [dbo].['' +  isnull([ST].TABLE_NAME,NULL) + ''] DROP COLUMN ['' + isnull([COL].COLUMN_NAME,NULL) + ''] '' + '';'' AS DEF_COLDROP'
          UNION ALL SELECT '        ,ST.TABLE_TYPE as TABLE_TYPE'
          UNION ALL SELECT '        FROM'
          UNION ALL SELECT '        INFORMATION_SCHEMA.TABLES [ST] WITH (NOLOCK,READUNCOMMITTED)'
          UNION ALL SELECT '        LEFT JOIN  '
          UNION ALL SELECT '            (SELECT'
          UNION ALL SELECT '              isnull([COLS].TABLE_NAME,NULL) AS TABLE_NAME'
          UNION ALL SELECT '            , isnull([COLS].COLUMN_NAME,NULL) AS COLUMN_NAME'
          UNION ALL SELECT '            , isnull([COLS].ORDINAL_POSITION,0) AS ORDINAL_POSITION'
          UNION ALL SELECT '            , isnull([COLS].DATA_TYPE,NULL) AS DATA_TYPE'
          UNION ALL SELECT '            , isnull([COLS].CHARACTER_MAXIMUM_LENGTH,0) AS CHARACTER_MAXIMUM_LENGTH'
          UNION ALL SELECT '            , isnull([COLS].NUMERIC_PRECISION,0) AS NUMERIC_PRECISION'
          UNION ALL SELECT '            , isnull([COLS].NUMERIC_SCALE,0) AS NUMERIC_SCALE'
          UNION ALL SELECT '            , isnull([COLS].COLUMN_DEFAULT,NULL) AS COLUMN_DEFAULT'
          UNION ALL SELECT '            , isnull([COLS].IS_NULLABLE,''0'') AS IS_NULLABLE'
          UNION ALL SELECT '            , CASE [COLS].DATA_TYPE'
          UNION ALL SELECT '                WHEN ''binary'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''char'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''nchar'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''nvarchar'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''varbinary'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''varchar'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + CASE [COLS].CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE CAST([COLS].CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END + '')'''
          UNION ALL SELECT '                WHEN ''float'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + '')'''
          UNION ALL SELECT '                WHEN ''decimal'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + '','' + cast([COLS].NUMERIC_SCALE AS VARCHAR(10)) + '')'''
          UNION ALL SELECT '                WHEN ''numeric'' THEN ''['' + upper([COLS].DATA_TYPE) + '']'' + ''('' + cast([COLS].NUMERIC_PRECISION AS VARCHAR(10)) + '','' + cast([COLS].NUMERIC_SCALE AS VARCHAR(10)) + '')'''
          UNION ALL SELECT '                ELSE ''['' + upper([COLS].DATA_TYPE) + '']'''
          UNION ALL SELECT '                END AS DATATYPE'
          UNION ALL SELECT '            FROM INFORMATION_SCHEMA.COLUMNS [COLS] WITH (NOLOCK,READUNCOMMITTED)) [COL] '
          UNION ALL SELECT '            ON [ST].TABLE_NAME = [COL].TABLE_NAME'
          UNION ALL SELECT '        LEFT JOIN sys.indexes [SI] WITH (NOLOCK,READUNCOMMITTED) '
          UNION ALL SELECT '            ON OBJECT_ID([ST].TABLE_NAME) = SI.object_id AND SI.is_primary_key = 1'
          UNION ALL SELECT '        LEFT JOIN sys.index_columns [SIC] WITH (NOLOCK,READUNCOMMITTED) '
          UNION ALL SELECT '            ON SI.object_id = SIC.object_id AND SI.index_id = SIC.index_id AND [COL].COLUMN_NAME = COL_NAME(SIC.object_id,SIC.column_id)'
          UNION ALL SELECT '        LEFT JOIN sys.identity_columns [SID] WITH (NOLOCK,READUNCOMMITTED) '
          UNION ALL SELECT '            ON OBJECT_ID([ST].TABLE_NAME) = SID.object_id AND [COL].COLUMN_NAME = COL_NAME(SID.object_id,SID.column_id)'
          UNION ALL SELECT '        LEFT JOIN sys.computed_columns [SCC] WITH (NOLOCK,READUNCOMMITTED) '
          UNION ALL SELECT '            ON OBJECT_ID([ST].TABLE_NAME) = SCC.object_id AND [COL].COLUMN_NAME = COL_NAME(SCC.object_id,SCC.column_id)) v_BLD_STBL_Get'
          UNION ALL SELECT '        WHERE TABLE_NAME = @ObjectName'
          UNION ALL SELECT '        ORDER BY ORDINAL_POSITION'
          UNION ALL SELECT '        ------------------------------------- <<< DROP All Default Contraints >>> -----------------------------------------------------'
          UNION ALL SELECT '        -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '        IF EXISTS (SELECT SD.name FROM sys.default_constraints SD'
          UNION ALL SELECT '            LEFT JOIN sys.columns SC ON  SC.default_object_id  = SD.object_id'
          UNION ALL SELECT '            LEFT JOIN @TABLE_SRC SRC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME'
          UNION ALL SELECT '            WHERE OBJECT_NAME(SD.parent_object_id ) = @ObjectName'
          UNION ALL SELECT '            AND (SRC.COLUMN_DEFAULT IS NULL OR REPLACE(REPLACE(SRC.COLUMN_DEFAULT,'')'',''''),''('','''') <> REPLACE(REPLACE(SD.definition,'')'',''''),''('','''')))'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            INSERT INTO @TMP_DEFCONDROP (ReturnData)'
          UNION ALL SELECT '            SELECT ''ALTER TABLE ['' + @ObjectName + ''] DROP CONSTRAINT ['' + SD.name + ''] ; -- Current Value:'' + ISNULL(SD.definition,''NULL'') + '', New Value:'' + ISNULL(SRC.COLUMN_DEFAULT,''NULL'')'
          UNION ALL SELECT '            FROM sys.default_constraints SD'
          UNION ALL SELECT '                LEFT JOIN sys.columns SC ON  SC.default_object_id  = SD.object_id'
          UNION ALL SELECT '                LEFT JOIN @TABLE_SRC SRC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME'
          UNION ALL SELECT '                WHERE OBJECT_NAME(SD.parent_object_id ) = @ObjectName'
          UNION ALL SELECT '                AND (SRC.COLUMN_DEFAULT IS NULL OR REPLACE(REPLACE(SRC.COLUMN_DEFAULT,'')'',''''),''('','''') <> REPLACE(REPLACE(SD.definition,'')'',''''),''('',''''))'
          UNION ALL SELECT '            INSERT INTO @TMP_DEFCONDROP (ReturnData)'
          UNION ALL SELECT '            SELECT ''GO'''
          UNION ALL SELECT '        END'
          UNION ALL SELECT '    END --IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''''+ @ObjectName) AND type in (N''U''))'
          UNION ALL SELECT '    ELSE'
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        ------------------------------------- <<< Target Table Does Not Exist - Need to Create >>> ------------------------------------'
          UNION ALL SELECT '        -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '        SET @EXIST_TRG = 0'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '        SELECT '''''
          UNION ALL SELECT '        UNION ALL SELECT ''CREATE TABLE ['' + @ObjectName + '']('''
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '        SELECT ''    ['' + isnull(COLUMN_NAME,'''') + ''] '' +'
          UNION ALL SELECT '        CASE WHEN isnull(CALC_OBJECTID,0) > 0 THEN '' AS '' + isnull(CALC_DEFINITION, NULL) + '''' ELSE isnull(DEF_DATATYPE,'''')  + '''' +'
          UNION ALL SELECT '            CASE WHEN isnull(SEED_OBJECTID,0) > 0 THEN '' IDENTITY('' + Convert(VARCHAR(max),isnull(SEED_VALUE, 0)) + '','' + Convert(VARCHAR(max),isnull(SEED_INCREMENT, 0)) + '')'' ELSE '''' END +'
          UNION ALL SELECT '            CASE isnull(IS_NULLABLE,''0'') WHEN ''1'' THEN '''' ELSE '' NOT NULL'' END'
          UNION ALL SELECT '        END + '','''
          UNION ALL SELECT '        FROM @TABLE_SRC'
          UNION ALL SELECT '        IF EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY > 0)'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '            SELECT ''CONSTRAINT [PK_'' + @ObjectName + ''] PRIMARY KEY CLUSTERED '''
          UNION ALL SELECT '            SET @PK = ''    ('''
          UNION ALL SELECT '            SELECT TOP 10 @PK = @PK + ''['' + COLUMN_NAME + ''] '' + CASE WHEN ISNULL(PK_DESC,0)=0 THEN ''ASC'' Else ''DESC'' END + '', '''
          UNION ALL SELECT '            FROM @TABLE_SRC'
          UNION ALL SELECT '            WHERE IS_PRIMARY > 0'
          UNION ALL SELECT '            ORDER BY PK_ORD'
          UNION ALL SELECT '            SET @PK = LEFT(@PK,LEN(@PK)-1) + '')'''
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '            SELECT @PK'
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '            SELECT '' ON [PRIMARY]'''
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCREATE (ReturnData)'
          UNION ALL SELECT '            SELECT '') ON [PRIMARY]'''
          UNION ALL SELECT '            UNION ALL SELECT ''GO'''
          UNION ALL SELECT '    END'
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    IF @EXIST_TRG = 1'
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCOLALT (ColName,ReturnData)'
          UNION ALL SELECT '        SELECT COLUMN_NAME,DEF_COLALTER FROM @TABLE_SRC'
          UNION ALL SELECT '        WHERE COLUMN_NAME IN'
          UNION ALL SELECT '        (SELECT COLUMN_NAME'
          UNION ALL SELECT '            FROM (SELECT COLUMN_NAME, DEF_DATATYPE ,IS_NULLABLE, CALC_DEFINITION FROM @TABLE_SRC'
          UNION ALL SELECT '                    EXCEPT'
          UNION ALL SELECT '                    SELECT COLUMN_NAME, DEF_DATATYPE ,IS_NULLABLE, CALC_DEFINITION FROM @TABLE_TRG) COLS'
          UNION ALL SELECT '                    WHERE COLS.COLUMN_NAME NOT IN (SELECT COLUMN_NAME FROM @TABLE_SRC'
          UNION ALL SELECT '                        EXCEPT'
          UNION ALL SELECT '                        SELECT COLUMN_NAME FROM @TABLE_TRG))'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCOLALT (ColName,ReturnData)'
          UNION ALL SELECT '        SELECT COLUMN_NAME,''-- PK -- '' + DEF_COLALTER FROM @TABLE_SRC'
          UNION ALL SELECT '        WHERE COLUMN_NAME IN'
          UNION ALL SELECT '        (SELECT COLUMN_NAME'
          UNION ALL SELECT '            FROM (SELECT COLUMN_NAME,IS_PRIMARY FROM @TABLE_SRC'
          UNION ALL SELECT '                    EXCEPT'
          UNION ALL SELECT '                    SELECT COLUMN_NAME,IS_PRIMARY FROM @TABLE_TRG) COLS'
          UNION ALL SELECT '                    WHERE COLS.COLUMN_NAME NOT IN (SELECT COLUMN_NAME FROM @TABLE_SRC'
          UNION ALL SELECT '                        EXCEPT'
          UNION ALL SELECT '                        SELECT COLUMN_NAME FROM @TABLE_TRG))'
          UNION ALL SELECT '        IF EXISTS (SELECT ReturnData FROm @TMP_TRGCOLALT)'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCOLALT (ReturnData)'
          UNION ALL SELECT '            SELECT ''GO'''
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCOLADD (ColName,ReturnData)'
          UNION ALL SELECT '            SELECT COLUMN_NAME,DEF_COLADD FROM @TABLE_SRC'
          UNION ALL SELECT '            WHERE COLUMN_NAME IN (SELECT COLUMN_NAME FROM @TABLE_SRC'
          UNION ALL SELECT '            EXCEPT'
          UNION ALL SELECT '            SELECT COLUMN_NAME FROM @TABLE_TRG)'
          UNION ALL SELECT '        IF EXISTS (SELECT ReturnData FROm @TMP_TRGCOLADD)'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCOLADD (ReturnData)'
          UNION ALL SELECT '            SELECT ''GO'''
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGCOLDROP (ColName,ReturnData)'
          UNION ALL SELECT '            SELECT COLUMN_NAME,''-- --'' + DEF_COLDROP FROM @TABLE_TRG'
          UNION ALL SELECT '            WHERE COLUMN_NAME IN (SELECT COLUMN_NAME FROM @TABLE_TRG'
          UNION ALL SELECT '            EXCEPT'
          UNION ALL SELECT '            SELECT COLUMN_NAME FROM @TABLE_SRC)'
          UNION ALL SELECT '        IF EXISTS (SELECT ReturnData FROm @TMP_TRGCOLDROP)'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            INSERT INTO @TMP_TRGCOLDROP (ReturnData)'
          UNION ALL SELECT '            SELECT ''-- --GO'''
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '        IF EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY > 0' 
          UNION ALL SELECT '            AND COLUMN_NAME IN (SELECT ColName FROM @TMP_TRGCOLALT'
          UNION ALL SELECT '                      UNION ALL SELECT ColName FROM @TMP_TRGCOLADD'
          UNION ALL SELECT '                      UNION ALL SELECT ColName FROM @TMP_TRGCOLDROP))'
          UNION ALL SELECT '        OR EXISTS (SELECT IS_PRIMARY FROM @TABLE_TRG WHERE IS_PRIMARY > 0' 
          UNION ALL SELECT '            AND COLUMN_NAME IN (SELECT ColName FROM @TMP_TRGCOLALT'
          UNION ALL SELECT '                      UNION ALL SELECT ColName FROM @TMP_TRGCOLADD'
          UNION ALL SELECT '                      UNION ALL SELECT ColName FROM @TMP_TRGCOLDROP))'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            DECLARE @PKN VARCHAR(200)'
          UNION ALL SELECT '            DECLARE @PKD VARCHAR(max)'
          UNION ALL SELECT '            SELECT TOP 1 @PKN = [SI].name FROM sys.tables ST WITH (NOLOCK,READUNCOMMITTED)'
          UNION ALL SELECT '            LEFT JOIN sys.indexes SI WITH (NOLOCK,READUNCOMMITTED) ON ST.object_id = SI.object_id AND SI.is_primary_key = 1'
          UNION ALL SELECT '            WHERE ST.name = @ObjectName'
          UNION ALL SELECT '            SET @PKD = ''ALTER TABLE ['' + @ObjectName + ''] DROP CONSTRAINT ['' + @PKN + '']'''
          UNION ALL SELECT '            SET @PK = ''ALTER TABLE ['' + @ObjectName + ''] ADD CONSTRAINT [PK_'' + @ObjectName + ''] PRIMARY KEY CLUSTERED    ('''
          UNION ALL SELECT '            SELECT TOP 10 @PK = @PK + ''['' + COLUMN_NAME + ''] '' + CASE WHEN ISNULL(PK_DESC,0)=0 THEN ''ASC'' Else ''DESC'' END + '', '''
          UNION ALL SELECT '            FROM @TABLE_SRC WHERE IS_PRIMARY > 0 ORDER BY PK_ORD'
          UNION ALL SELECT '            SET @PK = LEFT(@PK,LEN(@PK)-1) + '')'''
          UNION ALL SELECT '            INSERT INTO @TMP_PKCONDROP (ReturnData) SELECT @PKD'
          UNION ALL SELECT '            INSERT INTO @TMP_PKCONCREATE (ReturnData) SELECT @PK'
          UNION ALL SELECT '            IF EXISTS (SELECT ReturnData FROm @TMP_PKCONDROP)'
          UNION ALL SELECT '            BEGIN'
          UNION ALL SELECT '                INSERT INTO @TMP_PKCONDROP (ReturnData)'
          UNION ALL SELECT '                SELECT ''GO'''
          UNION ALL SELECT '            END'
          UNION ALL SELECT '            IF EXISTS (SELECT ReturnData FROm @TMP_PKCONCREATE)'
          UNION ALL SELECT '            BEGIN'
          UNION ALL SELECT '                INSERT INTO @TMP_PKCONCREATE (ReturnData)'
          UNION ALL SELECT '                SELECT ''GO'''
          UNION ALL SELECT '            END'
          UNION ALL SELECT '        END'
          UNION ALL SELECT '    END --IF @EXIST_TRG = 1'
          UNION ALL SELECT '    INSERT INTO @TMP_TRGDEFADD (ReturnData)'
          UNION ALL SELECT '        SELECT ''ALTER TABLE [''+SRC.TABLE_NAME+''] ADD CONSTRAINT [DF_''+SRC.TABLE_NAME+''_''+SRC.COLUMN_NAME+''] DEFAULT ''+SRC.COLUMN_DEFAULT+'' FOR [''+SRC.COLUMN_NAME+''] -- Current Value:''+ISNULL(SD.definition,''NULL'')+'',New Value:''+ISNULL(SRC.COLUMN_DEFAULT,''NULL'')'
          UNION ALL SELECT '        FROM @TABLE_SRC SRC'
          UNION ALL SELECT '        LEFT JOIN sys.columns SC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME'
          UNION ALL SELECT '        LEFT JOIN  sys.default_constraints SD ON  SC.default_object_id  = SD.object_id'
          UNION ALL SELECT '        WHERE REPLACE(REPLACE(SRC.COLUMN_DEFAULT,'')'',''''),''('','''') <> REPLACE(REPLACE(isnull(SD.definition,''''),'')'',''''),''('','''')'
          UNION ALL SELECT '    IF EXISTS (SELECT ReturnData FROm @TMP_TRGDEFADD)'
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGDEFADD (ReturnData)'
          UNION ALL SELECT '        SELECT ''GO'''
          UNION ALL SELECT '    END'
          UNION ALL SELECT '    -------------------------------------------------------------------------------------------------------------------------------'
          UNION ALL SELECT '    INSERT INTO @TMP_TRGDEFSET (ReturnData)'
          UNION ALL SELECT '    SELECT ''UPDATE ['' + SRC.TABLE_NAME  + ''] SET ['' + SRC.COLUMN_NAME + '']  = '' + SRC.COLUMN_DEFAULT + '' WHERE ['' + SRC.COLUMN_NAME + ''] IS NULL ;'''
          UNION ALL SELECT '        FROM @TABLE_SRC SRC'
          UNION ALL SELECT '        LEFT JOIN sys.columns SC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME'
          UNION ALL SELECT '        LEFT JOIN  sys.default_constraints SD ON SC.default_object_id  = SD.object_id'
          UNION ALL SELECT '        WHERE REPLACE(REPLACE(SRC.COLUMN_DEFAULT,'')'',''''),''('','''') <> REPLACE(REPLACE(isnull(SD.definition,''''),'')'',''''),''('','''')'
          UNION ALL SELECT '        ORDER BY SRC.COLUMN_NAME' 
          UNION ALL SELECT '    IF EXISTS (SELECT ReturnData FROm @TMP_TRGDEFSET)'
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        INSERT INTO @TMP_TRGDEFSET (ReturnData)'
          UNION ALL SELECT '        SELECT ''GO'''
          UNION ALL SELECT '    END'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData)'
          UNION ALL SELECT '    SELECT ''------------------------------------- <<< Actions Required for: ['' + @ObjectName + ''] >>> ----- --------------------'''
          IF @TRH = 1
          BEGIN
               INSERT INTO @OUT_RETURN (ReturnData)
             SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH SET CONCAT_NULL_YIELDS_NULL, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, XACT_ABORT ON'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH  O'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH SET TRANSACTION ISOLATION LEVEL SERIALIZABLE'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH GO'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH BEGIN TRANSACTION'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRH GO'''
           END         
           INSERT INTO @OUT_RETURN (ReturnData)
          SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_DEFCONDROP WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_PKCONDROP WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGCREATE WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGCOLADD WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGCOLALT WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGCOLDROP WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGDEFADD WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGDEFSET WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_PKCONCREATE WHERE ISNULL(REPLACE(ReturnData,'' '',''''), '''') <> '''' ORDER BY ID'
          IF @TRF = 1
          BEGIN
             INSERT INTO @OUT_RETURN (ReturnData)
               SELECT 'IF (SELECT COUNT(RETURNDATA)FROM @OUT_RETURN) > 1'
             UNION ALL SELECT 'BEGIN'
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRF IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END'''
             UNION ALL SELECT '    INSERT INTO @OUT_RETURN (ReturnData) SELECT ''--#TRF GO'''
             UNION ALL SELECT 'END'
          END
          INSERT INTO @OUT_RETURN (ReturnData)
          SELECT '    ---------------------------------------- << RETURN DATA >> ----------------------------------------'
          UNION ALL SELECT '    IF @Params LIKE ''%PRINT%'''
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        IF CURSOR_STATUS(''global'',''MasterCursor'')>=-1'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            CLOSE MasterCursor'
          UNION ALL SELECT '            DEALLOCATE MasterCursor'
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        DECLARE @PrintText VARCHAR(8000)'
          UNION ALL SELECT '        DECLARE MasterCursor CURSOR FOR'
          UNION ALL SELECT '        SELECT ReturnData FROM @OUT_RETURN ORDER BY ID'
          UNION ALL SELECT '        OPEN MasterCursor'
          UNION ALL SELECT '        FETCH NEXT FROM MasterCursor INTO @PrintText'
          UNION ALL SELECT '        WHILE (@@FETCH_STATUS = 0)'
          UNION ALL SELECT '        BEGIN'
          UNION ALL SELECT '            PRINT @PrintText'
          UNION ALL SELECT '            FETCH NEXT FROM MasterCursor INTO  @PrintText'
          UNION ALL SELECT '        END'
          UNION ALL SELECT '        CLOSE MasterCursor'
          UNION ALL SELECT '        DEALLOCATE MasterCursor'
          UNION ALL SELECT '    END'
          UNION ALL SELECT '    IF @Params LIKE ''%SELECT%'''
          UNION ALL SELECT '    BEGIN'
          UNION ALL SELECT '        SELECT ReturnData AS ''--ReturnData'' FROM @OUT_RETURN ORDER BY ID'
          UNION ALL SELECT '    END'
       END
       IF @CRE = 1
       BEGIN
          ------------------------------------- <<< DROP All Default Contraints >>> -----------------------------------------------------
          -------------------------------------------------------------------------------------------------------------------------------
          DECLARE @TMP_DEFCONDROP TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
          DECLARE @TMP_TRGDEFADD TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
          IF EXISTS (SELECT SD.name FROM sys.default_constraints SD
             LEFT JOIN sys.columns SC ON  SC.default_object_id  = SD.object_id
             LEFT JOIN @TABLE_SRC SRC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME
             WHERE OBJECT_NAME(SD.parent_object_id ) = @ObjectName
             AND isnull(SRC.COLUMN_DEFAULT,'')<>'')
          BEGIN
             INSERT INTO @TMP_DEFCONDROP (ReturnData)
             SELECT 'IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N''[' + SD.name + ']'') AND type = ''D'') ' + 
             'ALTER TABLE [' + @ObjectName + '] DROP CONSTRAINT [' + SD.name + '] ;'
             FROM sys.default_constraints SD
                LEFT JOIN sys.columns SC ON  SC.default_object_id  = SD.object_id
                LEFT JOIN @TABLE_SRC SRC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME AND SC.name = SRC.COLUMN_NAME
                WHERE OBJECT_NAME(SD.parent_object_id ) = @ObjectName
                AND isnull(SRC.COLUMN_DEFAULT,'')<>''
                ORDER BY SRC.COLUMN_NAME 
             INSERT INTO @TMP_DEFCONDROP (ReturnData)
             SELECT 'GO'
             -------------------------------------------------------------------------------------------------------------------------------
             INSERT INTO @TMP_TRGDEFADD (ReturnData)
             SELECT 'ALTER TABLE ['+SRC.TABLE_NAME+'] ADD CONSTRAINT [DF_'+SRC.TABLE_NAME+'_'+SRC.COLUMN_NAME+'] DEFAULT '+SRC.COLUMN_DEFAULT+' FOR ['+SRC.COLUMN_NAME+']'
             FROM sys.default_constraints SD
             LEFT JOIN sys.columns SC ON  SC.default_object_id  = SD.object_id
             LEFT JOIN @TABLE_SRC SRC ON OBJECT_NAME(SC.object_id ) = SRC.TABLE_NAME    AND SC.name = SRC.COLUMN_NAME
             WHERE OBJECT_NAME(SD.parent_object_id ) = @ObjectName
             AND isnull(SRC.COLUMN_DEFAULT,'')<>''
             ORDER BY SRC.COLUMN_NAME 
             IF EXISTS (SELECT ReturnData FROm @TMP_TRGDEFADD)
             BEGIN
                INSERT INTO @TMP_TRGDEFADD (ReturnData)
                SELECT 'GO'
             END
          END
          ------------------------------------- <<< Target Table Does Not Exist - Need to Create >>> ------------------------------------
          -------------------------------------------------------------------------------------------------------------------------------
          DECLARE @TMP_TRGCREATE TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
          INSERT INTO @TMP_TRGCREATE (ReturnData)
          SELECT ''
          UNION ALL SELECT 'IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[' + @ObjectName + ']'') AND type in (N''U''))'
          UNION ALL SELECT '    DROP TABLE [' + @ObjectName + ']'
          UNION ALL SELECT '    GO'
          INSERT INTO @TMP_TRGCREATE (ReturnData)
          SELECT ''
          UNION ALL SELECT 'CREATE TABLE [' + @ObjectName + ']('
          INSERT INTO @TMP_TRGCREATE (ReturnData)
          SELECT '    [' + isnull(COLUMN_NAME,'') + '] ' +
          CASE WHEN isnull(CALC_OBJECTID,0) > 0 THEN ' AS ' + isnull(CALC_DEFINITION, NULL) + '' ELSE isnull(DEF_DATATYPE,'')  + '' +
             CASE WHEN isnull(SEED_OBJECTID,0) > 0 THEN ' IDENTITY(' + Convert(VARCHAR(max),isnull(SEED_VALUE, 0)) + ',' + Convert(VARCHAR(max),isnull(SEED_INCREMENT, 0)) + ')' ELSE '' END +
             CASE isnull(IS_NULLABLE,'0') WHEN '1' THEN '' ELSE ' NOT NULL' END
          END + ','
          FROM @TABLE_SRC
          IF EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY > 0)
          BEGIN
             INSERT INTO @TMP_TRGCREATE (ReturnData)
             SELECT 'CONSTRAINT [PK_' + @ObjectName + '] PRIMARY KEY CLUSTERED '
             DECLARE @PK VARCHAR(max)
             SET @PK = '    ('
             SELECT TOP 10 @PK = @PK + '[' + COLUMN_NAME + '] ' + CASE WHEN ISNULL(PK_DESC,0)=0 THEN 'ASC' Else 'DESC' END + ', '
             FROM @TABLE_SRC
             WHERE IS_PRIMARY > 0
             ORDER BY PK_ORD
             SET @PK = LEFT(@PK,LEN(@PK)-1) + ')'
             INSERT INTO @TMP_TRGCREATE (ReturnData)
             SELECT @PK
             INSERT INTO @TMP_TRGCREATE (ReturnData)
             SELECT ' ON [PRIMARY]'
          END
          INSERT INTO @TMP_TRGCREATE (ReturnData)
             SELECT ') ON [PRIMARY]'
             UNION ALL SELECT 'GO'
          -------------------------------------------------------------------------------------------------------------------------------
          INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_DEFCONDROP WHERE ISNULL(REPLACE(ReturnData,' ',''), '') <> '' ORDER BY ID
          INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGCREATE WHERE ISNULL(REPLACE(ReturnData,' ',''), '') <> '' ORDER BY ID
          INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGDEFADD WHERE ISNULL(REPLACE(ReturnData,' ',''), '') <> '' ORDER BY ID
       END
       IF @VAR = 1
       BEGIN
          ------------------------------------- <<< DEFINE Variable Table >>> ------------------------------------
          -------------------------------------------------------------------------------------------------------------------------------
          DECLARE @TMP_TRGVARIABLE TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT ''
          UNION ALL SELECT 'DECLARE @' + @ObjectName + ' TABLE ('
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT '    ID INT IDENTITY, -- NOT DEFINED..Variable only'
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT '    ' + isnull(COLUMN_NAME,'') + ' ' + REPLACE(REPLACE(isnull(DEF_DATATYPE,''),'[',''),']','')  + '' + ','
          FROM @TABLE_SRC
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT ')'
          -------
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT 'INSERT INTO @' + @ObjectName
          DECLARE @FieldsSTR VARCHAR(MAX)
          SET @FieldsSTR = ''
          SELECT @FieldsSTR = @FieldsSTR + isnull(COLUMN_NAME,'') + ', '
          FROM @TABLE_SRC
          SET @FieldsSTR = LEFT(@FieldsSTR,LEN(@FieldsSTR) - 1)
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT '    (' + @FieldsSTR + ')'
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT 'SELECT ' + @FieldsSTR
          INSERT INTO @TMP_TRGVARIABLE (ReturnData)
          SELECT 'FROM ' + @ObjectName + ' WITH (NOLOCK,READUNCOMMITTED)'
          -------------------------------------------------------------------------------------------------------------------------------
          INSERT INTO @OUT_RETURN (ReturnData) SELECT ReturnData FROM @TMP_TRGVARIABLE WHERE ISNULL(REPLACE(ReturnData,' ',''), '') <> '' ORDER BY ID
       END
       ----------------------------------------------------------------------------------------------------
        --------------------------------------- <<< END PROCESS <<< ---------------------------------------
        ----------------------------------------------------------------------------------------------------
    END
    ---------------------------------------------------------------------------------------------------
    ---------------------------------------- << RETURN DATA >> ----------------------------------------
    ---------------------------------------------------------------------------------------------------
    IF @Rollback = 0
    BEGIN
        IF @PRINT = 1
        BEGIN
            ---------------------------------------------------------------------------------------------------
            -------------------------------- << PRINT DATA FROM OUTPUT TABLE >> --------------------------------
            ---------------------------------------------------------------------------------------------------
            IF CURSOR_STATUS('global','MasterCursor')>=-1
          BEGIN
             CLOSE MasterCursor
             DEALLOCATE MasterCursor
          END
            DECLARE @PrintText VARCHAR(8000)
            DECLARE MasterCursor CURSOR FOR
            SELECT ReturnData FROM @OUT_RETURN ORDER BY ID
            OPEN MasterCursor
            FETCH NEXT FROM MasterCursor INTO @PrintText
            WHILE (@@FETCH_STATUS = 0)
            BEGIN
                PRINT @PrintText
                FETCH NEXT FROM MasterCursor INTO  @PrintText
            END
            CLOSE MasterCursor
            DEALLOCATE MasterCursor
        END
        IF @SELECT = 1
        BEGIN
            ---------------------------------------------------------------------------------------------------
            -------------------------------- << RETURN DATA FROM OUTPUT TABLE >> ------------------------------
            ---------------------------------------------------------------------------------------------------
            SELECT ReturnData AS '--ReturnData'
            FROM @OUT_RETURN
            WHERE ISNULL(ReturnData,'') <> ''
            ORDER BY ID
            ---------------------------------------------------------------------------------------------------
        END
      
    END
END TRY
------------------------------------ <<< COMMIT / ROLLBACK <<< ------------------------------------
-- Check If Error Has Been Caught by TRY METHOD
BEGIN CATCH
    SET @Rollback = 1
    DECLARE @ErrorMessage NVARCHAR(2000),@ErrorSeverity INT,@ErrorState INT,@ErrorNo VARCHAR(10), @ErrorLine VARCHAR(10)
    SELECT @ErrorMessage = ERROR_MESSAGE(),@ErrorSeverity = ERROR_SEVERITY(),@ErrorState = ERROR_STATE()
        ,@ErrorNo = CAST(ERROR_NUMBER() AS VARCHAR) ,@ErrorLine = CAST(ERROR_LINE() AS VARCHAR)
    RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState) WITH SETERROR
    PRINT '-- -- >> ERROR CAUGHT: Number : ' +  isnull(@ErrorNo,'0') + ' , Line: ' + isnull(@ErrorLine,'0') + ' , Exec/Proc: ' + isnull(@ExecLine,@PROCName)
    PRINT '-- -- >> Error Message: ' + isnull(@ErrorMessage,'')
END CATCH
IF @@ERROR <> 0
    SET @Rollback = 1
IF @Rollback = 1
BEGIN
    PRINT '-- -- >> ERROR: Transaction ROLLBACK'
    PRINT '--' + REPLICATE('X',999) + CHAR(13) + CHAR(10) + REPLICATE('X',999) + CHAR(13) + CHAR(10) + REPLICATE('X',999)
    ROLLBACK TRANSACTION T1
END
ELSE
    COMMIT TRANSACTION T1
GOTO END_ALL
------------------------------------ <<< USAGE INFORMATION >>> ------------------------------------
USAGE_INFO:
    Print '-- Cannot Get Usage Information for : [' + @PROCName + ']'
GOTO END_ALL
---------------------------------- <<< END USAGE INFORMATION >>> ----------------------------------
END_ALL:
RETURN
