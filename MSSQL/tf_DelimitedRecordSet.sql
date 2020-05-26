CREATE FUNCTION [dbo].[tf_DelimitedRecordSet] (
    @DelmitedString VARCHAR(MAX)
    ,@Delimiter VARCHAR(10)
    ,@IncDuplicates BIT
    )
    RETURNS @OUT_RETURN TABLE (ID INT IDENTITY , ReturnData VARCHAR(max),rOrder INT)
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : tf_DelimitedRecordSet
-- DateTime       : 2014-09-18
-- Author         : Martin Scheepers
-- Purpose        : Convert a Delimited VARCHAR to a VARCHAR RecordSet Object
-- Ver            : 1.1
----------------------------------------------------------------------------------------------------
-- Changes        : 1.1 MJS 20141022 - Add Extra Delimters to End so Avoid Last Value being passed as Truncation
----------------------------------------------------------------------------------------------------
/*
Select * From dbo.tf_DelimitedRecordSet ('abc,d,e,r,y,u,i,oo,oo,xx',',',0) order by id
*/
----------------------------------------------------------------------------------------------------
BEGIN
    ---------------------------------- << DEBUG SECTION >> ---------------------------------------------
    --DECLARE @DelmitedString VARCHAR(MAX) = '[11-11],[12],[13],[14],[15],[16],[17],[],[],[18],[],[18],[],[18],[],[20]'
    --DECLARE @Delimiter VARCHAR(10) = '],['
    --DECLARE @IncDuplicates BIT = 0
    --DECLARE @OUT_RETURN TABLE (ID INT IDENTITY , ReturnData VARCHAR(max),rOrder INT)
    ---------------------------------- << BEGIN PROCESS >> ---------------------------------------------
    DECLARE @OUT_TEMP TABLE (ID INT IDENTITY , ReturnData VARCHAR(max),rOrder INT)
    ---- Use XML Method - This is not as Fast as Current Loop method
    -------------------
    --DECLARE @TMP_XML xml
    --SET @TMP_XML = N'<root><r>' + replace(@DelmitedString,@Delimiter,'</r><r>') + '</r></root>'
    --INSERT INTO @OUT_TEMP (ReturnData)
    --SELECT t.value('.','varchar(max)') as [items]
    --FROM @TMP_XML.nodes('//root/r') as a(t)
    ----------------------------------------------------------------------------------------------------
    --Declare and Create Variable output Tables
    DECLARE @DelmitedStringTMP VARCHAR(MAX)
    DECLARE @Object VARCHAR(MAX)
    DECLARE @ObjectOrder INT
    --Set Temp From input
    SET @DelmitedStringTMP = @DelmitedString + @Delimiter
    --Set Defaults
    SET @ObjectOrder = 1
    DECLARE @iCount SMALLINT = 1
    DECLARE @CntRow INT
    SET @CntRow = 0
    WHILE @DelmitedStringTMP <> '' 
    BEGIN
        --Look For Delimiter
        IF CHARINDEX(@Delimiter, @DelmitedStringTMP) = 0
        BEGIN
            --No More Delimiters so Must be Last Object
            SET @Object = @DelmitedStringTMP
            SET @DelmitedStringTMP = ''
        END
        ELSE
        BEGIN
            WHILE CHARINDEX(@Delimiter, @DelmitedStringTMP) = 1 ANd @iCount <50
            BEGIN
                --Remove Any Delimiters in Front of the String with No Strings Between
                SET @iCount = @iCount + 1
                SET @DelmitedStringTMP = SUBSTRING(@DelmitedStringTMP,LEN(@Delimiter)+1,LEN(@DelmitedStringTMP))
            END
            --Delimiters Exists so Need to Set New Object and Strip from Temp
            SET @Object = dbo.fn_StrBetween(@DelmitedStringTMP, NULL, @Delimiter, 0, NULL)
            SET @DelmitedStringTMP = dbo.fn_StrBetween(@DelmitedStringTMP, @Delimiter, NULL, 0, NULL)
            SET @iCount = 1
        END -- (ELSE)IF CHARINDEX(@Delimiter, @DelmitedStringTMP) = 0
        SELECT @CntRow = COUNT(ReturnData) From @OUT_TEMP
        IF @ObjectOrder < @CntRow
        BEGIN
          SET @ObjectOrder = @CntRow +1
        END
        --Check For Duplicate Objects
        IF @IncDuplicates = 0
        BEGIN
            --Check if Duplicate Exists and only add if Required
            IF NOT EXISTS(Select ReturnData From @OUT_TEMP Where ReturnData = @Object)
            BEGIN
                INSERT INTO @OUT_TEMP (ReturnData,rOrder)
                SELECT @Object,@ObjectOrder
                WHERE isnull(@Object,'') <> ''
                --Incerment Object Order
                SET @ObjectOrder = @ObjectOrder + 1
            END
        END -- IF @IncDuplicates = 0
        ELSE
        BEGIN
            --Add to outpur Regardless of Duplicates
            INSERT INTO @OUT_TEMP (ReturnData,rOrder)
            SELECT @Object,@ObjectOrder
            WHERE isnull(@Object,'') <> ''
            --Incerment Object Order
            SET @ObjectOrder = @ObjectOrder + 1
        END
        SET @Object = ''
    END -- WHILE @DelmitedStringTMP <> ''
    ---------------------------------- << DEBUG SECTION >> ---------------------------------------------
    --SELECT * FROM @OUT_TEMP WHERE ISNULL(ReturnData,'') <> '' ORDER BY rOrder 
    ----------------------------------- << END PROCESS >> ---------------------------------------------
    --Populate Output Table
    INSERT @OUT_RETURN (ReturnData,rOrder )
    SELECT ReturnData,ID 
    FROM @OUT_TEMP 
    WHERE ISNULL(ReturnData,'') <> ''
    ORDER BY ID--,rOrder  
    ---------------------------------------- << RETURN DATA >> ----------------------------------------
    RETURN
END    
GO
