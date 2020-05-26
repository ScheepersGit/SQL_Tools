CREATE PROCEDURE [dbo].[p_ScriptObject] (
     @ObjectName VARCHAR(200)
    , @Parameters VARCHAR(100) = '[SELECT][DEL][CRE]'
    )
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : [dbo].p_BLD_SOBJ_Get
-- DateTime       : 2014-09-16
-- Author         : Martin Scheepers
-- Purpose        : Script out SQL Object From Database
-- Ver            : 2.0
----------------------------------------------------------------------------------------------------
-- Changes        : 
----------------------------------------------------------------------------------------------------
/*
EXEC [dbo].[p_ScriptObject] '[dbo].[p_ScriptObject]', '[TFS]'
EXEC [dbo].[p_ScriptObject] '[dbo].[p_ScriptData]', '[SELECT][ALT]'
*/
-- Supported
--------------
--('FN','IF','P','TF','TR','V','SN')
--FN    SQL_SCALAR_FUNCTION
--IF    SQL_INLINE_TABLE_VALUED_FUNCTION
--P     SQL_STORED_PROCEDURE
--TF    SQL_TABLE_VALUED_FUNCTION
--TR    SQL_TRIGGER
--V     VIEW
--SN    SYNONYM
--Unsupported:
--------------
--('AF','C','D','F','FS','FT','IT','PC','PG','PK','R','RF','S','SN','SQ','TA','U','UQ','X')
--AF    AGGREGATE_FUNCTION
--C     CHECK_CONSTRAINT
--D     DEFAULT_CONSTRAINT
--F     FOREIGN_KEY_CONSTRAINT
--FS    CLR_SCALAR_FUNCTION
--FT    CLR_TABLE_VALUED_FUNCTION
--IT    INTERNAL_TABLE
--PC    CLR_STORED_PROCEDURE
--PG    PLAN_GUIDE
--PK    PRIMARY_KEY_CONSTRAINT
--R     RULE
--RF    REPLICATION_FILTER_PROCEDURE
--S     SYSTEM_TABLE
--SQ    SERVICE_QUEUE
--TA    CLR_TRIGGER
--U     USER_TABLE - WIP
--UQ    UNIQUE_CONSTRAINT
--X     EXTENDED_STORED_PROCEDURE
----------------------------------------------------------------------------------------------------
SET NOCOUNT ON
----------------------------------------------------------------------------------------------------
BEGIN TRY
    IF @ObjectName = '?' OR @ObjectName = '' OR @Parameters = '?' OR @Parameters = ''
    BEGIN
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- PROCEDURE        : [p_BLD_SOBJ_Get]'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Purpose          : Script Out SQL Object From a Database'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Input Paramaters :'
        PRINT '--     @ObjectName  : Source Object Name - Supports Qualified Table Name including Schema and Database, if no Schema Assume its dbo'
        PRINT '--     @Paramaters  : [SELECT] : (Default) Will output Results to RecordSet'
        PRINT '--                    [PRINT]  : Will output Results to Message'
        PRINT '--                    [DEL]    : (Default) Include DROP Object'
        PRINT '--                    [CRE]    : (Default) Generate as CREATE Object'
        PRINT '--                    [ALT]    : Generate as ALTER Object'
        PRINT '--                    [WSR]    : Remove Whitespace Lines From output'
        PRINT '--                    [GCR]    : Remove GreenCode (Comment) Lines From output'
        PRINT '--                    [CBR]    : Remove Comment Blocks From output'
        PRINT '--                    [TBR]    : Remove Title Block From output'
        PRINT '--                    [NOEXE]  : Exclude Execution line'
        PRINT '--                    [NOCMD]  : Exclude SQLcmd Line'
        PRINT '--                    [EXTP]   : Included Extended Properties'
        PRINT '--                    [NOHINT] : Include ANSI and QUOTED Hints - 1 = Hide the set ansis etc., 0 = show'
        PRINT '--                    [REPL]   : Replace String in SQL Object - Pipe Delimited eg. [REPL:Findme|ReplaceWith]'
        PRINT '--                    [COMP]   : Build Up a Comparable String, Includes WSR, GCR, CBR Leaving RAW Code'
        PRINT '--                    [TFS]    : Team Foundation Source Control Script'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Sample Execute Statment:'
        PRINT '--     EXEC [dbo].[p_ScriptObject] ''[SQLDatabase].[Schema].[SQL_Object]'',''[SELECT][DEL][CRE]'''
        PRINT '----------------------------------------------------------------------------------------------------'
        RETURN
    END
    ----------------------------------------------------------------------------------------------------
    DECLARE @Rollback BIT   = 0 -- 1 = ROLLBACK TRAN, 0 =  COMMIT TRAN.
    DECLARE @AsAtDate VARCHAR(10)  = Convert(VARCHAR(10),GETDATE(),120)
    DECLARE @PROCName VARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'NONAME')
	DECLARE @TargetType NVARCHAR(10) = ''
    --1.8 Parse Object Name to Get All Target Objects
    DECLARE @ThisSRV NVARCHAR(255) = @@SERVERNAME
    DECLARE @ThisDB NVARCHAR(255) = DB_NAME() 
	DECLARE @ThisSchema NVARCHAR(255) = 'dbo' --SCHEMA_NAME()
    DECLARE @TargetSRV NVARCHAR(255) = @@SERVERNAME
    DECLARE @TargetDB NVARCHAR(255) = DB_NAME() 
    DECLARE @TargetSchema NVARCHAR(255) = 'dbo' --SCHEMA_NAME()
    DECLARE @TargetObject VARCHAR(255) = @ObjectName
    SET @TargetObject = LTRIM(RTRIM(REPLACE(REPLACE(@TargetObject,']',''),'[','')))
    SET @TargetSRV = ISNULL(PARSENAME(@ObjectName, 4),@TargetSRV)
    SET @TargetDB = ISNULL(PARSENAME(@ObjectName, 3),@TargetDB)
    SET @TargetSchema = ISNULL(PARSENAME(@ObjectName, 2),@TargetSchema)
    SET @TargetObject = ISNULL(PARSENAME(@ObjectName, 1),@TargetObject)
    ----------------------------- << Define and Set Parameter Variables >> -----------------------------
    DECLARE @DEBUG TINYINT = 0, @PRINT TINYINT = 0, @SELECT TINYINT = 0
    DECLARE @ALT TINYINT = 0, @CRE TINYINT = 0, @DEL TINYINT = 0
    DECLARE @WSR TINYINT = 0, @GCR TINYINT = 0, @TBR TINYINT = 0 , @CBR TINYINT = 0
    DECLARE @NOEXE TINYINT = 0, @NOCMD TINYINT = 0, @EXTP TINYINT = 0
	DECLARE @REPL TINYINT = 0, @NOHINT TINYINT = 0, @COMP TINYINT = 0, @TFS TINYINT = 0
	---------------------------------------------
    IF isnull(@Parameters,'') = '' SET @Parameters = '[SELECT][DEL][CRE]'
    SET @Parameters = @Parameters + '[NOCMD]'
	IF @Parameters LIKE '%COMP%'   SET @COMP   = 1 -- Build up comparable String
	IF @COMP = 1 SET @Parameters = '[PRINT][ALT][WSR][GCR][CBR][TBR][NOEXE][NOCMD][NOHINT]'
	IF @Parameters LIKE '%TFS%'   SET @TFS   = 1 -- Source Safe Compatable Alter Script
	IF @TFS = 1 SET @Parameters = '[SELECT][CRE][NOEXE][NOCMD][NOHINT]'
    IF @Parameters LIKE '%DEBUG%'  SET @DEBUG  = 1 -- Debug mode for output
    IF @Parameters LIKE '%PRINT%'  SET @PRINT  = 1 -- Output Result in PRINT
    IF @Parameters LIKE '%SELECT%' SET @SELECT = 1 -- Output Result in SELECT Grid
    IF @Parameters LIKE '%ALT%'    SET @ALT    = 1 -- Output Result as ALTER
    IF @Parameters LIKE '%CRE%'    SET @CRE    = 1 -- Output Result as DROP AND CREATE
    IF @Parameters LIKE '%DEL%'    SET @DEL    = 1 -- Output Result as DROP Only
    IF @Parameters LIKE '%WSR%'    SET @WSR    = 1 -- Remove Whitespace Lines From output
    IF @Parameters LIKE '%GCR%'    SET @GCR    = 1 -- Remove GreenCode (Comment) Lines From output
    IF @Parameters LIKE '%CBR%'    SET @CBR    = 1 -- Remove Comment Blocks (Titles) Lines From output
    IF @Parameters LIKE '%TBR%'    SET @TBR    = 1 -- Remove TitleBlock From output
    IF @Parameters LIKE '%NOEXE%'  SET @NOEXE  = 1 -- Exclude Execution line
    IF @Parameters LIKE '%NOCMD%'  SET @NOCMD  = 1 -- Exclude SQLcmd Line
    IF @Parameters LIKE '%EXTP%'   SET @EXTP   = 1 -- Included Extended Properties
	IF @Parameters LIKE '%NOHINT%' SET @NOHINT = 1 -- Include ANSI and QUOTED Hints - 1 = Hide the set ansis etc., 0 = show
    IF @Parameters LIKE '%REPL%'   SET @REPL   = 1 -- Replace String in SQL Object - Pipe Delimited eg. [REPL:Findme|ReplaceWith]
    ------------------- << SET Variable Defaults to Eliminate Conflicting Options >> -------------------
    IF @PRINT = 0 AND @SELECT = 0 SET @SELECT = 1
    IF @SELECT = 1 SET @PRINT = 0
    IF @DEBUG = 1 SET @PRINT = 1
    IF @PRINT = 1 SET @SELECT = 0
    IF @ALT = 1 AND @CRE = 1 SET @ALT = 0
    IF @ALT = 0 AND @CRE = 0 AND @DEL = 0 SET @CRE = 1
    IF @CRE = 1 SET @ALT = 0
	 --------------------------------- << DECLARE Exec Line For Proc >> --------------------------------
    DECLARE @SQLEXE VARCHAR(MAX)
    DECLARE @ExecLine VARCHAR(MAX)
    SET @SQLEXE = 'EXEC ' + QUOTENAME(@ThisSchema) + '.' + QUOTENAME(@PROCName) + ' ' + '''' +
			QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetObject) + '''' +
			',' + '''' + Replace(isnull(@Parameters,''),'''','''''') + '''' 
    SET @ExecLine = '-- ' + @SQLEXE
	----------------------------- << Depenedancy and Limitation Checks  >> -----------------------------
    IF @TargetSRV <> @ThisSRV
    BEGIN
        PRINT '-- -- >> ERROR: Object Definition Cannot be Derived for Different Server: [' + @TargetSRV + '].[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
        SET @Rollback = 1
    END
	IF @TargetDB <> @ThisDB
    BEGIN
        PRINT '-- -- >> ERROR: Object Definition Cannot be Derived for Different Database: [' + @TargetSRV + '].[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
        SET @Rollback = 1
    END
    IF ISNULL(OBJECT_ID('[dbo].[tf_DelimitedRecordSet]'),'') = '' 
    BEGIN
        PRINT '-- -- >> ERROR: Required Object Does Not Exist : [dbo].[tf_DelimitedRecordSet] : ' + @AsAtDate
        SET @Rollback = 1
    END
    IF ISNULL(OBJECT_ID('[dbo].[fn_StrBetween]'),'') = '' 
    BEGIN
        PRINT '-- -- >> ERROR: Required Object Does Not Exist : [dbo].[fn_StrBetween] : ' + @AsAtDate
        SET @Rollback = 1
    END
	IF ISNULL(OBJECT_ID('[dbo].[fn_StripSQLComments]'),'') = '' AND @GCR = 1
    BEGIN
        PRINT '-- -- >> ERROR: Required Object Does Not Exist : [dbo].[fn_StripSQLComments] : ' + @AsAtDate
        SET @Rollback = 1
    END
    -------------------------------------- >>> BEGIN PROCESS >>> --------------------------------------
    IF @Rollback = 0
    BEGIN
        --------------------------------------------- 
        -- Replace Ability Vaiables
        DECLARE @FindMe VARCHAR(255) = ''
        DECLARE @ReplaceWith VARCHAR(255) = ''
        IF @REPL = 1
        BEGIN
			SET @FindMe = dbo.fn_StrBetween(@Parameters,'REPL:',']',0,CONVERT(VARCHAR(255),@FindMe))
			SET @ReplaceWith = dbo.fn_StrBetween(@FindMe,'|',NULL,0,CONVERT(VARCHAR(10),@ReplaceWith))
			SET @FindMe = dbo.fn_StrBetween(@FindMe,NULL,'|',0,CONVERT(VARCHAR(255),@FindMe))
			IF ISNULL(@FindMe,'') = '' SET @FindMe = ''
			IF ISNULL(@ReplaceWith,'') = '' SET @ReplaceWith = ''
        END 
        ------------------------- << Declare and Create Variable OUTPUT Tables >> -------------------------
        DECLARE @OUT_RETURN TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        DECLARE @OUT_TEMP TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT, rOrder INT)
        ------------------------- << Declare Global Variables for General Use >> ----------------------------
        DECLARE @SQLCMD VARCHAR(MAX)
        DECLARE @TAB VARCHAR(2) = CHAR(9), @CR VARCHAR(2) = CHAR(13) , @LF VARCHAR(2) = CHAR(10)
        DECLARE @CRLF VARCHAR(2) , @Token VARCHAR(10)
        SET @CRLF = @CR + @LF
        SET @Token = '!' + CHAR(67) + CHAR(82) + CHAR(76) + CHAR(70) + '!'
		--SET @SQLCMD = 'SQLCMD -S ' + @TargetSRV + ' -d ' + @TargetDB + ' -Q "' + @SQLEXE + '" -y 0 -o ".\' + @TargetObject + '.sql"'
        SET @SQLEXE = '-- ------- >> SQL Execution : -- ' + @SQLEXE
        SET @SQLCMD = '-- ------- >> SQLcmd Command: -- ' + @SQLCMD
        -- Pass Execution lines to output
        INSERT INTO @OUT_RETURN (ReturnData) SELECT @SQLEXE WHERE @NOEXE = 0
        INSERT INTO @OUT_RETURN (ReturnData) SELECT @SQLCMD WHERE @NOCMD = 0
        -------------------------------------- << Check to See if Object Exists and is Supported >> --------
        SET @TargetType = ''
        DECLARE @SQL_Params NVARCHAR(4000)
        DECLARE @SQL_Exec NVARCHAR(4000)
        SET @SQL_Params = N'@OUTType VARCHAR(10) OUTPUT'
        SET @SQL_Exec =N'SELECT TOP 1 @OUTType = SO.type 
        FROM [' + @TargetDB + '].[sys].[all_objects] SO WITH (NOLOCK) 
        WHERE SO.object_id = OBJECT_ID(N''[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + ']'')'
        IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
        EXECUTE sp_executesql @SQL_Exec, @SQL_params, @OUTType = @TargetType OUTPUT
        SET @TargetType = LTRIM(RTRIM(@TargetType))
        --------------------------------------
        IF ISNULL(@TargetType,'') IN ('AF','C','D','F','FS','FT','IT','PC','PG','PK','R','RF','S','SQ','TA','UQ','X') --,'U')
        BEGIN
            PRINT '-- -- >> ERROR: Object Type (' + ISNULL(@TargetType,'') + ') is Not Supported : [' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
            SET @Rollback = 1
        END
        IF ISNULL(@TargetType,'') = ''
        BEGIN
            SET @SQL_Exec =N''
            SET @SQL_Exec =N'IF EXISTS(SELECT TOP 1 SI.name 
            FROM [' + @TargetDB + '].[sys].[indexes] SI WITH (NOLOCK) 
            WHERE SI.name = ''' + @TargetObject + ''') SET @OUTType = ''IDX'''
            IF @DEBUG = 1 PRINT @SQL_Exec
            EXECUTE sp_executesql @SQL_Exec, @SQL_params, @OUTType = @TargetType OUTPUT
            SET @TargetType = LTRIM(RTRIM(@TargetType))
        END
        IF ISNULL(@TargetType,'') = ''
        BEGIN
            PRINT '-- -- >> ERROR: Object Type Cannot be Derived or Object does not Exist: [' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
            SET @Rollback = 1
        END
        IF @Rollback = 0
        BEGIN
            -------------------------------------- << Get Defintion if Type is Supported >> --------------------
            DECLARE @TargetDefinitionText VARCHAR(MAX) = ''
            IF ISNULL(@TargetType,'') IN ('FN','IF','P','TF','TR','V','SN')
            BEGIN
                SET @SQL_Params = N'@Definition VARCHAR(MAX) OUTPUT'
                SET @SQL_Exec = N'SELECT TOP 1 @Definition = '
                    SELECT @SQL_Exec = @SQL_Exec + '
                    CASE WHEN COALESCE(SM.uses_ansi_nulls, SSM.uses_ansi_nulls,'''') = 1 THEN ''SET ANSI_NULLS ON'' + CHAR(13) + CHAR(10) + ''GO ''
                        WHEN COALESCE(SM.uses_ansi_nulls, SSM.uses_ansi_nulls,'''') = 0 THEN ''SET ANSI_NULLS OFF'' + CHAR(13) + CHAR(10) + ''GO ''
                        ELSE '''' END + CHAR(13) + CHAR(10) +
                    CASE WHEN COALESCE(SM.uses_quoted_identifier, SSM.uses_quoted_identifier,'''') = 1 THEN ''SET QUOTED_IDENTIFIER ON'' + CHAR(13) + CHAR(10) + ''GO ''
                        WHEN COALESCE(SM.uses_quoted_identifier, SSM.uses_quoted_identifier,'''') = 0 THEN ''SET QUOTED_IDENTIFIER OFF'' + CHAR(13) + CHAR(10) + ''GO ''
                        ELSE '''' END + CHAR(13) + CHAR(10) + ' WHERE @NOHINT = 0
                    SET @SQL_Exec = @SQL_Exec + '
                    CASE 
                        WHEN LTRIM(RTRIM(SO.[Type])) = ''SN'' THEN ''CREATE SYNONYM ['' + SS.[name]  + ''].['' + SN.[name] + ''] FOR '' + SN.[base_object_name]
                        ELSE COALESCE(SM.DEFINITION, SSM.DEFINITION,'''')
                    END
                FROM [' + @TargetDB + '].[sys].[all_objects] SO WITH (NOLOCK)
                INNER JOIN [' + @TargetDB + '].[sys].[schemas] SS WITH (NOLOCK) ON SS.schema_id = SO.schema_id AND SS.name = ''' + @TargetSchema + '''
                LEFT JOIN [' + @TargetDB + '].[sys].[sql_modules] SM WITH (NOLOCK) ON SM.object_id = SO.object_id
                LEFT JOIN [' + @TargetDB + '].[sys].[system_sql_modules] SSM WITH (NOLOCK) ON SSM.object_id = SO.object_id
                LEFT JOIN [' + @TargetDB + '].[sys].[synonyms] SN WITH (NOLOCK) ON SO.[schema_id] = SN.[schema_id] AND SO.[object_id] = SN.[object_id]
                WHERE SO.object_id = OBJECT_ID(''[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + ']'',N''' + @TargetType + ''')'
                IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
                EXECUTE sp_executesql @SQL_Exec, @SQL_params, @Definition = @TargetDefinitionText OUTPUT
            END
			--------------------------------------
			IF ISNULL(@TargetType,'') IN ('U')
            BEGIN
				DECLARE @TABLE_SRC TABLE (ID INT IDENTITY,TABLE_NAME NVARCHAR(128), COLUMN_NAME NVARCHAR(128), ORDINAL_POSITION SMALLINT, DATA_TYPE NVARCHAR(128)
				, CHARACTER_MAXIMUM_LENGTH INT, NUMERIC_PRECISION TINYINT, NUMERIC_SCALE SMALLINT, COLUMN_DEFAULT NVARCHAR(4000), IS_NULLABLE NVARCHAR(3)
				, IS_PRIMARY BIT, PK_ORD SMALLINT, PK_DESC TINYINT, PK_FILL SMALLINT
				, SEED_OBJECTID INT, SEED_VALUE SQL_VARIANT, SEED_INCREMENT SQL_VARIANT, CALC_OBJECTID INT, CALC_PERSISTED BIT
				, CALC_DEFINITION NVARCHAR(MAX), DEF_DATATYPE NVARCHAR(MAX), R_ACTION VARCHAR(15), DEF_DEFINTION VARCHAR(4000)
				, LEN_COL INT, LEN_TYPE INT, LENM_COL INT, LENM_TYPE INT
				)
				-- Insert Table Definition into Temp Table From SQL View
				INSERT INTO @TABLE_SRC
				(TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT
				, IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, PK_FILL, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE)
				SELECT
				TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_DEFAULT
				, IS_NULLABLE, IS_PRIMARY, PK_ORD, PK_DESC, PK_FILL, SEED_OBJECTID, SEED_VALUE, SEED_INCREMENT, CALC_OBJECTID, CALC_PERSISTED, CALC_DEFINITION, DEF_DATATYPE
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
					, CASE WHEN isnull([SI].is_primary_key,0) = 1 AND isnull([SI].fill_factor, 0) <> 0 THEN [SI].fill_factor ELSE 0 END AS PK_FILL
					, isnull([SID].object_id,0) AS SEED_OBJECTID
					, isnull([SID].seed_value,0) AS SEED_VALUE
					, isnull([SID].increment_value,0) AS SEED_INCREMENT  
					, isnull([SCC].object_id,0) AS CALC_OBJECTID
					, isnull([SCC].is_persisted,0) AS CALC_PERSISTED
					, isnull([SCC].[definition],0) AS CALC_DEFINITION
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
					ON OBJECT_ID(QUOTENAME([ST].TABLE_SCHEMA) + '.' + QUOTENAME([ST].TABLE_NAME)) = SI.object_id AND SI.is_primary_key = 1
						LEFT JOIN sys.index_columns [SIC] WITH (NOLOCK,READUNCOMMITTED) 
					ON SI.object_id = SIC.object_id AND SI.index_id = SIC.index_id AND [COL].COLUMN_NAME = COL_NAME(SIC.object_id,SIC.column_id)
						LEFT JOIN sys.identity_columns [SID] WITH (NOLOCK,READUNCOMMITTED) 
					ON OBJECT_ID(QUOTENAME([ST].TABLE_SCHEMA) + '.' + QUOTENAME([ST].TABLE_NAME)) = SID.object_id AND [COL].COLUMN_NAME = COL_NAME(SID.object_id,SID.column_id)
						LEFT JOIN sys.computed_columns [SCC] WITH (NOLOCK,READUNCOMMITTED) 
					ON OBJECT_ID(QUOTENAME([ST].TABLE_SCHEMA) + '.' + QUOTENAME([ST].TABLE_NAME)) = SCC.object_id AND [COL].COLUMN_NAME = COL_NAME(SCC.object_id,SCC.column_id)
					WHERE [ST].[TABLE_NAME] = @TargetObject AND [ST].TABLE_SCHEMA = @TargetSchema ) v_BLD_STBL_Get
					ORDER BY ORDINAL_POSITION

					UPDATE @TABLE_SRC SET DEF_DEFINTION = ' CONSTRAINT [DF_' + ISNULL(TABLE_NAME,'') + '_' + ISNULL(COLUMN_NAME,'') + '] DEFAULT ' + ISNULL(COLUMN_DEFAULT,'') + ''
					WHERE  ISNULL(COLUMN_DEFAULT,'') <> ''
					--Pad the Fields
					UPDATE @TABLE_SRC SET LEN_COL = LEN(COLUMN_NAME)
					UPDATE @TABLE_SRC SET LEN_TYPE = LEN(DEF_DATATYPE)
					UPDATE @TABLE_SRC SET LENM_COL = (SELECT MAX(LEN_COL) FROM @TABLE_SRC)
					UPDATE @TABLE_SRC SET LENM_TYPE = (SELECT MAX(LEN_TYPE) FROM @TABLE_SRC)
				  -------------------------------------------------------------------------------------------------------------------------------
				  DECLARE @TMP_TRGCREATE TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
				  INSERT INTO @TMP_TRGCREATE (ReturnData)
				  SELECT ''
				  UNION ALL SELECT 'CREATE TABLE [' + @TargetSchema + '].[' + @TargetObject + ']('
				  INSERT INTO @TMP_TRGCREATE (ReturnData)
				  SELECT '    [' + isnull(COLUMN_NAME,'') + '] ' + SPACE((LENM_COL + 2) - LEN_COL) +
				  CASE WHEN isnull(CALC_OBJECTID,0) > 0 THEN ' AS ' + isnull(CALC_DEFINITION, NULL) + '' ELSE isnull(DEF_DATATYPE,'') + SPACE((LENM_TYPE + 2) - LEN_TYPE) + '' +
					 CASE WHEN isnull(SEED_OBJECTID,0) > 0 THEN ' IDENTITY(' + Convert(VARCHAR(max),isnull(SEED_VALUE, 0)) + ',' + Convert(VARCHAR(max),isnull(SEED_INCREMENT, 0)) + ')' ELSE '' END +
					 CASE WHEN ISNULL(COLUMN_DEFAULT,'') = '' THEN '' ELSE DEF_DEFINTION END +
					 CASE isnull(IS_NULLABLE,'0') WHEN '1' THEN ' NULL ' ELSE ' NOT NULL' END
				  END + 
				  ' ,'
				  FROM @TABLE_SRC
				  -------------------------------------------------
				  IF EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY > 0)
				  BEGIN
					 INSERT INTO @TMP_TRGCREATE (ReturnData)
					 SELECT ' CONSTRAINT [PK_' + @TargetObject + '] PRIMARY KEY CLUSTERED '
					 DECLARE @PK VARCHAR(max)
					 SET @PK = '    ('
					 
					 SELECT TOP 10 @PK = @PK + '[' + COLUMN_NAME + '] ' + CASE WHEN ISNULL(PK_DESC,0)=0 THEN 'ASC' Else 'DESC' END + ', '
					 FROM @TABLE_SRC
					 WHERE IS_PRIMARY > 0
					 ORDER BY PK_ORD

					 SET @PK = LEFT(@PK,LEN(@PK)-1) + ')'
					 
					 --TODO: Need to PK Attributes and Add WITH

					 INSERT INTO @TMP_TRGCREATE (ReturnData)
					 SELECT @PK
					 --INSERT INTO @TMP_TRGCREATE (ReturnData)
					 --SELECT ' ON [PRIMARY]'
				  END
				  INSERT INTO @TMP_TRGCREATE (ReturnData)
					 SELECT ')'
					 --UNION ALL SELECT 'ON [PRIMARY]'
					 UNION ALL SELECT ';'
					 UNION ALL SELECT 'GO'
				  -------------------------------------------------------------------------------------------------------------------------------
				  SET @TargetDefinitionText = ''
				  SELECT @TargetDefinitionText = ISNULL(@TargetDefinitionText,'') + ISNULL(ReturnData,'') + ' ' + @CRLF 
				  FROM @TMP_TRGCREATE WHERE ISNULL(REPLACE(ReturnData,' ',''), '') <> '' ORDER BY ID
			END
			--------------------------------------
            IF ISNULL(@TargetType,'') IN ('IDX')
            BEGIN
                DECLARE @TargetParent VARCHAR(255) = ''
                DECLARE @TargetParentType VARCHAR(10) = ''
                SET @SQL_Params = N'@ParentType VARCHAR(10) OUTPUT, @ParentName VARCHAR(255) OUTPUT'
                SET @SQL_Exec = N'SELECT TOP 1 @ParentName = OBJECT_NAME(SI.object_id), @ParentType = SO.type
                FROM [' + @TargetDB + '].[sys].[indexes] SI WITH (NOLOCK) 
                INNER JOIN [' + @TargetDB + '].[sys].[all_objects] SO WITH (NOLOCK) ON SI.object_id = SO.object_id 
                INNER JOIN [' + @TargetDB + '].[sys].[schemas] SS WITH (NOLOCK) ON SS.schema_id = SO.schema_id AND SS.name = ''' + @TargetSchema + '''
                WHERE SI.name = ''' + @TargetObject + ''''
                IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
                EXECUTE sp_executesql @SQL_Exec, @SQL_params, @ParentName = @TargetParent OUTPUT , @ParentType = @TargetParentType OUTPUT
                SET @TargetParent = LTRIM(RTRIM(@TargetParent))
                SET @TargetParentType = LTRIM(RTRIM(@TargetParentType))
                --------------------------------------
                SET @SQL_Params = N'@Definition VARCHAR(MAX) OUTPUT'
                SET @SQL_Exec = N'
				DECLARE @CRLF VARCHAR(20) = CHAR(13)+CHAR(10)
				SELECT TOP 1 
					@Definition = 
					''CREATE ''+CASE WHEN SI.is_unique = 1 THEN '' UNIQUE '' ELSE '''' END+SI.type_desc COLLATE DATABASE_DEFAULT+'' INDEX [''+SI.name+''] ON ['+@TargetSchema+'].[''+SO.name+'']''+@CRLF 
					+ISNULL('' (''+REPLACE(KeyColumns,'' , '', @CRLF+'','')+'' )''+@CRLF, '''') 
					+ISNULL('' INCLUDE (''+@CRLF+REPLACE(IncludedColumns,'' , '', @CRLF+'','')+'' )''+@CRLF,'''') 
					+ISNULL('' WHERE ''+SI.Filter_definition,'''')+'' WITH ( '' 
					'
					SET @SQL_Exec = @SQL_Exec+N'
					+'' SORT_IN_TEMPDB = OFF ''+'','' 
					+'' DROP_EXISTING = OFF ''+'',''
					+'' ONLINE = OFF ''+'',''
					+'' PAD_INDEX = ''+CASE WHEN SI.is_padded = 1 THEN ''ON '' ELSE ''OFF '' END+'',''
					+CASE WHEN SI.Fill_factor = 0 THEN '''' ELSE ''FILLFACTOR = ''+CONVERT(CHAR(5),SI.Fill_factor)+'','' END
					+'' IGNORE_DUP_KEY = ''+CASE WHEN SI.ignore_dup_key = 1 THEN ''ON '' ELSE ''OFF '' END+'',''
					+'' STATISTICS_NORECOMPUTE = ''+CASE WHEN ST.no_recompute = 0 THEN ''OFF '' ELSE ''ON '' END+'',''
					+'' ALLOW_ROW_LOCKS = ''+CASE WHEN SI.allow_row_locks = 1 THEN ''ON '' ELSE ''OFF '' END+'',''
					+'' ALLOW_PAGE_LOCKS = ''+CASE WHEN SI.allow_page_locks = 1 THEN ''ON '' ELSE ''OFF '' END+'' ) ''+@CRLF+'' ON [''+DS.name+'' ] ''
				'
				SET @SQL_Exec = @SQL_Exec+N'
				FROM ['+@TargetDB+'].[sys].[indexes] SI WITH (NOLOCK)
				INNER JOIN ['+@TargetDB+'].[sys].[all_objects] SO WITH (NOLOCK) ON SO.object_id = SI.object_id
				INNER JOIN ['+@TargetDB+'].[sys].[stats] ST WITH (NOLOCK) ON ST.object_id = SI.object_id AND ST.stats_id = SI.index_id 
				INNER JOIN ['+@TargetDB+'].[sys].[data_spaces] DS WITH (NOLOCK) ON SI.data_space_id = DS.data_space_id   
				LEFT JOIN (
					SELECT KC.object_id, KC.index_id, KC.KeyColumns FROM (   
						SELECT IC2.object_id , IC2.index_id ,   
						STUFF((SELECT '', [''+SC.name+CASE WHEN MAX(CONVERT(INT,IC1.is_descending_key)) = 1 THEN ''] DESC '' ELSE ''] ASC '' END
							FROM ['+@TargetDB+'].[sys].[index_columns] IC1 WITH (NOLOCK) 
							INNER JOIN ['+@TargetDB+'].[sys].[columns] SC WITH (NOLOCK) ON SC.object_id = IC1.object_id AND SC.column_id = IC1.column_id AND IC1.is_included_column = 0   
							WHERE IC1.object_id = IC2.object_id    AND IC1.index_id = IC2.index_id    
							GROUP BY IC1.object_id, SC.name, IC1.index_id   
							ORDER BY MAX(IC1.key_ordinal)   
							FOR XML PATH('''')), 1, 2, '''') KeyColumns    
						FROM sys.index_columns IC2    
						WHERE IC2.Object_id = OBJECT_ID(''['+@TargetDB+'].['+@TargetSchema+'].['+@TargetParent+']'',N'''+@TargetParentType+''')
						GROUP BY IC2.object_id ,IC2.index_id
						) KC 
					) KCL ON SI.object_id = KCL.object_id AND SI.Index_id = KCL.index_id  
				LEFT JOIN (
					SELECT LC.object_id, LC.index_id, LC.IncludedColumns FROM (   
						SELECT IC2.object_id , IC2.index_id ,   
						STUFF((SELECT '', [''+SC.name+CASE WHEN MAX(CONVERT(INT,IC1.is_descending_key)) = 1 THEN ''] DESC '' ELSE ''] ASC '' END
							FROM ['+@TargetDB+'].[sys].[index_columns] IC1 WITH (NOLOCK) 
							INNER JOIN ['+@TargetDB+'].[sys].[columns] SC WITH (NOLOCK) ON SC.object_id = IC1.object_id AND SC.column_id = IC1.column_id AND IC1.is_included_column = 1   
							WHERE IC1.object_id = IC2.object_id    AND IC1.index_id = IC2.index_id    
							GROUP BY IC1.object_id, SC.name, IC1.index_id   
							ORDER BY MAX(IC1.key_ordinal)   
							FOR XML PATH('''')), 1, 2, '''') IncludedColumns    
						FROM ['+@TargetDB+'].[sys].[index_columns] IC2 WITH (NOLOCK)     
						WHERE IC2.Object_id = OBJECT_ID(''['+@TargetDB+'].['+@TargetSchema+'].['+@TargetParent+']'',N'''+@TargetParentType+''')  
						GROUP BY IC2.object_id ,IC2.index_id
						) LC WHERE LC.IncludedColumns IS NOT NULL
					) LCL ON SI.object_id = LCL.object_id AND SI.Index_id = LCL.index_id     
				WHERE SI.is_primary_key = 0 AND SI.is_unique_constraint = 0  
				AND SI.Object_id = OBJECT_ID(''['+ @TargetDB +'].['+@TargetSchema+'].['+@TargetParent+']'')
				AND SI.name = '''+@TargetObject+''''
                IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
                EXECUTE sp_executesql @SQL_Exec, @SQL_params, @Definition = @TargetDefinitionText OUTPUT
            END
            -------------------------------------- << Cleanup and Process Definition For output >> -------------
            SET @TargetDefinitionText = LTRIM(RTRIM(@TargetDefinitionText))
            IF ISNULL(@TargetDefinitionText,'') = ''
            BEGIN
                PRINT '-- -- >> ERROR: Object Definition Cannot be Found: [' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
                SET @Rollback = 1
            END
            IF @Rollback = 0
            BEGIN
                -- Remove any Comment Blocks Greencode
                DECLARE @LoopSafe int = 0
                IF @CBR = 1
                BEGIN
                    DECLARE @CommentBlock VARCHAR(MAX) = ''
                    IF CHARINDEX('/*',@TargetDefinitionText) > 0 SET @CommentBlock = 'BEGIN'
                    WHILE @CommentBlock <> '' AND @LoopSafe < 1000
                    BEGIN
                        SET @CommentBlock = [dbo].[fn_StrBetween](@TargetDefinitionText,'/*','*/',0,'') 
                        SET @TargetDefinitionText = REPLACE(@TargetDefinitionText,'/*' + @CommentBlock + '*/' ,'')
                        SET @LoopSafe = @LoopSafe + 1
                    END
                END
                IF @WSR = 1
                BEGIN
                    DECLARE @DoubleSpace SMALLINT = 1
                    SET @LoopSafe = 0
                    IF @COMP = 1 
                    BEGIN 
                        SET @TargetDefinitionText = REPLACE(@TargetDefinitionText,@TAB,'    ')
                        SET @DoubleSpace = CHARINDEX('  ',@TargetDefinitionText)
                    END
                    ELSE
                    BEGIN
                        SET @DoubleSpace = CHARINDEX('  ',@TargetDefinitionText)
                        SET @TargetDefinitionText = REPLACE(@TargetDefinitionText,'    ',@TAB)
                    END
                    WHILE @DoubleSpace > 0 AND @LoopSafe < 10000
                    BEGIN
                        SET @TargetDefinitionText = REPLACE(@TargetDefinitionText,'  ',' ')
                        SET @DoubleSpace = CHARINDEX('  ',@TargetDefinitionText)
                        SET @LoopSafe = @LoopSafe + 1
                    END
                END
                -- Cleanup Definition Replacing All Specials
                --SET @TargetDefinitionText = REPLACE(@TargetDefinitionText,@TAB,'    ')
                SET @TargetDefinitionText = RTRIM(REPLACE(RTRIM(REPLACE(REPLACE(@TargetDefinitionText,@CRLF,@Token),@CR,@Token)),@LF,@Token))
                ----------------------------------------------------------------------------------------------------
                -------------------------------------- << Convert Delimited string to Recordset >> -----------------
                ----------------------------------------------------------------------------------------------------
                INSERT INTO @OUT_TEMP (ReturnData,rOrder)
                SELECT ReturnData,ID FROM [dbo].[tf_DelimitedRecordSet] (@TargetDefinitionText,@Token,1) ORDER BY ID
                --------------------------------------
                IF NOT EXISTS (SELECT TOP 1 ID FROM @OUT_TEMP)
                BEGIN
                    PRINT '-- -- >> ERROR: Object Definition Records Have not been Loaded: [' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
                    SET @Rollback = 1
                END
                IF @Rollback = 0
                BEGIN
                    -------------------------------------- << Process Definition and Adjust for Paramters >> -----------
                    IF ISNULL(@TargetType,'') IN ('IDX','SN') AND @ALT = 1
                    BEGIN
                        SELECT @DEL = 1, @CRE = 1, @ALT = 0
                    END
                    IF @DEL = 1
                    BEGIN
                        IF ISNULL(@TargetType,'') IN ('IDX')
                        BEGIN
                            INSERT INTO @OUT_RETURN (ReturnData)
                            SELECT 'IF  EXISTS (SELECT TOP 1 object_id From [sys].[indexes] WITH (NOLOCK) WHERE object_id = OBJECT_ID(N''[' + @TargetSchema + '].[' + @TargetParent + ']'',N''' + @TargetParentType + ''') AND name = ''' + @TargetObject + ''')'
                        END
                        ELSE
                        BEGIN
                            INSERT INTO @OUT_RETURN (ReturnData)
                            SELECT 'IF  EXISTS (SELECT TOP 1 object_id From [sys].[all_objects] WITH (NOLOCK) WHERE object_id = OBJECT_ID(N''[' + @TargetSchema + '].[' + @TargetObject + ']'',N''' + @TargetType + '''))'
                        END
                        INSERT INTO @OUT_RETURN (ReturnData)
                                SELECT '    DROP FUNCTION [' + @TargetSchema + '].[' + @TargetObject + ']'  WHERE @TargetType IN ('FN', 'IF', 'TF')
                        UNION ALL SELECT '    DROP PROCEDURE [' + @TargetSchema + '].[' + @TargetObject + ']' WHERE @TargetType IN ('P')
                        UNION ALL SELECT '    DROP VIEW [' + @TargetSchema + '].[' + @TargetObject + ']'      WHERE @TargetType IN ('V')
                        UNION ALL SELECT '    DROP TRIGGER [' + @TargetSchema + '].[' + @TargetObject + ']'   WHERE @TargetType IN ('TR')
                        UNION ALL SELECT '    DROP SYNONYM [' + @TargetSchema + '].[' + @TargetObject + ']'   WHERE @TargetType IN ('SN')
                        UNION ALL SELECT '    DROP INDEX [' + @TargetObject + '] ON [' + @TargetSchema + '].[' + @TargetParent + '] WITH ( ONLINE = OFF )'  WHERE @TargetType IN ('IDX')
                        UNION ALL SELECT '    DROP TABLE [' + @TargetSchema + '].[' + @TargetObject + ']' WHERE @TargetType IN ('U')
                        UNION ALL SELECT 'GO'
                    END
                    IF @ALT = 1
                    BEGIN
                        DECLARE @LineID INT = 0
                        SELECT TOP 1 @LineID = MIN(ID) FROM @OUT_TEMP WHERE LTRIM(RTRIM(REPLACE(ReturnData,' ','$$'))) LIKE 'CREATE$$%' 
                        IF ISNULL(@LineID,0) = 0 SELECT TOP 1 @LineID = MIN(ID) FROM @OUT_TEMP WHERE REPLACE(ReturnData,' ','.') LIKE '%CREATE.%' 
                        UPDATE @OUT_TEMP SET ReturnData = REPLACE(ReturnData,'CREATE FUNCTION','ALTER FUNCTION')   WHERE @TargetType IN ('FN', 'IF', 'TF') AND ID = @LineID
                        UPDATE @OUT_TEMP SET ReturnData = REPLACE(ReturnData,'CREATE PROCEDURE','ALTER PROCEDURE') WHERE @TargetType IN ('P') AND ID = @LineID
                        UPDATE @OUT_TEMP SET ReturnData = REPLACE(ReturnData,'CREATE VIEW','ALTER VIEW')           WHERE @TargetType IN ('V') AND ID = @LineID
                        UPDATE @OUT_TEMP SET ReturnData = REPLACE(ReturnData,'CREATE TRIGGER','ALTER TRIGGER')     WHERE @TargetType IN ('TR') AND ID = @LineID
                    END
                    ------------------------ << Add Additional Information and Properties >> ---------------------------
                    --INSERT INTO @OUT_TEMP (ReturnData) SELECT 'GO'
                    --Set Trigger Order if a Trigger
                    IF @EXTP = 1 AND @TargetType = 'TR' AND (@ALT = 1 OR @CRE = 1)
                    BEGIN
                        DECLARE @TargetTriggerOrder VARCHAR(MAX) = ''
                        SET @SQL_Params = N'@TrigOrd VARCHAR(MAX) OUTPUT'
                        SET @SQL_Exec = N'SET @TrigOrd = ''''
                        SELECT @TrigOrd = @TrigOrd + ISNULL(''EXEC sp_settriggerorder''
                            + '' @triggername=N''''[dbo].['' + ISNULL(ST.NAME COLLATE DATABASE_DEFAULT, '''') + '']'''''' 
                            + '', @stmttype=N'''''' + ISNULL(STE.type_desc COLLATE DATABASE_DEFAULT, '''') + '''''''' 
                            + '', @order=N'''''' + CASE WHEN STE.is_first = 1 THEN ''First'' WHEN STE.is_last = 1 THEN ''Last'' ELSE NULL END + '''''''' + ''' + @Token + 'GO' + @Token + ''','''')
                        FROM sys.triggers ST WITH (NOLOCK)
                        INNER JOIN sys.trigger_events STE WITH (NOLOCK)
                            ON STE.object_id = ST.object_id
                        WHERE ST.NAME = ''' + @TargetObject + ''' AND (STE.is_first = 1 OR STE.is_last = 1)'
                        IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
                        EXECUTE sp_executesql @SQL_Exec, @SQL_params, @TrigOrd = @TargetTriggerOrder OUTPUT
                        IF @TargetTriggerOrder <> ''
                        BEGIN
                            INSERT INTO @OUT_TEMP (ReturnData)
                            SELECT ReturnData FROM [dbo].[tf_DelimitedRecordSet] (@TargetTriggerOrder,@Token,1) ORDER BY ID
                        END
                    END
                    --Extended Properties
                    IF @EXTP = 1 AND @CRE = 1
                    BEGIN
                        DECLARE @TargetExtendedProperty VARCHAR(MAX) = ''
                        SET @SQL_Params = N'@PropList VARCHAR(MAX) OUTPUT'
                        SET @SQL_Exec = N'SET @PropList = ''''
                        SELECT @PropList = @PropList + ISNULL(''EXEC sys.sp_addextendedproperty''
                            + '' @name = N'''''' + CONVERT(VARCHAR(MAX),SEP.name) + '''''','' 
                            + '' @value = N'''''' + CONVERT(VARCHAR(MAX),SEP.value) + '''''','' 
                            + '' @level0type = N''''SCHEMA'''', @level0name = [' + @TargetSchema + '],''
                            + '' @level1type = N''''' + 
                            CASE WHEN @TargetType = 'P' THEN 'PROCEDURE'
                                WHEN @TargetType = 'FN' THEN 'FUNCTION'
                                WHEN @TargetType = 'IF' THEN 'FUNCTION'
                                WHEN @TargetType = 'TF' THEN 'FUNCTION'
                                WHEN @TargetType = 'SN' THEN 'SYNONYM'
                                WHEN @TargetType = 'TR' THEN 'TRIGGER'
                                WHEN @TargetType = 'V' THEN 'VIEW'
                            ELSE 'default' END + ''''', @level1name = ''''' + @TargetObject + ''''''' + ''' + @Token + 'GO'','''')
                        FROM [' + @TargetDB + '].[sys].[all_objects] SO WITH (NOLOCK)
                        INNER JOIN [' + @TargetDB + '].[sys].[schemas] SS WITH (NOLOCK) ON SS.schema_id = SO.schema_id AND SS.name = ''' + @TargetSchema + '''
                        INNER JOIN [' + @TargetDB + '].[sys].[extended_properties] SEP WITH (NOLOCK) ON SEP.major_id = SO.object_id AND SEP.minor_id = 0
                        WHERE SO.object_id = OBJECT_ID(''[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + ']'',N''' + @TargetType + ''')'
                        IF @DEBUG = 1 PRINT @SQL_Params + @CRLF + @SQL_Exec
                        EXECUTE sp_executesql @SQL_Exec, @SQL_params, @PropList = @TargetExtendedProperty OUTPUT
                        IF @TargetExtendedProperty <> ''
                        BEGIN
                            INSERT INTO @OUT_TEMP (ReturnData)
                            SELECT ReturnData FROM [dbo].[tf_DelimitedRecordSet] (@TargetExtendedProperty,@Token,1) ORDER BY ID
                        END
                    END
                    ------------------------ << Cleanout Greencode if Flag has been Set >> -----------------------------
                    IF @GCR = 1
                    BEGIN
                        -- Remove All Greencode Lines
                        DELETE FROM @OUT_TEMP WHERE @GCR = 1 AND (ISNULL(REPLACE(ReturnData,' ',''), '') LIKE '--%')
                        -- Strip out Greencode from the right --2.0 Using a Function
                        UPDATE @OUT_TEMP SET ReturnData = [dbo].[fn_StripSQLComments](ReturnData)
                    END
                    ------------------------ << Add Definition Records to OUTPUT Table >> ------------------------------
                    IF @ALT = 1 OR @CRE = 1
                    BEGIN
                        ------------------------ << SEND TO OUTPUT >> ------------------------------------------------------
                        INSERT INTO @OUT_RETURN (ReturnData)
                        SELECT ReturnData
                        FROM @OUT_TEMP
                        ORDER BY rOrder
                        -- Cleanup
                        DELETE FROM @OUT_TEMP 
                    END
                    ---------------------------------------- << RETURN DATA >> ----------------------------------------
                    IF @Rollback = 0
                    BEGIN
						--UPDATE @OUT_RETURN SET ReturnData = REPLACE(ReturnData,'    ',@TAB)
						--UPDATE @OUT_RETURN SET ReturnData = LTRIM(RTRIM(ReturnData))
						UPDATE @OUT_RETURN SET ReturnData = RTRIM(ReturnData)

                        IF @REPL = 1 AND ISNULL(@FindMe,'') <> '' --AND ISNULL(@ReplaceWith,'') <> ''
                        BEGIN
                            UPDATE @OUT_RETURN SET ReturnData = REPLACE(ReturnData,@FindMe,@ReplaceWith)
                        END
                        IF @COMP = 1 UPDATE @OUT_RETURN SET ReturnData = REPLACE(REPLACE(ReturnData,' ',''),@TAB,'')
    
	                    IF @PRINT = 1
                        BEGIN
                            ---------------------------------------------------------------------------------------------------
                            -------------------------------- << PRINT DATA FROM OUTPUT TABLE >> --------------------------------
                            ---------------------------------------------------------------------------------------------------
							UPDATE @OUT_RETURN SET ReturnData = REPLACE(ReturnData,@TAB,'    ') 

                            IF CURSOR_STATUS('global','MasterCursor')>=-1
                            BEGIN
                                CLOSE MasterCursor
                                DEALLOCATE MasterCursor
                            END
                            DECLARE @PrintText VARCHAR(8000)
                            DECLARE MasterCursor CURSOR LOCAL FAST_FORWARD FOR
								SELECT ReturnData FROM @OUT_RETURN 
								WHERE CASE WHEN ((ISNULL(LTRIM(RTRIM(ReturnData)),'') = '') AND (@WSR = 1)) THEN 0 ELSE 1 END = 1
								ORDER BY ID
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
							UPDATE @OUT_RETURN SET ReturnData = REPLACE(ReturnData,@TAB,'    ') --Select Does not Return Tabs for some reason

                            SELECT ReturnData AS '--ReturnData'
                            FROM @OUT_RETURN
                            WHERE CASE WHEN ((ISNULL(LTRIM(RTRIM(ReturnData)),'') = '') AND (@WSR = 1)) THEN 0 ELSE 1 END = 1
                            ORDER BY ID
                            ---------------------------------------------------------------------------------------------------
                        END
                    END
                    THE_END:
                    -- Cleanup
                    DELETE FROM @OUT_TEMP 
                    DELETE FROM @OUT_RETURN 
                END
            END
        END
    END
END TRY
---------------------------------------------------------------------------------------------------
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
IF @Rollback = 1
BEGIN
    PRINT '-- -- >> ERROR: Cerain criteria may not be met to complete successfully. Please see Additional Information or Show Help ? : ' + @AsAtDate
    PRINT '-- -- >>' + REPLICATE('X',100) + CHAR(13) + CHAR(10) + REPLICATE('X',100) + CHAR(13) + CHAR(10) + REPLICATE('X',100)
END
RETURN
GO
