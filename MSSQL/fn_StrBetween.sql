CREATE FUNCTION [dbo].[fn_StrBetween] (
    @ObjectName VARCHAR(MAX)
    ,@FindStart VARCHAR(200)
    ,@FindEnd VARCHAR(200)
    ,@Offset INT
    ,@StringNotFound VARCHAR(MAX)
    )
    RETURNS VARCHAR(MAX)
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : fn_StrBetween
-- DateTime       : 2014-09-18
-- Author         : Martin Scheepers
-- Purpose        : Returns a Portion of a VARCHAR(MAX) Object between FindStart and FindEnd
-- Ver            : 1.0
----------------------------------------------------------------------------------------------------
-- Changes        : Based on fn_StrBetween (Unknown Author)
----------------------------------------------------------------------------------------------------
/*
SELECT [dbo].[fn_StrBetween]('[[11-11],[12]##[13],[14],[18],[]**[18],[],[20]],[','##',NULL,0,NULL)
SELECT [dbo].[fn_StrBetween]('[[11-11],[12]##[13],[14],[18],[]**[18],[],[20]],[','##','**',0,NULL)
*/
----------------------------------------------------------------------------------------------------
BEGIN
    ---------------------------------- << DEBUG SECTION >> ---------------------------------------------
    --DECLARE @ObjectName VARCHAR(MAX) = '],[[11-11],[12],[13],[14],[18],[],[18],[],[20]],['
    --DECLARE @FindStart VARCHAR(200) = '],['
    --DECLARE @FindEnd VARCHAR(200) = NULL
    --DECLARE @Offset int = 0
    --DECLARE @StringNotFound VARCHAR(MAX) = NULL
    ---------------------------------- << BEGIN PROCESS >> ---------------------------------------------
    DECLARE @OUTPUT as VARCHAR(MAX) = ''
    DECLARE @iStart INT
    DECLARE @iEnd INT
    SET @OUTPUT = ''
    SET @OUTPUT = @ObjectName
    IF @FindStart IS NOT NULL AND @FindEnd IS NOT NULL
    BEGIN
        SET @iStart = CASE WHEN CHARINDEX(@FindStart,@OUTPUT,@Offset) = 0
            THEN 0
            ELSE CHARINDEX(@FindStart,@OUTPUT,@Offset) + DATALENGTH(@FindStart) END
        IF @iStart <> 0
        BEGIN
            SET @iEnd = CASE WHEN CHARINDEX(@FindEnd,@OUTPUT,@iStart + 1) = 0
                THEN 0
                ELSE CHARINDEX(@FindEnd,@OUTPUT,@iStart + 1) - @iStart END
        END
        ELSE
        BEGIN
            SET @iEnd = CASE WHEN CHARINDEX(@FindEnd,@OUTPUT,@Offset) = 0
                THEN 0
                ELSE CHARINDEX(@FindEnd,@OUTPUT,@Offset) END
        END --(Else) IF @Start <> 0
    END
    ELSE IF @FindStart IS NULL
    BEGIN
        SET @iStart = 1
        SET @iEnd = CASE WHEN CHARINDEX(@FindEnd,@OUTPUT,@Offset) = 0
            THEN 0
            ELSE CHARINDEX(@FindEnd,@OUTPUT,@Offset) - @iStart END
    END
    ELSE IF @FindEnd IS NULL
    BEGIN
        SET @iStart = CASE WHEN CHARINDEX(@FindStart,@OUTPUT,@Offset) = 0
            THEN 0
            ELSE CHARINDEX(@FindStart,@OUTPUT,@Offset) + DATALENGTH(@FindStart) END
        SET @iEnd = DATALENGTH(@OUTPUT)
    END -- IF @FindStart IS NOT NULL AND @FindEnd IS NOT NULL
    IF @iStart <> 0 AND @iEnd <> 0
    BEGIN
        SET @OUTPUT = SUBSTRING(@OUTPUT,@iStart,@iEnd)
    END
    ELSE IF @StringNotFound IS NULL
    BEGIN
        IF @iEnd = 0
            SET @iEnd = DATALENGTH(@OUTPUT) + 1
        SET @OUTPUT = SUBSTRING(@OUTPUT,@iStart,@iEnd)
    END
    ELSE
        SET @OUTPUT = CASE WHEN @StringNotFound = '@@NULL' THEN NULL ELSE @StringNotFound END
    ---------------------------------- << DEBUG SECTION >> ---------------------------------------------
    --SELECT @OUTPUT
    ----------------------------------- << END PROCESS >> ---------------------------------------------
    ---------------------------------------- << RETURN DATA >> ----------------------------------------
    RETURN @OUTPUT
END
GO
