CREATE OR REPLACE FUNCTION HITDB2.tf_DelimitedRecordSet(
    v_Data_1 CLOB(1M), 
    v_Delimtator VARCHAR(12),
    v_Parameters VARCHAR(100) DEFAULT '')
RETURNS TABLE (RowID INTEGER, FieldData VARCHAR(2048))
SPECIFIC HITDB2.tf_DelimitedRecordSet
LANGUAGE SQL
----------------------------------------------------------------------------------------------------
-- Script Name    : tf_DelimitedRecordSet
-- DateTime       : 2020-01-13
-- Author         : Martin Scheepers
-- Purpose        : Convert a Delimited CLOB to a VARCHAR RecordSet Object
-- Ver            : 1.0
----------------------------------------------------------------------------------------------------
-- Changes        : 
----------------------------------------------------------------------------------------------------
/*
SELECT * FROM TABLE( HITDB2.tf_DelimitedRecordSet('abc,d,e,R,y,U,i,billy BOB,oo,oo,xx',',')) ;
SELECT * FROM TABLE( HITDB2.tf_DelimitedRecordSet('abc,d,e,R,y,U,i,billy BOB,oo,oo,xx',',','[LOWER]')) ;
SELECT * FROM TABLE( HITDB2.tf_DelimitedRecordSet('abc,d,e,R,y,U,i,billy BOB,oo,oo,xx',',','[UPPER][TRIM]')) ;
*/
----------------------------------------------------------------------------------------------------
BEGIN
    DECLARE vLength INTEGER DEFAULT 1;
    DECLARE vLocate INTEGER DEFAULT 0;
    DECLARE vLine VARCHAR(2048);
    DECLARE vRow INTEGER;
    DECLARE pUPPER SMALLINT DEFAULT 0;
    DECLARE pLOWER SMALLINT DEFAULT 0;
    DECLARE pTRIM SMALLINT DEFAULT 0;
    ----------------------------------------------------------------------------------------------------
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pUPPER FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%UPPER%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pLOWER FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%LOWER%';
    SELECT CASE WHEN IBMREQD = 'Y' THEN 1 ELSE 0 END INTO pTRIM FROM SYSIBM.SYSDUMMY1 WHERE v_Parameters LIKE '%TRIM%';
    ----------------------------------------------------------------------------------------------------
    SET vRow = 0;

    IF v_Data_1 IS NULL THEN
        RETURN;
    END IF;

    SET vLocate = LOCATE(v_Delimtator, v_Data_1);

    WHILE vLocate > 0 DO
        SET vLine = SUBSTR(v_Data_1, vLength, vLocate - vLength);
        IF pUPPER = 1 THEN SET vLine = UPPER(vLine); END IF;
        IF pLOWER = 1 THEN SET vLine = LOWER(vLine); END IF;
        IF pTRIM = 1 THEN SET vLine = TRIM(vLine); END IF;
        ----------------------------------------------------------------------------------------------------
        SET vRow = vRow + 1;
        PIPE (vRow, vLine);

        SET vLength = vLocate + LENGTH(v_Delimtator);
        SET vLocate = LOCATE(v_Delimtator, v_Data_1, vLocate + LENGTH(v_Delimtator));
    END WHILE;

    SET vLine = SUBSTR(v_Data_1, vLength, LENGTH(v_Data_1) - vLength+1);
    IF pUPPER = 1 THEN SET vLine = UPPER(vLine); END IF;
    IF pLOWER = 1 THEN SET vLine = LOWER(vLine); END IF;
    IF pTRIM = 1 THEN SET vLine = TRIM(vLine); END IF;
    ----------------------------------------------------------------------------------------------------
    SET vRow = vRow + 1;
    PIPE (vRow, vLine);
    RETURN;
END
@
