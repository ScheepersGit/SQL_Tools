CREATE FUNCTION [dbo].[fn_StripSQLComments] (
    @CommentedSQLCode VARCHAR(MAX)
    )
    RETURNS VARCHAR(MAX)
AS
----------------------------------------------------------------------------------------------------
-- Script Name    : fn_StripSQLComments
-- DateTime       : 20170912
-- Author         : Martin Scheepers
-- Purpose        : Returns a Portion of a VARCHAR(MAX) Object Deleting Any String After a Valid SQL comment marker is found
-- Ver            : 1.0
----------------------------------------------------------------------------------------------------
-- Changes        : 
----------------------------------------------------------------------------------------------------
/*
SELECT [dbo].[fn_StripSQLComments]('')
*/
----------------------------------------------------------------------------------------------------
BEGIN
     DECLARE @SQL_Code VARCHAR(MAX) = @CommentedSQLCode
     DECLARE @MAX_Length INTEGER = DATALENGTH(@SQL_Code)
     DECLARE @CNT_Char INTEGER = 0
     DECLARE @Char1 VARCHAR(1)
     DECLARE @Char2 VARCHAR(1)
     DECLARE @StringOpen BIT = 0
     DECLARE @UncommentedSQLCode VARCHAR(MAX) = @SQL_Code
     WHILE @CNT_Char < @MAX_Length
     BEGIN
        SET @Char1 = ''
        SET @Char2 = ''
        SET @Char1 = SUBSTRING(@SQL_Code,@CNT_Char,1)
        SET @Char2 = SUBSTRING(@SQL_Code,@CNT_Char + 1,1) 
        IF @Char1 = '''' IF @StringOpen = 1 SET @StringOpen = 0 ELSE SET @StringOpen = 1
        IF @Char1 = '-' ANd @Char2 = '-' AND @StringOpen = 0
        BEGIN
            SET @UncommentedSQLCode = LEFT(@SQL_Code, @CNT_Char - 1 )
            SET @CNT_Char = @MAX_Length
        END
        SET @CNT_Char = @CNT_Char + 1
     END
    RETURN @UncommentedSQLCode
END
GO
