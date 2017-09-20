Spillman/Ctree SQL Examples
===========================

Query Date Range
---------------

```sql
select "number",securid FROM lwmain where dtrepor BETWEEN '2016-01-30 00:00:00' and '2016-01-31 00:00:00';
```

Timestamp to Date Casting
-------------------------

```sql
select count(*),cast(towdate as date) as tow_on from vimain group by cast(towdate as date) order by tow_on desc;
```

Evidence with Float Quantity
----------------------------

```sql
select
"number", lctn, incino, item, pmodel, serial,meas,CAST(quant AS CHAR(10)) as qty
FROM evmain
WHERE addwhen > '1/1/2016'
AND status = 'ACT'
AND lctn in ('GB','G01','G02','G03','GS','SAFEA','SAFEB','NARC');
```

Hierarchy of Offense/Charge
---------------------------

Goal: Find highest offense.

```sql
select distinct
l."number",
o.offcode,
t.action
FROM lwmain l
JOIN lwoffs o ON o."number" = l."number"
JOIN tboff t ON o.offcode = t.abbr
WHERE l."number" like ' 160002%'
AND NOT EXISTS (SELECT 1 FROM lwoffs o1
  JOIN tboff t1 ON o1.offcode = t1.abbr
  WHERE o1."number" = l."number"
  AND t1.action > t.action
);
```

Goal: list offenses by rank.

```sql
select distinct
l."number",
s.statute,
t.action
FROM lwmain l
JOIN lwstatut s ON s."number" = l."number"
JOIN tblaw c ON c.abbr = s.statute
JOIN tboff t ON t.abbr = c.offense
WHERE l."number" = ' 16024520'
ORDER BY t.action DESC;

NUMBER       STATUTE                        ACTION
------       -------                        ------ 
 16024520    470 (D) PC FEL                     29
 16024520    484 I(C) PC FEL                    29
 16024520    11357 (A) HS MIS                   20
 16024520    11364 (A) HS                       16
 16024520    11350 (A) HS MIS                   14
 16024520    11377 (A) HS MIS                   14
 16024520    475 (A) PC FEL                      0
 16024520    529 (A)(3) PC FEL                   0
8 records selected
```

Goal: list charge codes by rank

```sql
select distinct
l."number",
o.offcode,
t.action
FROM lwmain l
JOIN lwoffs o ON o."number" = l."number"
JOIN tboff t ON o.offcode = t.abbr
WHERE l."number" = ' 16024520'
ORDER BY t.action DESC
;
```

List Arrests with name record
-----------------------------

Link by syinvolv

```sql
SELECT lawnum,
inmate,n."number" as name,counts,statute
FROM jloffens j
JOIN syinvolv i ON i.rec = j.num
JOIN nmmain n ON i.relrec = n."number"
WHERE i.typ = 750 and reltyp = 900
AND lawnum = ' 15091929'
;
```


Link by jlinmate

```sql
SELECT lawnum,
inmate,n."number" as name,counts,statute
FROM jloffens j
JOIN jlinmate i ON i."num" = j.inmate
JOIN nmmain n ON i.namenum = n."number"
AND lawnum = ' 15091929'
;
```
Last 8 days of Deleted lwsupl's
-------------------------------

```sql
SELECT usrid,"date",misc
FROM sylog
WHERE tablnam = 'lwsupl'
AND "mode" = 'D'
AND "date" > TIMESTAMPADD(SQL_TSI_DAY,-8,systime)
ORDER BY "date" desc;
```


Activity for a Month
--------------------

```sql
SELECT
l."number" as dr,
s.statute,
z."desc" as beat,
locatn,
address,
dtrepor,
ocurdt1,
ocurdt2,
ccode 
FROM lwmain l
JOIN lwstatut s ON l."number" = s."number"
JOIN tbzones z ON l.locatn = z.abbr
WHERE dtrepor BETWEEN '2016-03-01 00:00:00' AND '2016-04-01 00:00:00'
AND ccode IN ('6X','7X','8X')
ORDER BY statute,dr desc
;
```

