CREATE PROCEDURE [dbo].[p_ScriptData] (
    @ObjectName VARCHAR(200)
    , @WhereClause VARCHAR(MAX) = ''
    , @Parameters VARCHAR(100) = '[DEL][INS][SELECT][UA]'
    , @ExcludeColumns VARCHAR(MAX) = ''
    , @IncludeColumns VARCHAR(MAX) = ''
    )
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : [p_ScriptData]
-- DateTime       : 2014-09-16
-- Author         : Martin Scheepers
-- Purpose        : Script Out Data From a Database Table
-- Ver            : 2.0
----------------------------------------------------------------------------------------------------
-- Changes        :
----------------------------------------------------------------------------------------------------
/*
EXEC [dbo].[p_ScriptData] '[dbo].[ExportTable]','','[DEL][INS][SELECT][UA][NOEXE]','',''
EXEC [dbo].[p_ScriptData] '?'
*/
----------------------------------------------------------------------------------------------------
SET NOCOUNT ON
----------------------------------------------------------------------------------------------------
BEGIN TRY
    IF @ObjectName = '?' OR @ObjectName = '' OR @Parameters = '?' OR @Parameters = ''
    BEGIN
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- PROCEDURE        : [p_ScriptData]'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Purpose          : Script Out Data From a Database Table'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Input Paramaters :'
        PRINT '--     @ObjectName  : Source Table Name - Supports Qualified Table Name including Schema, if no Schema Assume its dbo'
        PRINT '--     @WhereClause : Where Clause to Specifiy Selection Criteria and Can Include ORDER BY Clause'
        PRINT '--     @Paramaters  : [SELECT] : (Default) Will output Results to RecordSet'
        PRINT '--                    [PRINT]  : Will output Results to Message'
        PRINT '--                    [DEL]    : (Default) Include DELETE FROM When Using INSERT'
        PRINT '--                    [INS]    : (Default) INSERT INTO ...'
        PRINT '--                    [UPD]    : UPDATE @ObjectName SET ...'
        PRINT '--                    [EXIST]  : If UPD Specified Will Do IF EXIST, IF [INS] Specified Will Do IF NOT EXIST'
        PRINT '--                    [UA]     : (Default) Only Applies If [INS] Specified, Will Do UNION ALL'
        PRINT '--                    [TPL]    : Include Transaction Template'
        PRINT '--                    [TR]     : Add Command to Disable Triggers on Target Table'
        PRINT '--                    [FK]     : Add Command to Disable Foreign Keys on Target Table'
        PRINT '--                    [SUP]    : Suppress No Data Exists Error'
        PRINT '--                    [NOEXE]  : Do Not include Execution Reference Line'
        PRINT '--                    [NOPK]   : Ignore Primary Key Requirements - 0 = Ensure PK are included in Columns output'
        PRINT '--                    [SHOW]   : Show Excluded Columns Prefixed with --$$'
        PRINT '--                    [INC]    : Increment Order Field Specified [INC:ColumnName|5] When ColumnName is Found it Will Reorder and increment Values by Specified Amount'
        PRINT '--                    [PAD]    : Pad output Columns to max len so nicely spaced'
        PRINT '--                    [TFS]    : Team Foundation Source Control Script'
		PRINT '--                    [FRC]    : If UPD Specified will Remove PK Limitation, Thus Forcing UPDATE on 1st Column.'
        PRINT '--     @ExcludeColumns : SemiColon or Comma Seperated List of Columns to Exclude (Will always include Primary Keys)'
        PRINT '--     @IncludeColumns : SemiColon or Comma Seperated List of Columns to Always Include (Will always include Primary Keys)'
        PRINT '----------------------------------------------------------------------------------------------------'
        PRINT '-- Sample Execute Statment:'
        PRINT '--     EXEC [dbo].p_ScriptData ''[SQLDatabase].[Schema].[SQL_Table_Name]'',''Where_Clause'',''[DEL][INS][SELECT][UA][TFS]'',''Exclude1;Exclude2'',''Include1,Include2'''
        PRINT '----------------------------------------------------------------------------------------------------'
        RETURN
    END
    ----------------------------------------------------------------------------------------------------
    DECLARE @Rollback BIT   = 0 -- 1 = ROLLBACK TRAN, 0 =  COMMIT TRAN.
    DECLARE @AsAtDate VARCHAR(10)  = Convert(VARCHAR(10),GETDATE(),120)
    DECLARE @PROCName VARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'NONAME')
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
    --------------------------------- << DECLARE Exec Line For Proc >> --------------------------------
    DECLARE @ExecLine VARCHAR(MAX)
    SET @ExecLine = '-- EXEC ' + QUOTENAME(@ThisSchema) + '.' + QUOTENAME(@PROCName) + ' ' + '''' +
        QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetObject) + '''' +
        ',' + '''' + Replace(isnull(@WhereClause,''),'''','''''') + '''' +
        ',' + '''' + Replace(isnull(@Parameters,''),'''','''''') + '''' +
        ',' + '''' + isnull(@ExcludeColumns,'') + '''' +
        ',' + '''' + isnull(@IncludeColumns,'') + ''''
    ---------------------------------- >>> Dependant Object Check >>> ----------------------------------
    IF @TargetSRV <> @ThisSRV
    BEGIN
        PRINT '-- -- >> ERROR: Data Cannot be Derived for Different Server: [' + @TargetSRV + '].[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
        SET @Rollback = 1
    END
    IF @TargetDB <> @ThisDB
    BEGIN
        PRINT '-- -- >> ERROR: Data Cannot be Derived for Different Database: [' + @TargetSRV + '].[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
        SET @Rollback = 1
    END
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE [id] = OBJECT_ID(N'[dbo].[tf_DelimitedRecordSet]') AND type IN (N'FN', N'IF', N'TF', N'FS', N'FT'))
    BEGIN
        PRINT '-- -- >> ERROR: Required Object Does Not Exist : ' + @TargetDB + '.[dbo].[tf_DelimitedRecordSet] : ' + @AsAtDate
        SET @Rollback = 1
    END
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE [id] = OBJECT_ID(N'[dbo].[fn_StrBetween]') AND type IN (N'FN', N'IF', N'TF', N'FS', N'FT'))
    BEGIN
        PRINT '-- -- >> ERROR: Required Object Does Not Exist : ' + @TargetDB + '.[dbo].[fn_StrBetween] : ' + @AsAtDate
        SET @Rollback = 1
    END
    -------------------------------------- >>> BEGIN PROCESS >>> --------------------------------------
    IF @Rollback = 0
    BEGIN
        ----------------------------- << Define and Set Paramter Variables >> -----------------------------
        DECLARE @DEBUG TINYINT = 0, @PRINT TINYINT = 0, @SELECT TINYINT = 0
        DECLARE @EXIST TINYINT = 0, @UPD TINYINT = 0, @INS TINYINT = 0, @UA TINYINT = 0, @INC TINYINT = 0
        DECLARE @DEL TINYINT = 0, @TPL TINYINT = 0, @TR TINYINT = 0, @FK TINYINT = 0 , @SUP TINYINT = 0 , @NOEXE TINYINT = 0, @NoPK TINYINT = 0, @ShowExc TINYINT = 0
        DECLARE @PAD TINYINT = 0, @TFS TINYINT = 0, @FRC TINYINT
        IF isnull(@Parameters,'') = '' SET @Parameters = '[DEL][INS][SELECT][UA][TPL][PAD]'
        IF @Parameters LIKE '%DEBUG%' SET @DEBUG = 1
        IF @Parameters LIKE '%PRINT%' SET @PRINT = 1
        IF @Parameters LIKE '%SELECT%' SET @SELECT = 1
        IF @Parameters LIKE '%EXIST%' SET @EXIST = 1
        IF @Parameters LIKE '%INS%' SET @INS = 1
        IF @Parameters LIKE '%UPD%' SET @UPD = 1
        IF @Parameters LIKE '%DEL%' SET @DEL = 1
        IF @Parameters LIKE '%UA%' SET @UA = 1
        IF @Parameters LIKE '%TPL%' SET @TPL = 1 -- Include Transaction Template
        IF @Parameters LIKE '%TR%' SET @TR = 1 -- Add Command to Disable Triggers on Target Table
        IF @Parameters LIKE '%FK%' SET @FK = 1 -- Add Command to Disable Foreign Keys on Target Table
        IF @Parameters LIKE '%SUP%' SET @SUP = 1 -- Suppress No Data Exists Error
        IF @Parameters LIKE '%NOEXE%' SET @NOEXE = 1 -- Do Not include Execution Reference Line
        IF @Parameters LIKE '%NOPK%' SET @NoPK = 1 -- Ignore Primary Key Requirements - 0 = Ensure PK are included in Columns output
        IF @Parameters LIKE '%SHOW%' SET @ShowExc = 1 -- Show Excluded ColumnsPrefixed with --$$
        IF @Parameters LIKE '%INC%' SET @INC = 1 --Increment Order Field Specified [INC:ColumnName|5] When ColumnName is Found it Will Reorder and increment Values by Specified Amount
        IF @Parameters LIKE '%PAD%' SET @PAD = 1 --Pad output Columns to max len so nicely spaced
        IF @Parameters LIKE '%TFS%' SET @TFS = 1 --Use TFS Data Template for Output to be Source Safe Ready
		IF @Parameters LIKE '%FRC%' SET @FRC = 1 --Force Override of PK Limit on UPDATE
        ------------------- << SET Variable Defaults to Eliminate Conflicting Options >> -------------------
        IF @PRINT = 0 AND @SELECT = 0 SET @SELECT = 1
        IF @SELECT = 1 SET @PRINT = 0
        IF @DEBUG = 1 SET @PRINT = 1
        IF @PRINT = 1 SET @SELECT = 0
        IF @UPD = 1 SET @UA = 0
        IF @UPD = 1 SET @DEL = 0
        IF @INS = 0 AND @UPD = 0 AND @DEL = 0 SET @INS = 1
        IF @INS = 1 AND @UPD = 1 SET @EXIST = 1
        IF @TFS = 1 
        BEGIN
            SET @TPL = 0
            SET @FK = 0
            SET @TR = 1
        END
        --Replace Illegal Characters so can Split Useing Delimted Function
        SET @ExcludeColumns = REPLACE(REPLACE(REPLACE(@ExcludeColumns,',',';'),']',''),'[','')
        SET @IncludeColumns = REPLACE(REPLACE(REPLACE(@IncludeColumns,',',';'),']',''),'[','')
        IF ISNULL(@ExcludeColumns,'') = '' AND ISNULL(@IncludeColumns,'') = '' SET @NoPK = 0
        --Increment Field Value if set and Column Name Ends in "Order"
        DECLARE @IncField VARCHAR(255) = '%Order|5'
        DECLARE @IncAmount SMALLINT = 5
        IF @INC = 1
        BEGIN
            SET @IncField = dbo.fn_StrBetween(@Parameters,'INC:',']',0,CONVERT(VARCHAR(255),@IncField))
            SET @IncAmount = dbo.fn_StrBetween(@IncField,'|',NULL,0,CONVERT(VARCHAR(10),@IncAmount))
            SET @IncField = dbo.fn_StrBetween(@IncField,NULL,'|',0,CONVERT(VARCHAR(255),@IncField))
            IF @IncAmount <=0 SET @IncAmount = 1
            IF ISNULL(@IncField,'') = '' SET @IncField = 'XXXXXX'
        END 
        ------------------------- << DECLARE and Create Variable OUTPUT Tables >> -------------------------
        DECLARE @MAXLines INT = 1000
        DECLARE @OUT_RETURN TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        DECLARE @OUT_DATA TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        DECLARE @TRIGS TABLE (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        --DECLARE and Create Temp output Tables
        IF OBJECT_ID('tempdb..#TMP_BLD_SDATA') IS NOT NULL DROP TABLE #TMP_BLD_SDATA
        CREATE TABLE #TMP_BLD_SDATA (ID INT IDENTITY , ReturnData VARCHAR(max), InfoType SMALLINT)
        INSERT INTO @OUT_RETURN (ReturnData)
        SELECT '    -- ------- >> Execution: ' + @ExecLine  WHERE @NOEXE = 0
        ----------------------------------------------------------------------------------------------------
        -------------------------------------- << Start Work Here >> ---------------------------------------
        ----------------------------------------------------------------------------------------------------
        IF ISNULL(@WhereClause,'') = '' SET @WhereClause = '' SET @WhereClause = REPLACE(@WhereClause,'*',CHAR(39))
        ------------- << DECLARE AND GET FIELD DEFINITIONS FROM DATABASE For Source Object >> -------------
        DECLARE @TABLE_SRC TABLE (ID INT IDENTITY,TABLE_NAME NVARCHAR(128), COLUMN_NAME NVARCHAR(128), ORDINAL_POSITION SMALLINT, DATA_TYPE NVARCHAR(128)
            , COLUMN_DEFAULT NVARCHAR(4000), IS_NULLABLE NVARCHAR(3), IS_PRIMARY BIT, SEED_OBJECTID INT, CALC_OBJECTID INT, COL_INC TINYINT, COL_EXC TINYINT, MAX_LEN BIGINT)
        INSERT INTO @TABLE_SRC
            (TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, COLUMN_DEFAULT, IS_NULLABLE, IS_PRIMARY, SEED_OBJECTID, CALC_OBJECTID,COL_INC,COL_EXC)
        SELECT
            isnull([COLS].TABLE_NAME,NULL) AS TABLE_NAME
            , isnull([COLS].COLUMN_NAME,NULL) AS COLUMN_NAME
            , isnull([COLS].ORDINAL_POSITION,0) AS ORDINAL_POSITION
            , isnull([COLS].DATA_TYPE,NULL) AS DATA_TYPE
            , isnull([COLS].COLUMN_DEFAULT,NULL) AS COLUMN_DEFAULT
            , isnull([COLS].IS_NULLABLE,'0') AS IS_NULLABLE
            , CASE WHEN NOT isnull([KEY].CONSTRAINT_NAME, '') = '' THEN 1 ELSE 0 END AS IS_PRIMARY
            , isnull([ID].object_id, 0) AS SEED_OBJECTID --CASE WHEN COLUMNPROPERTY(object_id([COLS].TABLE_NAME), [COLS].COLUMN_NAME, 'IsIdentity') = 1    THEN 1 ELSE 0 END
            , isnull([COM].object_id, 0) AS CALC_OBJECTID --CASE WHEN COLUMNPROPERTY(object_id([COLS].TABLE_NAME), [COLS].COLUMN_NAME, 'IsComputed') = 1    THEN 1 ELSE 0 END
            , 1
            , 0
        FROM INFORMATION_SCHEMA.COLUMNS [COLS] WITH (NOLOCK)
        LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE [KEY] WITH (NOLOCK)
            ON [COLS].TABLE_NAME = [KEY].TABLE_NAME
            AND [COLS].COLUMN_NAME = [KEY].COLUMN_NAME
            AND OBJECTPROPERTY(OBJECT_ID([KEY].CONSTRAINT_NAME), 'IsPrimaryKey') = 1
            AND [COLS].TABLE_CATALOG = [KEY].TABLE_CATALOG
            AND [COLS].TABLE_SCHEMA = [KEY].TABLE_SCHEMA 
        LEFT JOIN sys.identity_columns [ID] WITH (NOLOCK)
            ON OBJECT_ID([COLS].TABLE_NAME) = [ID].object_id
            AND [COLS].COLUMN_NAME = [ID].[name]
        LEFT JOIN sys.computed_columns [COM] WITH (NOLOCK)
            ON OBJECT_ID([COLS].TABLE_NAME) = [COM].object_id
            AND [COLS].COLUMN_NAME = [COM].[name]
        WHERE 1=1
            AND [COLS].TABLE_NAME = @TargetObject
            AND isnull([ID].object_id, 0) = 0 --Exclude Identity
            AND isnull([COM].object_id, 0) = 0 --Exclude Calulated
            --AND [COLS].TABLE_CATALOG = @TargetDB --Not Currently Supported
            AND [COLS].TABLE_SCHEMA = @TargetSchema 
        ORDER BY [COLS].TABLE_NAME,[COLS].ORDINAL_POSITION
		IF NOT EXISTS (SELECT * FROM sysobjects WHERE [id] = OBJECT_ID(N'[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + ']') AND type IN (N'U', N'V'))
		BEGIN
			PRINT '-- -- >> ERROR: Definition Could not be Loaded for Object. Please verify Object Exists : [' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetObject + '] : ' + @AsAtDate
			SET @Rollback = 1
		END
		--Force PK Overeride on update if no PK
		IF @UPD = 1 AND @FRC = 1 AND (NOT EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY = 1))
		BEGIN
			UPDATE @TABLE_SRC SET IS_PRIMARY = 1 WHERE ORDINAL_POSITION = 1
		END
		IF @Rollback = 0
		BEGIN
			----------------------------------------------------------------------------------------------------
			--Exclude Fields Where Defined Ensuring that All Primary Keyes and NON Nullable with no defaults are retained
			IF ISNULL(@ExcludeColumns,'') <> ''
			BEGIN
				UPDATE @TABLE_SRC SET COL_INC = 1 , COL_EXC = 0 -- Reset So that All columns are Included	  
				IF @NoPK = 0
				BEGIN
					UPDATE @TABLE_SRC SET COL_INC = 0 , COL_EXC = 1
					--DELETE FROM @TABLE_SRC
					WHERE ISNULL(COLUMN_NAME,'') IN (
					SELECT ISNULL(ReturnData,'') FROM tf_DelimitedRecordSet (@ExcludeColumns,';',0)) 
						AND ISNULL(COLUMN_NAME,'') NOT IN (
					SELECT ISNULL(COLUMN_NAME,'') FROM @TABLE_SRC WHERE IS_PRIMARY = 1 OR (IS_NULLABLE = 'NO' AND COLUMN_DEFAULT IS NULL))
				END
				IF @NoPK = 1
				BEGIN
					UPDATE @TABLE_SRC SET COL_INC = 0 , COL_EXC = 1
					--DELETE FROM @TABLE_SRC
					WHERE ISNULL(COLUMN_NAME,'') IN (
						SELECT ISNULL(ReturnData,'') FROM tf_DelimitedRecordSet (@ExcludeColumns,';',0))
				END         
			END    
			--Include Fields Where Defined Ensuring that All Primary Keyes and NON Nullable with no defaults are retained
			IF ISNULL(@IncludeColumns,'') <> ''
			BEGIN
				UPDATE @TABLE_SRC SET COL_INC = 0 , COL_EXC = 1 -- Reset So that All columns are Excluded
				UPDATE @TABLE_SRC SET COL_INC = 1 , COL_EXC = 0 -- Now Set to include columns
				WHERE ISNULL(COLUMN_NAME,'') IN (
					SELECT ISNULL(ReturnData,'') FROM tf_DelimitedRecordSet (@IncludeColumns,';',0))
				--------------------------------------------------     
				UPDATE @TABLE_SRC SET COL_INC = 1 , COL_EXC = 0 -- Now Set to include Primary Keys
				WHERE ISNULL(COLUMN_NAME,'') IN (
				SELECT ISNULL(COLUMN_NAME,'') FROM @TABLE_SRC WHERE IS_PRIMARY = 1 OR (IS_NULLABLE = 'NO' AND COLUMN_DEFAULT IS NULL))
					AND COL_INC = 0 AND COL_EXC = 1
			END   
			----------------------------------------------------------------------------------------------------
			------------------ << Build FROM Dynamic SQL to Select Data From Source Object >> ------------------
			DECLARE @DSQL_FROM VARCHAR(MAX)
			DECLARE @OUTObject VARCHAR(255)
			SET @OUTObject = @TargetObject 
			SET @DSQL_FROM = ' FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetObject) + ' WITH (NOLOCK) ' +
			CASE WHEN ISNULL(@WhereClause,'') = '' THEN '' ELSE ISNULL(' WHERE ' + @WhereClause, '') END
			----------------------------------------------------------------------------------------------------
			-- If the Source is a SQL View Try and Get the Most Relevant Table By Looking if the View Ends in a Referenced Table Name    
			IF  EXISTS (Select * From sysobjects WHERE [id] = OBJECT_ID(N'' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetObject)) AND type in (N'V'))
			BEGIN
				SET @OUTObject = SUBSTRING(@TargetObject,7,LEN(@TargetObject)) --REPLACE(@TargetObject,'v_BLD_','')-- SUBSTRING(@TargetObject,7,LEN(@TargetObject))
				--Find Primary Table if this is a View - View Needs to end with TableName
				SELECT DISTINCT TOP 1 
					@OUTObject = OBJECT_NAME(sd.referenced_major_id)
				FROM sys.sql_dependencies sd
				INNER JOIN sys.objects so
					ON sd.referenced_major_id = so.object_id AND LTRIM(RTRIM(so.[type])) = 'U'
				WHERE OBJECT_NAME(sd.object_id) = @TargetObject
					AND CHARINDEX(OBJECT_NAME(sd.referenced_major_id) + '$$',@TargetObject + '$$') > 0
				--Reset the Schema
				SELECT TOP 1 @TargetSchema = ISNULL(SS.Name,@TargetSchema) From sys.objects SO
				INNER JOIN sys.schemas SS ON SS.schema_id = SO.schema_id
				WHERE OBJECT_NAME(SO.object_id) = @OUTObject
			END
			----------------------------------------------------------------------------------------------------	   
			DECLARE @OrderByFieldsCSV VARCHAR(1000)
			SET @OrderByFieldsCSV = CASE WHEN CHARINDEX('ORDER BY',@WhereClause,0) > 0 THEN SUBSTRING(@WhereClause,CHARINDEX('ORDER BY',@WhereClause,0) + 9,LEN(@WhereClause)) ELSE '' END
			IF @INC = 1
			BEGIN
				IF ISNULL(@OrderByFieldsCSV,'') <> ''
					IF CHARINDEX(@IncField,@OrderByFieldsCSV,0) <= 0 SET @OrderByFieldsCSV = @OrderByFieldsCSV + ',' + @IncField
				ELSE
					SET @OrderByFieldsCSV = ' ' + @IncField
			END
			--Tidy up Where Clause
			SET @WhereClause = LEFT(@WhereClause,CASE WHEN CHARINDEX('ORDER BY',@WhereClause,0) > 0 THEN CHARINDEX('ORDER BY',@WhereClause,0) - 1 ELSE LEN(@WhereClause) END)
			----------------------------------------------------------------------------------------------------
			DECLARE @DATA_Columns VARCHAR(MAX)
			DECLARE @DATA_Columns_PK VARCHAR(MAX)
			DECLARE @DATA_ColumnsValues_PK VARCHAR(MAX)
			DECLARE @DATA_ColumnsValues_SET VARCHAR(MAX)
			DECLARE @DATA_ColumnsValues_CSV VARCHAR(MAX)
			--Get List fo Columns (Can be used on Insert/Exist/Update
			SELECT @DATA_Columns = COALESCE(@DATA_Columns + CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN ' --$$ ' ELSE '' END + ',','') +  QUOTENAME(COLUMN_NAME) 
			FROM @TABLE_SRC 
			WHERE CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN 1 ELSE COL_INC END = 1
			ORDER BY COL_INC DESC,ORDINAL_POSITION ASC
			--Get Object Columns Dynamic SQL to Use in Dynamic Select
			IF (EXISTS (SELECT IS_PRIMARY FROM @TABLE_SRC WHERE IS_PRIMARY = 1))
			BEGIN
				---------------------------------- << Build EXISTS Dynamic SQL >> ----------------------------------
				SELECT @DATA_Columns_PK = COALESCE(@DATA_Columns_PK + CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN ' --$$ ' ELSE '' END + ',','') + QUOTENAME(COLUMN_NAME) FROM @TABLE_SRC WHERE IS_PRIMARY = 1 AND CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN 1 ELSE COL_INC END = 1 ORDER BY COL_INC DESC,ORDINAL_POSITION ASC
				--Get Object Column Values Dynamic SQL to Use in Select (Exluding Columns if Defined) Into Comma Seperated String (Exclude Computed and identity Columns)
				SELECT @DATA_ColumnsValues_PK = COALESCE(@DATA_ColumnsValues_PK + ' + '' AND '' + ''','') + CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN ' --$ ' ELSE '' END + QUOTENAME(COLUMN_NAME)  + ' = '' + ' +
				CASE
					WHEN DATA_TYPE IN ('int','uniqueidentifier','bit','smallint') THEN 'ISNULL('''''''' + CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)) + '''''''',''NULL'')'
					WHEN DATA_TYPE IN ('datetime') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
					WHEN DATA_TYPE IN ('time') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
					WHEN DATA_TYPE IN ('money') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',2),''NULL'')'
					WHEN DATA_TYPE IN ('float') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',128),''NULL'')' --1.1
					WHEN DATA_TYPE IN ('decimal') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + '),''NULL'')' --1.1
					WHEN DATA_TYPE IN ('xml') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS nvarchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
					WHEN DATA_TYPE IN ('text') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
					WHEN DATA_TYPE IN ('image') THEN '''NULL'''
					WHEN DATA_TYPE IN ('sql_variant') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
					ELSE 'ISNULL('''''''' + REPLACE(' + QUOTENAME(COLUMN_NAME)  + ','''''''','''''''''''') + '''''''',''NULL'')'
				END
				FROM @TABLE_SRC WHERE IS_PRIMARY = 1 AND  CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN 1 ELSE COL_INC END = 1 ORDER BY COL_INC DESC,ORDINAL_POSITION ASC
				----------------------------------------------------------------------------------------------------
				---------------------------------- << Build UPDATE Dynamic SQL >> ----------------------------------
				--Get Object Column Values Dynamic SQL to Use in Select (Exluding Columns if Defined) Into Comma Seperated String (Exclude Computed and identity Columns)
				SELECT @DATA_ColumnsValues_SET = COALESCE(@DATA_ColumnsValues_SET + CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN ' --$$ ' ELSE '' END + ' + '','' + ''','') + QUOTENAME(COLUMN_NAME)  + ' = '' + ' +
						CASE
							WHEN DATA_TYPE IN ('int','uniqueidentifier','bit','smallint') THEN 'ISNULL('''''''' + CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('datetime') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('time') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('money') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',2),''NULL'')'
							WHEN DATA_TYPE IN ('float') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',128),''NULL'')' --1.1
							WHEN DATA_TYPE IN ('decimal') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + '),''NULL'')' --1.1
							WHEN DATA_TYPE IN ('xml') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS nvarchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('text') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('image') THEN '''NULL'''
							WHEN DATA_TYPE IN ('sql_variant') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							ELSE 'ISNULL('''''''' + REPLACE(' + QUOTENAME(COLUMN_NAME)  + ','''''''','''''''''''') + '''''''',''NULL'')'
						END
				FROM @TABLE_SRC WHERE IS_PRIMARY = 0 AND CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN 1 ELSE COL_INC END = 1 ORDER BY COL_INC DESC,ORDINAL_POSITION ASC
			END
			ELSE
			BEGIN
				IF (@UPD = 1 OR @EXIST = 1)
				BEGIN
					PRINT '-- -- >> ERROR: No Primary Keys Found on Object:' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + '. Please Disable the "IF EXISTS" And/Or "UPDATE" Flag.'
					SET @UPD = 0
					SET @INS = 1
					SET @EXIST = 0
					SET @Rollback = 1
				END
			END 
			IF @Rollback = 0
			BEGIN
				----------------------------------------------------------------------------------------------------
				---------------------------------- << Build INSERT Dynamic SQL >> ----------------------------------
				--PAD to max len
				IF @PAD = 1
				BEGIN
					DECLARE @Columns varchar(max);
					DECLARE @Unpivot varchar(max);
					DECLARE @SQL varchar(max);
					--------------------------------------
					SELECT @Columns = STUFF((
					SELECT ',convert(bigint,max(len(replace(isnull(convert(varchar(max),[' + COLUMN_NAME + ']),''''),'' '',''_'')))) AS [' + COLUMN_NAME + ']' + CHAR(10) + CHAR(9)
					FROM @TABLE_SRC
					ORDER BY ORDINAL_POSITION
					FOR XML PATH('')),1,1,'')
					--------------------------------------
					SELECT @Unpivot = STUFF((
					SELECT ',[' + COLUMN_NAME + ']' --'/' + isnull(ltrim(CHARACTER_MAXIMUM_LENGTH),DATA_TYPE) + ']'
					FROM @TABLE_SRC
					ORDER BY ORDINAL_POSITION
					FOR XML PATH('')),1,1,'')
					--------------------------------------
					SELECT  @SQL = 
					'
					INSERT INTO #TMP_BLD_SMAX
					SELECT COLUMN_NAME, MAX_LEN
					FROM    (
					SELECT ' + @Columns + ' FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' ' + CASE WHEN ISNULL(@WhereClause,'') = '' THEN '' ELSE ' WHERE ' + REPLACE(REPLACE(@WhereClause,CHAR(39),CHAR(39)+CHAR(39)),'''''','''') END + '
					)x 
					UNPIVOT (MAX_LEN for COLUMN_NAME in (' + @Unpivot + '))p'
					--------------------------------------
					IF OBJECT_ID('tempdb..#TMP_BLD_SMAX') IS NOT NULL DROP TABLE #TMP_BLD_SMAX
					CREATE TABLE #TMP_BLD_SMAX (COLUMN_NAME NVARCHAR(128), MAX_LEN BIGINT)
					--------------------------------------
					EXEC (@SQL)
					--------------------------------------
					UPDATE SRC SET SRC.MAX_LEN = MX.MAX_LEN   
					FROM @TABLE_SRC SRC
					INNER JOIN #TMP_BLD_SMAX MX ON MX.COLUMN_NAME = SRC.COLUMN_NAME  
					--------------------------------------
					UPDATE @TABLE_SRC SET MAX_LEN = 250 WHERE MAX_LEN > 250
				END
				--Get Object Column Values Dynamic SQL to Use in Select (Exluding Columns if Defined) Into Comma Seperated String (Exclude Computed and identity Columns)
				SELECT @DATA_ColumnsValues_CSV = COALESCE(@DATA_ColumnsValues_CSV + 
					CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN ' + '' --$$ ''' ELSE '' END + ' + '','' ' + '' + ' + ','') + 
					CASE
						WHEN COLUMN_NAME like '%Order' AND @IncField = 'XXXXXX' AND @INC = 1 AND  DATA_TYPE IN ('int','smallint','money','decimal','float')
						THEN 'ISNULL('''''''' + CONVERT(VARCHAR(20),' + CONVERT(VARCHAR(10),@IncAmount) + ' * ROW_NUMBER() OVER (ORDER BY ' + QUOTENAME(COLUMN_NAME) + ' ASC))' + '+ '''''''',''NULL'')'
						WHEN COLUMN_NAME like @IncField AND @INC = 1 AND  DATA_TYPE IN ('int','smallint','money','decimal','float') 
						THEN 'ISNULL('''''''' + CONVERT(VARCHAR(20),' + CONVERT(VARCHAR(10),@IncAmount) + ' * ROW_NUMBER() OVER (ORDER BY ' + @OrderByFieldsCSV + ' ASC))' + '+ '''''''',''NULL'')'
						ELSE
						CASE
							WHEN DATA_TYPE IN ('int','uniqueidentifier','bit','smallint') THEN 'ISNULL('''''''' + CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('datetime') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('time') THEN 'ISNULL('''''''' + CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',120) + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('money') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',2),''NULL'')'
							WHEN DATA_TYPE IN ('float') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + ',128),''NULL'')' --1.1
							WHEN DATA_TYPE IN ('decimal') THEN 'ISNULL(CONVERT(varchar(MAX),' + QUOTENAME(COLUMN_NAME)  + '),''NULL'')' --1.1
							WHEN DATA_TYPE IN ('xml') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS nvarchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('text') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME) + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							WHEN DATA_TYPE IN ('image') THEN '''NULL'''
							WHEN DATA_TYPE IN ('sql_variant') THEN 'ISNULL('''''''' + REPLACE(CAST(' + QUOTENAME(COLUMN_NAME)  + ' AS varchar(MAX)),'''''''','''''''''''') + '''''''',''NULL'')'
							ELSE 'ISNULL('''''''' + REPLACE(' + QUOTENAME(COLUMN_NAME)  + ','''''''','''''''''''') + '''''''',''NULL'')'
						END
					END
					+ CASE WHEN @PAD = 1 THEN ' + ISNULL(replicate('' '',' + CONVERT(VARCHAR(20),ISNULL(MAX_LEN,10)) + ' - LEN(CONVERT(VARCHAR(MAX),' + QUOTENAME(COLUMN_NAME)  + '))),'''') ' ELSE '' END
				FROM @TABLE_SRC WHERE CASE WHEN COL_EXC = 1 AND @ShowExc = 1 THEN 1 ELSE COL_INC END = 1 ORDER BY COL_INC DESC,ORDINAL_POSITION ASC
				---------------------------------------------------------------------------------------------------
				------------------------ << BUILD Dynamic SQL and execute to Temp Table >> ------------------------
				DECLARE @DATA_DELETE VARCHAR(MAX)
				DECLARE @DATA_INSERT VARCHAR(MAX)
				DECLARE @DATA_INSERT_CSV VARCHAR(MAX)
				DECLARE @DATA_UPDATE VARCHAR(MAX)
				DECLARE @DATA_EXIST VARCHAR(MAX)
				DECLARE @DATA_NOTEXIST VARCHAR(MAX)
				DECLARE @DataCount INT
				SET @DATA_DELETE = 'SELECT ''' + CASE WHEN @DEL = 0 THEN '-- DELETE FROM ' ELSE 'DELETE FROM ' END + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ''
				SET @DATA_DELETE = @DATA_DELETE + CASE WHEN ISNULL(@WhereClause,'') = '' THEN '''' ELSE ' WHERE ' + REPLACE(@WhereClause,CHAR(39),CHAR(39)+CHAR(39)) + '''' END
				SET @DATA_INSERT = 'INSERT INTO ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' (' + REPLACE(@DATA_Columns,'--$$',') --$$') + ') '
				SET @DATA_INSERT_CSV = 'SELECT '' + ' + @DATA_ColumnsValues_CSV
				SET @DATA_UPDATE = 'UPDATE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' SET ' + @DATA_ColumnsValues_SET + ' + '' WHERE ' + @DATA_ColumnsValues_PK
				SET @DATA_EXIST = 'IF EXISTS (SELECT ' + isnull(@DATA_Columns_PK,'*') + ' FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' WITH (NOLOCK) WHERE ' + @DATA_ColumnsValues_PK + '+'')'
				SET @DATA_NOTEXIST = 'IF NOT EXISTS (SELECT ' + isnull(@DATA_Columns_PK,'*') + ' FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' WITH (NOLOCK) WHERE ' + @DATA_ColumnsValues_PK + '+'')'
				SET @DataCount= 0
				---------------------------------------------------------------------------------------------------
				IF @INS = 0 AND @UPD = 1 AND @EXIST = 0 --UPDATE ONLY
				BEGIN
					SET @UA = 0
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT 'SELECT ''' + @DATA_UPDATE  + @DSQL_FROM
					END
					ELSE
					BEGIN
						EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_UPDATE  + @DSQL_FROM)
						SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 0
						IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @INS = 0 AND @UPD = 1 AND @EXIST = 1 -- EXIST UPDATE
				BEGIN
					SET @UA = 0
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT 'SELECT ''' + @DATA_EXIST + ' ' +  @DATA_UPDATE  + @DSQL_FROM
					END
					ELSE
					BEGIN
						EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_EXIST + ' ' +  @DATA_UPDATE  + @DSQL_FROM)
						SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 0
						IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @INS = 1 AND @UPD = 0 AND @EXIST = 1 -- NOT EXIST INSERT
				BEGIN
					SET @UA = 0
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT 'SELECT ''' + @DATA_NOTEXIST + ' ' + @DATA_INSERT + @DATA_INSERT_CSV + @DSQL_FROM
					END
					ELSE
					BEGIN
						EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_NOTEXIST + ' ' + @DATA_INSERT + @DATA_INSERT_CSV + @DSQL_FROM)
						SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 0
						IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @INS = 1 AND @UPD = 1 --IF EXIST UPDATE ELSE INSERT
				BEGIN
					SET @UA = 0
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT 'SELECT ''' + @DATA_EXIST + ' ' +  @DATA_UPDATE  + ' + '' ELSE ' + @DATA_INSERT + @DATA_INSERT_CSV + @DSQL_FROM
					END
					ELSE
					BEGIN
						SET @EXIST = 1
						EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_EXIST + ' ' +  @DATA_UPDATE  + ' + '' ELSE ' + @DATA_INSERT + @DATA_INSERT_CSV + @DSQL_FROM)
						SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 0
						IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @INS = 0 AND @UPD = 0 AND @DEL = 1 --DELETE ONLY
				BEGIN
					SET @UA = 0
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT 'SELECT ''' + @DATA_EXIST + ' ' +  @DATA_UPDATE  + ' + '' ELSE ' + @DATA_INSERT + @DATA_INSERT_CSV + @DSQL_FROM
					END
					ELSE
					BEGIN
						EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) ' + @DATA_DELETE)
						SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 0
						IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @INS = 1 AND @UPD = 0 AND @EXIST = 0 --DELETE AND INSERT ONLY
				BEGIN
					IF @DEBUG = 1
					BEGIN
						PRINT '--[DEBUG] Parameter Set - No Work Will be Done!'
						PRINT '-- --------------------------------------------------------'
						PRINT @DATA_DELETE
						PRINT 'SELECT ''' + @DATA_INSERT + ''''
						PRINT 'SELECT ''' + @DATA_INSERT_CSV +  @DSQL_FROM
					END
					ELSE
					BEGIN
						EXEC ('DELETE FROM #TMP_BLD_SDATA')
						IF @UA = 0
						BEGIN
							--INSERT SELECT
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) ' + @DATA_DELETE)
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) ' + 'SELECT ''''')
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_INSERT_CSV +  @DSQL_FROM)
							UPDATE #TMP_BLD_SDATA SET ReturnData = ISNULL(@DATA_INSERT,'') + ReturnData WHERE ID > 2
							SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 2
							IF @DataCount > 0 INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
						END
						ELSE
						BEGIN
							--INSERT SELECT UNION ALL
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) ' + @DATA_DELETE)
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) ' + 'SELECT ''''')
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData) SELECT ''' + @DATA_INSERT + '''')
							EXEC ('INSERT INTO #TMP_BLD_SDATA (ReturnData)' + 'SELECT ''' + @DATA_INSERT_CSV +  @DSQL_FROM)
							--PrePend UNION ALL
							UPDATE #TMP_BLD_SDATA SET ReturnData = 'UNION ALL ' + ReturnData WHERE ID > 4
							SELECT @DataCount = COUNT(ID) FROM #TMP_BLD_SDATA Where ID > 3
							--Do Maxlines
							IF @DataCount > @MAXLines AND @DataCount > 100
							BEGIN
								DECLARE @iStart INT
								SET @iStart = 1
								--Add First Batch with No MOD
								INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] FROM
								(SELECT ROW_NUMBER() OVER(ORDER BY ID) AS RowNum, [ReturnData] From #TMP_BLD_SDATA) as TData
								WHERE TData.RowNum BETWEEN @iStart and @iStart + @MAXLines
								SET @iStart = @iStart + @MAXLines + 1
								WHILE @iStart < @DataCount
								BEGIN
									--Add Insert Statement
									INSERT INTO @OUT_DATA (ReturnData) SELECT ''
									IF @TPL = 0 INSERT INTO @OUT_DATA (ReturnData) SELECT 'GO
									' --1.5 MJS
									INSERT INTO @OUT_DATA (ReturnData) SELECT + @DATA_INSERT
									--Add First and Remove UA
									INSERT INTO @OUT_DATA (ReturnData) SELECT REPLACE([ReturnData],'UNION ALL ','') FROM
										(SELECT ROW_NUMBER() OVER(ORDER BY ID) AS RowNum, [ReturnData] From #TMP_BLD_SDATA) as TData
										WHERE TData.RowNum = @iStart --BETWEEN @iStart and @iStart + 1
									SET @iStart = @iStart + 1
									--ADD Rest
									IF @iStart < @DataCount
									INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] FROM
										(SELECT ROW_NUMBER() OVER(ORDER BY ID) AS RowNum, [ReturnData] From #TMP_BLD_SDATA) as TData
										WHERE TData.RowNum BETWEEN @iStart and @iStart + @MAXLines
									--Increment
									SET @iStart = @iStart + @MAXLines + 1
								END
							END
							ELSE
								INSERT INTO @OUT_DATA (ReturnData) SELECT [ReturnData] From #TMP_BLD_SDATA ORDER BY ID
						END
					END
				END
				---------------------------------------------------------------------------------------------------
				IF @DataCount <= 0 AND @DEBUG = 0 AND @SUP = 0
				BEGIN
					PRINT @Execline
					PRINT '-- -- >> ERROR: No Data Exists in Object : ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' : ' + Convert(VARCHAR(10), GETDATE(), 120)
					SET @Rollback = 1
				END
				----------------------------------------------------------------------------------------------------
				---------------------------------------- << BUILD OUTPUT >> ----------------------------------------
				IF @Rollback = 0 AND @DEBUG = 0 AND @DataCount > 0
				BEGIN
					DECLARE @Spaces VARCHAR(10)
					SET @Spaces = ''
					SET @Spaces = Space(4)
					IF @TPL = 1
					BEGIN
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT '----------------------------------------------------------------------------------------------------'
						UNION ALL SELECT 'SET NOCOUNT ON'
						UNION ALL SELECT 'DECLARE @Rollback BIT   = 0 -- 1 = ROLLBACK TRAN, 0 =  COMMIT TRAN.'
						UNION ALL SELECT '---------------------------------- >>> BEGIN TANSACTION / TRY >>> ----------------------------------'
						UNION ALL SELECT 'BEGIN TRANSACTION T1'
						UNION ALL SELECT 'BEGIN TRY'
						UNION ALL SELECT '    IF @Rollback = 0'
						UNION ALL SELECT '    BEGIN'   
					END
					----------------------------------------------------------------------------------------------------
					IF @TFS = 1
					BEGIN
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT '----------------------------------------------------------------------------------------------------'
						UNION ALL SELECT 'SET NOCOUNT ON'
						UNION ALL SELECT 'BEGIN TRY'
						UNION ALL SELECT '    PRINT ''***Data is Being Deployed - ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ''''
					END
					----------------------------------------------------------------------------------------------------
					IF @FK = 1
					BEGIN
						IF EXISTS(SELECT referenced_object_id FROM sys.foreign_keys WHERE object_name(parent_object_id)= @OUTObject and is_ms_shipped = 0)
						BEGIN
							INSERT INTO @OUT_RETURN (ReturnData)
							SELECT DISTINCT @Spaces + 'ALTER TABLE [' + object_name(parent_object_id) + '] NOCHECK CONSTRAINT all'
							FROM sys.foreign_keys
							WHERE object_name(parent_object_id)= @OUTObject and is_ms_shipped = 0
						END
						IF EXISTS(SELECT parent_object_id FROM sys.foreign_keys WHERE object_name(referenced_object_id)= @OUTObject)
						BEGIN
							INSERT INTO @OUT_RETURN (ReturnData)
							SELECT DISTINCT @Spaces + 'ALTER TABLE [' + object_name(parent_object_id) + '] NOCHECK CONSTRAINT all'
							FROM sys.foreign_keys
							WHERE object_name(referenced_object_id)= @OUTObject and is_ms_shipped = 0
						END
					END
					----------------------------------------------------------------------------------------------------
					If @TR = 1
					BEGIN
						INSERT INTO @TRIGS (ReturnData)
						SELECT object_name(object_id) From sys.triggers where is_disabled = 0 AND object_name(parent_id) = @OUTObject
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT @Spaces + 'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[' + ReturnData + ']'')) ALTER TABLE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' DISABLE TRIGGER [' + ReturnData + ']'
						FROM @TRIGS
					END
					----------------------------------------------------------------------------------------------------
					--Update Results to be SQL Compliant
					UPDATE @OUT_DATA SET [ReturnData] = REPLACE([ReturnData],'''GetDate()''','GetDate()')
					--------------------------------- << PASS DATA SCRIPT TO OUTPUT >> ---------------------------------
					--INSERT INTO @OUT_RETURN (ReturnData) SELECT @Spaces +  '----------------------------------------------------------------------------------------------------'
					INSERT INTO @OUT_RETURN (ReturnData) SELECT @Spaces + [ReturnData] From @OUT_DATA ORDER BY ID
					INSERT INTO @OUT_RETURN (ReturnData) SELECT '' WHERE @NOEXE = 0
					--INSERT INTO @OUT_RETURN (ReturnData) SELECT @Spaces +  '----------------------------------------------------------------------------------------------------'
					----------------------------------------------------------------------------------------------------
					If @TR = 1
					BEGIN
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT @Spaces + 'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[' + ReturnData + ']'')) ALTER TABLE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@OUTObject) + ' ENABLE TRIGGER [' + ReturnData + ']'
						FROM @TRIGS
					END
					----------------------------------------------------------------------------------------------------
					IF @FK = 1
					BEGIN
						IF EXISTS(SELECT referenced_object_id FROM sys.foreign_keys WHERE object_name(parent_object_id)= @OUTObject and is_ms_shipped = 0)
						BEGIN
							INSERT INTO @OUT_RETURN (ReturnData)
							SELECT DISTINCT @Spaces + 'ALTER TABLE [' + object_name(parent_object_id) + '] WITH CHECK CHECK CONSTRAINT all'
							FROM sys.foreign_keys
							WHERE object_name(parent_object_id)= @OUTObject and is_ms_shipped = 0
						END
						IF EXISTS(SELECT parent_object_id FROM sys.foreign_keys WHERE object_name(referenced_object_id)= @OUTObject)
						BEGIN
							INSERT INTO @OUT_RETURN (ReturnData)
							SELECT DISTINCT @Spaces + 'ALTER TABLE [' + object_name(parent_object_id) + '] WITH CHECK CHECK CONSTRAINT all'
							FROM sys.foreign_keys
							WHERE object_name(referenced_object_id)= @OUTObject and is_ms_shipped = 0
						END
					END
					----------------------------------------------------------------------------------------------------
					IF @TFS = 1
					BEGIN
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT 'END TRY'
						UNION ALL SELECT '------------------------------------ >>> COMMITT / ROLLBACK >>> ------------------------------------'
						UNION ALL SELECT '-- Check If Error Has Been Caught by TRY METHOD'
						UNION ALL SELECT 'BEGIN CATCH'
						UNION ALL SELECT '    DECLARE @ERROR_MESSAGE  NVARCHAR(4000) = ''~~~Aborting due to error : '' + isnull(ERROR_MESSAGE(),'''') '
						UNION ALL SELECT '    RAISERROR (@ERROR_MESSAGE,10,1) WITH SETERROR '
						UNION ALL SELECT 'END CATCH'
						UNION ALL SELECT ''
						--UNION ALL SELECT 'GO'
					END
					----------------------------------------------------------------------------------------------------
					IF @TPL = 1
					BEGIN
						INSERT INTO @OUT_RETURN (ReturnData)
						SELECT '    END'
						UNION ALL SELECT 'END TRY'
						UNION ALL SELECT '------------------------------------ >>> COMMITT / ROLLBACK >>> ------------------------------------'      
						UNION ALL SELECT '-- Check If Error Has Been Caught by TRY METHOD'
						UNION ALL SELECT 'BEGIN CATCH'
						UNION ALL SELECT '    SET @Rollback = 1'
						UNION ALL SELECT '    DECLARE @ErrorMessage NVARCHAR(2000),@ErrorSeverity INT,@ErrorState INT,@ErrorNo VARCHAR(10), @ErrorLine VARCHAR(10)'
						UNION ALL SELECT '    SELECT @ErrorMessage = ERROR_MESSAGE(),@ErrorSeverity = ERROR_SEVERITY(),@ErrorState = ERROR_STATE()'
						UNION ALL SELECT '    ,@ErrorNo = CAST(ERROR_NUMBER() AS VARCHAR) ,@ErrorLine = CAST(ERROR_LINE() AS VARCHAR)'
						UNION ALL SELECT '    RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState) WITH SETERROR'
						UNION ALL SELECT '    PRINT ''-- -- >> ERROR CAUGHT: Number : '' +  isnull(@ErrorNo,''0'') + '' , Line: '' + isnull(@ErrorLine,''0'') + '' , PROC: '' + isnull(OBJECT_NAME(@@PROCID),''NONAME'')'           
						UNION ALL SELECT '    PRINT ''-- -- >> Error Message: '' + isnull(@ErrorMessage,'''')'
						UNION ALL SELECT 'END CATCH'
						UNION ALL SELECT 'IF @@ERROR <> 0'
						UNION ALL SELECT '    SET @Rollback = 1'
						UNION ALL SELECT 'IF @Rollback = 1'
						UNION ALL SELECT 'BEGIN'
						UNION ALL SELECT '    PRINT ''-- -- >> ERROR: Transaction ROLLBACK'''
						UNION ALL SELECT '    PRINT ''--'' + REPLICATE(''X'',999) + CHAR(13) + CHAR(10) + REPLICATE(''X'',999) + CHAR(13) + CHAR(10) + REPLICATE(''X'',999)'
						UNION ALL SELECT '    ROLLBACK TRANSACTION T1'
						UNION ALL SELECT 'END'
						UNION ALL SELECT 'ELSE'
						UNION ALL SELECT '    COMMIT TRANSACTION T1'
						UNION ALL SELECT 'GO'
						UNION ALL SELECT 'IF @@TRANCOUNT>0 ROLLBACK'
						UNION ALL SELECT 'GO'
					END
				END
            END
        END
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
            DECLARE MasterCursor CURSOR LOCAL FAST_FORWARD FOR
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
    --RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState) WITH SETERROR
    PRINT '-- -- >> ERROR CAUGHT: Number : ' +  isnull(@ErrorNo,'0') + ' , Line: ' + isnull(@ErrorLine,'0') + ' , Exec/Proc: ' + isnull(@ExecLine,@PROCName)
    PRINT '-- -- >> Error Message: ' + isnull(@ErrorMessage,'')
END CATCH
IF @Rollback = 1
BEGIN
    PRINT '-- -- >> ERROR: Cerain criteria may not be met to complete successfully. Please see Additional Information or Show Help ? : ' + @AsAtDate
    PRINT '-- -- >>' + REPLICATE('X',100) + CHAR(13) + CHAR(10) + '-- -- >>' + REPLICATE('X',100) + CHAR(13) + CHAR(10) + '-- -- >>' + REPLICATE('X',100)
END
RETURN
GO


