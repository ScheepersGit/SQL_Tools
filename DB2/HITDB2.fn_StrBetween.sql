CREATE OR REPLACE FUNCTION HITDB2.fn_StrBetween (
    vSourceData CLOB(1M)
    , vFindStart VARCHAR(200)
    , vFindEnd VARCHAR(200)
    , vOffset INTEGER
    , vStringNotFound CLOB(1M)
    )
RETURNS CLOB(1M)
SPECIFIC HITDB2.fn_StrBetween
LANGUAGE SQL
----------------------------------------------------------------------------------------------------
-- Script Name    : fn_StrBetween
-- DateTime       : 2020-01-13
-- Author         : Martin Scheepers
-- Purpose        : Returns a Portion of a CLOB Object between FindStart and FindEnd
-- Ver            : 1.0
----------------------------------------------------------------------------------------------------
-- Changes        : 
----------------------------------------------------------------------------------------------------
/*
SELECT HITDB2.fn_StrBetween('[[11-11],[12]##[13],[14],[18],[]**[18],[],[20]],[','##',NULL,1,NULL) FROM SYSIBM.SYSDUMMY1;
SELECT HITDB2.fn_StrBetween('[[11-11],[12]##[13],[14],[18],[]**[18],[],[20]],[','##','**',1,NULL) FROM SYSIBM.SYSDUMMY1;
SELECT HITDB2.fn_StrBetween('[[11-11],[12]##[13],[14],[18],[]**[18],[],[20]],[','','',1,'') FROM SYSIBM.SYSDUMMY1;
*/
----------------------------------------------------------------------------------------------------
BEGIN

    DECLARE vOUTPUT CLOB(1M);
    DECLARE viStart INTEGER DEFAULT 0;
    DECLARE viEnd INTEGER DEFAULT 0;
    DECLARE viLen INTEGER DEFAULT 0;

    SET vSourceData = COALESCE(vSourceData,'');
    SET vFindStart = COALESCE(vFindStart,'');
    SET vFindEnd = COALESCE(vFindEnd,'');
    SET vStringNotFound = COALESCE(vStringNotFound,'');

    SET vOUTPUT = vSourceData;
    SET viLen = LENGTH(vSourceData);
    IF COALESCE(vOffset,0) <= 0 THEN SET vOffset = 1; END IF;
 
    IF vFindStart = '' AND vFindEnd = '' THEN
        SET viStart = 0;
        SET viEnd = 0;
        SET vOUTPUT = CASE WHEN vStringNotFound = 'vvNULL' THEN NULL ELSE vStringNotFound END;
    ELSE
        IF vFindStart <> '' THEN
            SET viStart = LOCATE(vFindStart,vSourceData,vOffset);
            IF viStart > 0 THEN
                SET viStart = viStart + LENGTH(vFindStart);
                SET vOffset = viStart;
            END IF;
        ELSE
            SET viStart = 1;
        END IF;

        IF vFindEnd <> '' THEN
            SET viEnd = LOCATE(vFindEnd,vSourceData,vOffset);
            IF viEnd > viStart THEN
                SET viEnd = viEnd - viStart;
            END IF;
        ELSE
            SET viEnd = viLen - (viStart -1);
        END IF;

        IF viStart > 0 AND viEnd > 0 THEN
            SET vOUTPUT = SUBSTR(vSourceData,viStart,viEnd);
        ELSE
            SET vOUTPUT = CASE WHEN vStringNotFound = 'vvNULL' THEN NULL ELSE vStringNotFound END;
        END IF;

    END IF;

    ---------------------------------------- << RETURN DATA >> ----------------------------------------
    RETURN vOUTPUT;--  || '-->' || vistart || viend;
END
@