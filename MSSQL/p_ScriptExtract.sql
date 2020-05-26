ALTER PROCEDURE [dbo].[p_ScriptExtract] (
    @Parameters VARCHAR(100) = '[ALL]'
)
AS
DECLARE @Version VARCHAR(50) = '5.3.0000'
-----------------------------------------------------------------------------------------------------
-- Object    : [dbo].[p_BLD_Extract_DAT]
-- Created   : 2019-08-30
-- Author    : Martin Scheepers
-- Purpose   : Create a Batch File that will use SQLCMD to Extract All Objects to Scripts in a Specified Directory Structure
-- Version   : 5.3.000
-----------------------------------------------------------------------------------------------------
-- Changes   :
-----------------------------------------------------------------------------------------------------
/*
EXEC [dbo].[p_ScriptExtract] @Parameters = '?'
EXEC [dbo].[p_ScriptExtract] @Parameters = '[ALL]'
EXEC [dbo].[p_ScriptExtract] @Parameters = '[SVW][SSP][SFN][STR][SIX][SSN]'
*/
----------------------------------------------------------------------------------------------------
SET NOCOUNT ON
----------------------------------------------------------------------------------------------------
DECLARE @Rollback BIT = 0
BEGIN TRY
    DECLARE @AsAtDate VARCHAR(10)= Convert(VARCHAR(10),GETDATE(),120)
    IF @Parameters = '?' OR @Parameters = ''
    BEGIN
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- PROCEDURE        : [p_BLD_Extract_DAT]'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Purpose          : Create a Batch File that will use SQLCMD to Extract All Objects to Scripts in a Specified Directory Structure'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Input Paramaters  :'
        PRINT '--     @Paramaters   :'
        PRINT '--                    ** Functional Paramters **'
        PRINT '--                    [ALL]  -- ALL Objects (default)'
        PRINT '--                    [EXH]  -- Exclude DOS Batch File Header and Variables Declaration - in case you call this proc from Data and Merge Both Extracts into one File'
          PRINT '--                    ** SQL Object Paramters **'
        --PRINT '--                    [STB]  -- SQL Tables and Triggers'
        PRINT '--                    [SVW]  -- SQL Views'
        PRINT '--                    [SSP]  -- SQL Procedures'
        PRINT '--                    [SFN]  -- SQL Functions'
        PRINT '--                    [STR]  -- SQL Triggers - Should be Part of Tables'
        PRINT '--                    [SIX]  -- SQL Indexes'
        PRINT '--                    [SSN]  -- SQL Synonyms'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Sample Execute Statment:'
        PRINT '--     EXEC [vts].[p_BLD_Extract_DAT] ''[ALL]'''
        PRINT '--     EXEC [vts].[p_BLD_Extract_DAT] ''[SSP]'''
        PRINT '----------------------------------------------------------------------------------------------------'
        RETURN
    END
    ----------------------------- << Define and Set Parameter Variables >> -----------------------------
    IF isnull(@Parameters,'') = '' SET @Parameters = '[ALL]'
    DECLARE @ALL TINYINT = 0, @EXH TINYINT = 0
    IF @Parameters LIKE '%ALL%' SET @ALL = 1
  
    DECLARE @STB TINYINT = @ALL, @SVW TINYINT = @ALL, @SSP TINYINT = @ALL, @SFN TINYINT = @ALL
    DECLARE @STR TINYINT = @ALL, @SIX TINYINT = @ALL, @SSN TINYINT = @ALL
    ---------------------------------------------
    IF @Parameters LIKE '%EXH%' SET @EXH  = 1
    IF @Parameters LIKE '%STB%' SET @STB  = 1
    IF @Parameters LIKE '%SVW%' SET @SVW  = 1
    IF @Parameters LIKE '%SSP%' SET @SSP  = 1
    IF @Parameters LIKE '%SFN%' SET @SFN  = 1
    IF @Parameters LIKE '%STR%' SET @STR  = 1
    IF @Parameters LIKE '%SIX%' SET @SIX  = 1
    IF @Parameters LIKE '%SSN%' SET @SSN  = 1
    ----------------------------------------------------------------------------------------------------
    DECLARE @TargetSRV NVARCHAR(255) = @@SERVERNAME
    DECLARE @TargetDB NVARCHAR(255) = DB_NAME()
    ----------------------------------------------------------------------------------------------------
    ----------------------------- << Load Defintions For Objects to be Scripted out >> -----------------
    ----------------------------------------------------------------------------------------------------
    DECLARE @ObjectDefinitions TABLE (
        ID INT IDENTITY , ObjectType VARCHAR(10), ObjectClass VARCHAR(10), Parameter VARCHAR(10), SeqNo VARCHAR(10), outEnabled SMALLINT
        , objMessage VARCHAR(200), SQLCMD VARCHAR(2000), outPath VARCHAR(2000), SQLExtract VARCHAR(8000))
    
    DECLARE @SQLCMD_SOBJ VARCHAR(2000)
    DECLARE @SQLCMD_SDAT VARCHAR(2000)
    DECLARE @DOS_MKDIR VARCHAR(2000)
    SET @SQLCMD_SOBJ = '%SQEC% -Q "EXEC [dbo].[p_ScriptObject] ''@@Object@@'',''[PRINT][DEL][CRE][NOEXE][NOCMD][NOHINT]'' " -y 0 -o "@@Dir@@\@@FileName@@.sql"'
    SET @SQLCMD_SDAT = '%SQEC% -Q "EXEC [dbo].[p_ScriptData] ''@@Object@@'',''@@Crit@@'',''[PRINT][DEL][INS][UA]'','''','''' " -y 0 -o "@@Dir@@\@@FileName@@.sql"'
    SET @DOS_MKDIR = 'if not exist "@@Dir@@" mkdir "@@Dir@@"'
	---------------------------------------------
    INSERT INTO @ObjectDefinitions (ObjectClass, ObjectType, Parameter, SeqNo, outEnabled, objMessage, outPath, SQLCMD)
    SELECT '0', '0', 'NON', '0', 0, 'Header', '', ''
    ---------------------------------------------
    ------------------- << [p_BLD_SOBJ_Get] is Used for these Objects >> -------------------------
    UNION ALL SELECT 'SD', '90', 'STB',  '200', @STB,  'SQL Tables and Triggers',                  '%TRG%%CMP%\Tables'       , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '91', 'SVW',  '205', @SVW,  'SQL Views',                                '%TRG%%CMP%\Views'        , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '92', 'SSP',  '210', @SSP,  'SQL Procedures',                           '%TRG%%CMP%\Procedures'   , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '93', 'SFN',  '215', @SFN,  'SQL Functions',                            '%TRG%%CMP%\Functions'    , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '94', 'STR',  '220', @STR,  'SQL Triggers',                             '%TRG%%CMP%\Triggers'     , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '95', 'SIX',  '225', @SIX,  'SQL Indexes',                              '%TRG%%CMP%\Indexes'      , @SQLCMD_SOBJ
    UNION ALL SELECT 'SD', '96', 'SSN',  '230', @SSN,  'SQL Synonyms',                             '%TRG%%CMP%\Synonyms'     , @SQLCMD_SOBJ
    ----------------------------------------------------------------------------------------------------------------
    ----------------------------- << Define Batch File and Add SQLCMD Refrenmces for each Object  >> ---------------
    ----------------------------------------------------------------------------------------------------------------
    DECLARE @DOS_BATCH TABLE (ID INT IDENTITY, ReturnData VARCHAR(max), InfoType SMALLINT, TempStore VARCHAR(2000))
    ----------------------------------------------------------------------------------------------------------------
    INSERT INTO @DOS_BATCH (ReturnData)
    SELECT ''
    UNION ALL SELECT '@Echo Off'
    UNION ALL SELECT 'REM Set Source Database Variables'
    UNION ALL SELECT 'REM ---------------------------------'
    UNION ALL SELECT 'SET "SSRV=' + ISNULL(@TargetSRV,'') + '"'
    UNION ALL SELECT 'SET "SDBD=' + ISNULL(@TargetDB,'') + '"'
    UNION ALL SELECT 'REM ---------------------------------'
    UNION ALL SELECT 'SET "SRCD=%~dp0"'
    UNION ALL SELECT 'SET "MEF=%~n0"'
    UNION ALL SELECT 'SET "TRG=%SRCD%"'
    UNION ALL SELECT 'SET "CMP=' + '1000' + '"'
    UNION ALL SELECT 'Echo --------------------------------------------------------------------------'
    UNION ALL SELECT 'Echo Local Target Directory:'
    UNION ALL SELECT 'Echo %TRG%%CMP%'
    UNION ALL SELECT 'Echo --------------------------------------------------------------------------'
    UNION ALL SELECT 'Echo Source SQL Server:-           %SSRV%'
    UNION ALL SELECT 'Echo Source SQL Data Database  :-  %SDBD%'
    UNION ALL SELECT 'Echo --------------------------------------------------------------------------'
    UNION ALL SELECT 'Echo --- Press {CTRL-C} to Cancel OR '
    UNION ALL SELECT 'PAUSE'
    UNION ALL SELECT 'REM SET SQL CMD VARIABLES'
    UNION ALL SELECT 'REM ---------------------'
    UNION ALL SELECT 'SET "SQEC=SQLCMD -S %SSRV% -d %SDBD% -U Batsumi_User -P GGGGGGGG"'
    UNION ALL SELECT 'SET "vPERv=%%"'
    --Delete the Header if the Flag has been set
    DELETE FROM @DOS_BATCH WHERE @EXH = 1
    --Add Reference to Database
    INSERT INTO @DOS_BATCH (ReturnData)
    SELECT ''
    UNION ALL SELECT 'Echo --------------------------------------------------------------------------'
    UNION ALL SELECT 'Echo EXTRACTING Files From %SDBD% Database Using SQLCMD.'
    UNION ALL SELECT 'Echo --------------------------------------------------------------------------'
    --Add MkDir For All Enabled Directories
    INSERT INTO @DOS_BATCH (ReturnData,TempStore)
    SELECT DISTINCT REPLACE(@DOS_MKDIR,'@@Dir@@',OBJ.outPath),'0'
    FROM @ObjectDefinitions OBJ
    WHERE outEnabled = 1
    INSERT INTO @DOS_BATCH (ReturnData)
    SELECT ''
    UNION ALL SELECT 'REM --------------------------------'
    ----------------------------------------------------------------------------------------------------------------
    ------------------- << [p_BLD_SOBJ_Get] is Used for these Objects >> -------------------------
    INSERT INTO @DOS_BATCH (ReturnData,TempStore)
    SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(OBJ.SQLCMD,'@@ObjType@@',OBJ.ObjectType),'@@Object@@',VI.ObjectID),'@@Dir@@',OBJ.outPath),'@@crit@@',VI.ObjectCrit),'@@FileName@@'
	    , REPLACE(ObjectFile,'*', LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(VI.ObjectID,'/','_'),'\','_'),':',''),'*',''),'>',''),'<',''),'?',''),'"',''),'|',''),'[',''),']',''))))) AS SQLCMD
        , OBJ.SeqNo + ObjectOrder + OBJ.Parameter + VI.ObjectID AS TEMPStore
    FROM @ObjectDefinitions OBJ
    INNER JOIN (
    SELECT '0' AS ObjectType, '' as ObjectID, '' AS ObjectFile , '' AS ObjectOrder ,'' AS ObjectCrit
    ---------------------------
    UNION ALL SELECT DISTINCT 'STB' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '100' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('U')
    UNION ALL SELECT DISTINCT 'SVW' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '110' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('V')
    UNION ALL SELECT DISTINCT 'SSP' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '120' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('P')
    UNION ALL SELECT DISTINCT 'SFN' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '130' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('FN','IF','TF')
    UNION ALL SELECT DISTINCT 'STR' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '140' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('TR')
    UNION ALL SELECT DISTINCT 'SSN' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SRC.schema_id))) + '.' + QUOTENAME(SRC.name), '*' , '150' ,'' FROM [sys].[all_objects] SRC WITH (NOLOCK) INNER JOIN sys.schemas SS ON SS.schema_id = SRC.schema_id WHERE SRC.is_ms_shipped = 0 AND SRC.Type IN ('SN')
    UNION ALL SELECT DISTINCT 'SIX' , QUOTENAME(ISNULL(SS.name,OBJECT_NAME(SO.schema_id)))  + '.' + QUOTENAME(SRC.name), '*' , '160' ,'' FROM [sys].[indexes] SRC WITH (NOLOCK) INNER JOIN [sys].[all_objects] SO ON SO.object_id = SRC.object_id AND SO.is_ms_shipped = 0 AND SO.type in (N'U') INNER JOIN sys.schemas SS ON SS.schema_id = SO.schema_id
    WHERE SRC.type = 2
    ) VI ON VI.ObjectType = OBJ.Parameter
    WHERE outEnabled = 1 AND ObjectClass = 'SD'
    ORDER BY OBJ.SeqNo, ObjectOrder, OBJ.Parameter, VI.ObjectID
    ----------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------
    UPDATE @DOS_BATCH SET ReturnData = '-- -- >> ERROR: NULL Data Was Passed.' + REPLICATE('X',100) WHERE ReturnData IS NULL
    SELECT ReturnData as [--ReturnData] From @DOS_BATCH order by id
    RETURN