Count of Statutes in 16-17 Law Incidents
----------------------------------------

```sql
SELECT * from (SELECT count(1) as cnt,o.statute 
FROM lwmain l 
JOIN lwstatut o ON o."number" = l."number" 
WHERE l."number" LIKE ' 16%' OR l."number" LIKE ' 16%' 
GROUP BY o.statute 
ORDER BY count(1) DESC
) s WHERE cnt > 20
;
```

Juvie Arrests
-------------

```sql
SELECT j.lawnum, 
         n.birthd, CONVERT(SQL_DATE,j."date") as chg_date,
         (CONVERT(SQL_DATE,j."date") - n.birthd)/365.25 as age
         FROM jloffens j 
         JOIN syinvolv i ON i.rec = j.num 
         JOIN nmmain n ON i.relrec = n."number" 
         WHERE i.typ = 750 
         AND reltyp = 900
         AND (CONVERT(SQL_DATE,j."date") - n.birthd)/365.25 < 18

```

Injunction Offenders with Involvements in last 90 days
-----------------------------------------------------

```sql
select rec,relship,"date",(TRIM(n.last)||', '||TRIM(n.first)) as name
FROM syinvolv i 
JOIN nmmain n ON i.relrec = n."number" 
AND i.reltyp = 900 
AND i."date" > CURRENT_DATE - 90
WHERE n."number" IN (SELECT namenum FROM somain WHERE type = 'INJ')
;
```

Names with Gang Alerts with Involvements in last 90 days
--------------------------------------------------------

```sql
SELECT TRIM(rec) as rec_num,
  TRIM(relship) as relship,
  TRIM(TO_CHAR(i."date",'DD/MM/YY') as "date",
  TRIM(TRIM(n.last)||', '||TRIM(n.first)) as name,
  TRIM(TO_CHAR(n.birthd,'DD/MM/YY')) as dob
FROM syinvolv i 
JOIN nmmain n ON i.relrec = n."number" 
AND i.reltyp = 900 
AND i."date" > CURRENT_DATE - 90
WHERE n."number" IN (SELECT "number" FROM nmalert WHERE code = 'GANG')
ORDER BY i."date" DESC
;
```

Counts of partitions, not complete
----------------------------------

```sql
SELECT
COUNT(*) as cnt,
TRIM(securid) as securid
from lwmain
WHERE securid like '"%'
AND LOWER(securid) NOT like '"cmplt'
GROUP BY TRIM(securid)
ORDER BY securid
```

Clean workflow for no report dispos
-----------------------------------

```sql
SELECT "number"
        FROM lwmain
        WHERE ccode = '2X'
        AND dispos <> '2X'
        AND NOT EXISTS (SELECT 1 FROM lwsupl WHERE "number" = lwmain."number")
        AND modwhen < TIMESTAMPADD(SQL_TSI_HOUR,-2,systime);
-- remove status lines
DELETE  FROM wfstat WHERE "number" IN (SELECT "number" FROM wfmain WHERE rkeyval in (SELECT "number" FROM lwmain  WHERE ccode = '2X'
        AND dispos <> '2X'
        AND NOT EXISTS (SELECT 1 FROM lwsupl WHERE "number" = lwmain."number")
        AND modwhen < TIMESTAMPADD(SQL_TSI_HOUR,-2,systime)
        ));
-- remove wfmain 
DELETE FROM wfmain WHERE rkeyval IN (SELECT "number" FROM lwmain  WHERE ccode = '2X'
        AND dispos <> '2X'
        AND NOT EXISTS (SELECT 1 FROM lwsupl WHERE "number" = lwmain."number")
        AND modwhen < TIMESTAMPADD(SQL_TSI_HOUR,-2,systime)
        );
-- set 2x dispos to '2x' for '2x' ccodes
UPDATE lwmain SET dispos = '2X' WHERE ccode = '2X' AND dispos <> '2X'
AND NOT EXISTS (SELECT 1 FROM lwsupl WHERE "number" = lwmain."number")
AND modwhen < TIMESTAMPADD(SQL_TSI_HOUR,-2,systime);
COMMIT;
```


