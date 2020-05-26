CREATE OR REPLACE PROCEDURE HITDB2.p_DDL_Procedure (
	IN v_ObjectName VARCHAR(200), 
	IN v_Parameters VARCHAR(100) DEFAULT '')
SPECIFIC HITDB2.p_DDL_Procedure
RESULT SETS 1
MODIFIES SQL DATA
NOT DETERMINISTIC
LANGUAGE SQL EXTERNAL ACTION
INHERIT SPECIAL REGISTERS
----------------------------------------------------------------------------------------------------
-- Script Name    : p_DDL_Procedure
-- DateTime       : 2020-01-13
-- Author         : Martin Scheepers
-- Purpose        : Extract a SQL Object DDL
-- Ver            : 1.0
----------------------------------------------------------------------------------------------------
-- Changes        : 
----------------------------------------------------------------------------------------------------
/*
CALL HITDB2.p_DDL_Procedure('HITDB2.p_DDL_Procedure','[UPPER][TRIM][GCR][WSR][CBR]');
CALL HITDB2.p_DDL_Procedure('HITDB2.p_DDL_Procedure','[UPPER][WSR]');
SELECT 
'CALL HITDB2.p_DDL_Procedure(''' || TRIM(PROCSCHEMA) || '.' || TRIM(PROCNAME) || ''',''[UPPER]'');',
'db2 "CALL HITDB2.p_DDL_Procedure(''' || TRIM(PROCSCHEMA) || '.' || TRIM(PROCNAME) || ''',''[UPPER]'');" -r /LOG/Procedures/' || TRIM(PROCSCHEMA) || '.' || TRIM(PROCNAME) || '.sql'
FROM SYSCAT.PROCEDURES
WHERE UPPER(TRIM(PROCSCHEMA)) IN ('HITDB2')

   BEGIN
		DECLARE CUR_DEBUG CURSOR WITH RETURN FOR
		SELECT 
			vTargetSchema as SH,vTargetObject as OB,vTargetDefinitionText as DEF
		 FROM SYSIBM.SYSDUMMY1;
		
		OPEN CUR_DEBUG;
	END;
	
	
*/
----------------------------------------------------------------------------------------------------
BEGIN
    DECLARE vTargetSRV NVARCHAR(255);
    DECLARE vTargetDB NVARCHAR(255);
    DECLARE vTargetSchema NVARCHAR(255);
    DECLARE vTargetObject VARCHAR(255);
    DECLARE vTargetDefinitionText CLOB(1M);
    DECLARE vTAB VARCHAR(5);
    DECLARE vCR VARCHAR(5); 
    DECLARE vLF VARCHAR(5);
    DECLARE vCRLF VARCHAR(5);
    DECLARE vToken VARCHAR(30);
    DECLARE vParameters VARCHAR(100);

    DECLARE pUPPER SMALLINT DEFAULT 0; --Convert Output to all Upper Case
    DECLARE pLOWER SMALLINT DEFAULT 0; --Convert Output to all Lower Case
    DECLARE pTRIM SMALLINT DEFAULT 0;  --Trim All Spaces from Both ends of all Lines in output
    DECLARE pGCR SMALLINT DEFAULT 0;   --Remove GreenCode (Comment) Lines From output
    DECLARE pCBR SMALLINT DEFAULT 0;   --Remove Comment Blocks From output
    DECLARE pWSR SMALLINT DEFAULT 0;   --Remove Whitespace Lines From output

    DECLARE vLoopSafe INTEGER DEFAULT 0;
    DECLARE vDoubleSpace SMALLINT DEFAULT 1;
    DECLARE vCommentBlock CLOB(1M);
    DECLARE vTempText CLOB(1M);

    DECLARE GLOBAL TEMPORARY TABLE TT_DEFINITION
	(
	    RowNum INTEGER,
	    ReturnData VARCHAR(2048)
	) ON COMMIT PRESERVE ROWS NOT LOGGED WITH REPLACE;
    ----------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pUPPER FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%UPPER%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pLOWER FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%LOWER%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pTRIM FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%TRIM%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pGCR FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%GCR%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pCBR FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%CBR%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pWSR FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%WSR%';
    ----------------------------------------------------------------------------------------------------
	SET vTAB = CHR(9);
	SET vCR = CHR(13);
	SET vLF = CHR(10);
    SET vCRLF = vCR || vLF;
    SET vToken = '!' || CHR(67) || CHR(82) || CHR(76) || CHR(70) || '!';
    
    SET vTargetObject = v_ObjectName;
    SET vTargetObject = REPLACE(REPLACE(vTargetObject,']',''),'[','');
    SET vTargetSchema = (SELECT HITDB2.fn_StrBetween(vTargetObject,NULL,'.',1,'HITDB2') FROM SYSIBM.SYSDUMMY1);
    SET vTargetObject = (SELECT HITDB2.fn_StrBetween(vTargetObject,'.',NULL,1,vTargetObject) FROM SYSIBM.SYSDUMMY1);
	SET vTargetSchema = COALESCE(TRIM(vTargetSchema),'HITDB2');
	SET vTargetObject = COALESCE(TRIM(vTargetObject),'NONE');
	
    SELECT TEXT INTO vTargetDefinitionText
    FROM SYSCAT.PROCEDURES
    WHERE TRIM(UPPER(PROCNAME)) = TRIM(UPPER(vTargetObject))
        AND TRIM(UPPER(PROCSCHEMA)) = TRIM(UPPER(vTargetSchema));

    SET vTargetDefinitionText = REPLACE(vTargetDefinitionText,vTAB, SPACE(4));
    SET vTargetDefinitionText = REPLACE(REPLACE(REPLACE(vTargetDefinitionText, vCRLF, vToken), vCR, vToken), vLF, vToken);

    IF pCBR = 1 THEN
        SET vLoopSafe = 0;
		SET vCommentBlock = '';
		
        IF ((LOCATE('/' || '*',vTargetDefinitionText) > 0) AND (LOCATE('*' || '/',vTargetDefinitionText) > 0)) THEN 
        	SET vCommentBlock = 'BEGIN'; 
   
	        WHILE ((COALESCE(vCommentBlock,'') <> '') AND (vLoopSafe < 10)) DO
	            SET vCommentBlock = '';
	            SET vCommentBlock = (SELECT HITDB2.fn_StrBetween(vTargetDefinitionText,'/' || '*','*' || '/',1,'') FROM SYSIBM.SYSDUMMY1);
	            SET vTargetDefinitionText = REPLACE(vTargetDefinitionText,COALESCE('/' || '*' || vCommentBlock || '*' || '/', ''),'');
	            SET vLoopSafe = vLoopSafe + 1; 
	        END WHILE;
        END IF;
        
    END IF;

    IF pWSR = 1 THEN
        SET vTargetDefinitionText = REPLACE(vTargetDefinitionText,SPACE(4),vTAB);

        SET vLoopSafe = 0;
        SET vDoubleSpace = LOCATE(SPACE(2),vTargetDefinitionText);
        
        WHILE ((vDoubleSpace > 0) AND (vLoopSafe < 50000)) DO 
            SET vTargetDefinitionText = REPLACE(vTargetDefinitionText,SPACE(2),SPACE(1));
            SET vDoubleSpace = LOCATE(SPACE(2),vTargetDefinitionText);
            SET vLoopSafe = vLoopSafe + 1;
        END WHILE;--

        SET vTargetDefinitionText = REPLACE(vTargetDefinitionText,vTAB,SPACE(4));
    END If;

    SET vParameters = '';
    IF pUPPER = 1 THEN SET vParameters = vParameters || '[UPPER]'; END IF;
    IF pLOWER = 1 THEN SET vParameters = vParameters || '[LOWER]'; END IF;
    IF pTRIM = 1 THEN SET vParameters = vParameters || '[TRIM]'; END IF;
 
    INSERT INTO SESSION.TT_DEFINITION(RowNum, ReturnData)
    SELECT RowID, FIELDDATA FROM TABLE( HITDB2.tf_DelimitedRecordSet(vTargetDefinitionText, vToken, vParameters));

    IF pGCR = 1 THEN
        DELETE fROM SESSION.TT_DEFINITION WHERE (COALESCE(REPLACE(ReturnData,SPACE(1),''), '') LIKE '--%');
        UPDATE SESSION.TT_DEFINITION SET ReturnData = LEFT(ReturnData, LOCATE('--',ReturnData )-1) WHERE LOCATE('--',ReturnData ) > 1;
    END IF;

    IF pTRIM = 1 THEN
        UPDATE SESSION.TT_DEFINITION SET ReturnData = TRIM(ReturnData);
    END IF;

    IF pWSR = 1 THEN