END TRY
---------------------------------------------------------------------------------------------------
-- Check If Error Has Been Caught by TRY METHOD
BEGIN CATCH
    SET @Rollback = 1
    DECLARE @ErrorMessage NVARCHAR(2000),@ErrorSeverity INT,@ErrorState INT,@ErrorNo VARCHAR(10), @ErrorLine VARCHAR(10)
    SELECT @ErrorMessage = ERROR_MESSAGE(),@ErrorSeverity = ERROR_SEVERITY(),@ErrorState = ERROR_STATE()
        ,@ErrorNo = CAST(ERROR_NUMBER() AS VARCHAR) ,@ErrorLine = CAST(ERROR_LINE() AS VARCHAR)
    RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState) WITH SETERROR
    --PRINT '-- -- >> ERROR CAUGHT: Number : ' +  isnull(@ErrorNo,'0') + ' , Line: ' + isnull(@ErrorLine,'0') + ' , Exec/Proc: ' + isnull(@ExecLine,@PROCName)
    PRINT '-- -- >> Error Message: ' + isnull(@ErrorMessage,'')
END CATCH
IF @Rollback = 1
BEGIN
    PRINT '-- -- >> ERROR: Cerain criteria may not be met to complete successfully. Please see Additional Information or Show Help ? : ' + @AsAtDate
    PRINT '-- -- >>' + REPLICATE('X',100) + CHAR(13) + CHAR(10) + REPLICATE('X',100) + CHAR(13) + CHAR(10) + REPLICATE('X',100)
END
RETURN