/*	
		UPDATE SESSION.TT_DEFINITION SET ReturnData = REPLACE(ReturnData,SPACE(4),vTAB);
		SET vLoopSafe = 0;
		WHILE (EXISTS(SELECT 'X' FROM SESSION.TT_DEFINITION WHERE LOCATE(SPACE(2),ReturnData) > 0) AND (vLoopSafe < 50000))
			UPDATE SESSION.TT_DEFINITION SET ReturnData = REPLACE(ReturnData,SPACE(2),SPACE(1));
			SET vLoopSafe = vLoopSafe + 1;
		END WHILE;
		UPDATE SESSION.TT_DEFINITION SET ReturnData = REPLACE(ReturnData,SPACE(2),SPACE(1));
		UPDATE SESSION.TT_DEFINITION SET ReturnData = REPLACE(ReturnData,vTAB,SPACE(4));
*/		
        DELETE fROM SESSION.TT_DEFINITION WHERE (COALESCE(REPLACE(ReturnData,SPACE(1),''), '') = '');
    END IF;

    --***************************************************************************************
	-- Output
	--***************************************************************************************
	BEGIN
		DECLARE CUR_RPT_OUTPUT CURSOR WITH RETURN FOR
		SELECT 
			RTRIM(ReturnData) AS ReturnData
		FROM SESSION.TT_DEFINITION
		ORDER BY RowNum;
		
		OPEN CUR_RPT_OUTPUT;
	END;

END
@

