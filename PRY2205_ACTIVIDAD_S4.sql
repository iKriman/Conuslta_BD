
-- Caso 1: Listado de Trabajadores


SELECT
    (CASE 
        WHEN LENGTH(TRIM(T.NUMRUT)) >= 9 OR T.NUMRUT >= 10000000 THEN
            SUBSTR(TO_CHAR(T.NUMRUT), 1, 2) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 3, 3) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 6, 3) || '-' || SUBSTR(TO_CHAR(T.NUMRUT), 9, 1)
        WHEN LENGTH(TRIM(T.NUMRUT)) = 8 THEN
            SUBSTR(TO_CHAR(T.NUMRUT), 1, 1) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 2, 3) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 5, 3) || '-' || SUBSTR(TO_CHAR(T.NUMRUT), 8, 1)
        ELSE 
            TO_CHAR(T.NUMRUT) 
    END) AS "RUT trabajador",
    UPPER(T.NOMBRE || ' ' || T.APPATERNO || ' ' || T.APMATERNO) AS "Nombre Completo Trabajador", 
    TT.DESC_CATEGORIA AS "Tipo Trabajador",
    C.NOMBRE_CIUDAD AS "Ciudad Trabajador",
    '$' || TO_CHAR(ROUND(T.SUELDO_BASE, 0), 'FM9G999G999') AS "Sueldo Base"
FROM
    TRABAJADOR T
    INNER JOIN COMUNA_CIUDAD C  
        ON T.ID_CIUDAD = C.ID_CIUDAD
    INNER JOIN TIPO_TRABAJADOR TT 
        ON T.ID_CATEGORIA_T = TT.ID_CATEGORIA
WHERE
    T.SUELDO_BASE BETWEEN 650000 AND 3000000
ORDER BY
    "Ciudad Trabajador" DESC,
    T.SUELDO_BASE ASC;



-- Caso 2: Listado Cajeros

SELECT
   (CASE 
        WHEN LENGTH(TRIM(T.NUMRUT)) >= 9 OR T.NUMRUT >= 10000000 THEN
            SUBSTR(TO_CHAR(T.NUMRUT), 1, 2) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 3, 3) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 6, 3) || '-' || SUBSTR(TO_CHAR(T.NUMRUT), 9, 1)
        WHEN LENGTH(TRIM(T.NUMRUT)) = 8 THEN
            SUBSTR(TO_CHAR(T.NUMRUT), 1, 1) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 2, 3) || '.' || SUBSTR(TO_CHAR(T.NUMRUT), 5, 3) || '-' || SUBSTR(TO_CHAR(T.NUMRUT), 8, 1)
        ELSE 
            TO_CHAR(T.NUMRUT) 
    END) AS "RUT Cajero",

    INITCAP(T.NOMBRE || ' ' || T.APPATERNO || ' ' || T.APMATERNO) AS "Nombre Cajero",

    TT.DESC_CATEGORIA AS "Tipo Trabajador",

    C.NOMBRE_CIUDAD AS "Comuna Trabajador",

    COUNT(TK.NRO_TICKET) AS "Cantidad Tickets",

    '$' || TO_CHAR(SUM(TK.MONTO_TICKET), 'FM9G999G999') AS "Total Vendido",

    '$' || TO_CHAR(NVL(SUM(CT.VALOR_COMISION), 0), 'FM9G999G999') AS "Comisión Total"
FROM TRABAJADOR T
    INNER JOIN TIPO_TRABAJADOR TT 
        ON T.ID_CATEGORIA_T = TT.ID_CATEGORIA
    INNER JOIN COMUNA_CIUDAD C 
        ON T.ID_CIUDAD = C.ID_CIUDAD
    LEFT JOIN TICKETS_CONCIERTO TK 
        ON T.NUMRUT = TK.NUMRUT_T
    LEFT JOIN COMISIONES_TICKET CT 
        ON TK.NRO_TICKET = CT.NRO_TICKET

WHERE
    TT.ID_CATEGORIA = 3  

GROUP BY
    T.NUMRUT, T.DVRUT, T.NOMBRE, T.APPATERNO, T.APMATERNO,
    TT.DESC_CATEGORIA,
    C.NOMBRE_CIUDAD

HAVING
    SUM(NVL(TK.MONTO_TICKET, 0)) > 50000 

ORDER BY
    SUM(TK.MONTO_TICKET) DESC;  



-- Caso 3: Listado de Bonificaciones

SELECT
    (CASE 
        WHEN LENGTH(TRIM(T.NUMRUT)) >= 9 OR T.NUMRUT >= 10000000 THEN
            SUBSTR(TO_CHAR(T.NUMRUT),1,2) || '.' || SUBSTR(TO_CHAR(T.NUMRUT),3,3) || '.' ||
            SUBSTR(TO_CHAR(T.NUMRUT),6,3) || '-' || T.DVRUT
        WHEN LENGTH(TRIM(T.NUMRUT)) = 8 THEN
            SUBSTR(TO_CHAR(T.NUMRUT),1,1) || '.' || SUBSTR(TO_CHAR(T.NUMRUT),2,3) || '.' ||
            SUBSTR(TO_CHAR(T.NUMRUT),5,3) || '-' || T.DVRUT
        ELSE
            TO_CHAR(T.NUMRUT) || '-' || T.DVRUT
    END) AS "RUT Trabajador",

    INITCAP(T.NOMBRE || ' ' || T.APPATERNO || ' ' || T.APMATERNO) AS "Trabajador Nombre",

    TO_CHAR(T.FECING, 'YYYY') AS "Año Ingreso",

    TRUNC(MONTHS_BETWEEN(SYSDATE, T.FECING) / 12) AS "Años Antiguedad",

    NVL(CF.NUM_CARGAS, 0) AS "Num. Cargas Familiares",

    I.NOMBRE_ISAPRE AS "Sistema Salud",

    '$' || TO_CHAR(ROUND(T.SUELDO_BASE,0), 'FM9G999G999') AS "Sueldo Base",

    CASE WHEN UPPER(I.NOMBRE_ISAPRE) = 'FONASA'
         THEN '$' || TO_CHAR(ROUND(T.SUELDO_BASE * 0.01,0), 'FM9G999G999')
         ELSE '$0'
    END AS "Bono Fonasa",

    '$' || TO_CHAR(ROUND(
          T.SUELDO_BASE *
          CASE WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, T.FECING)/12) <= 10 THEN 0.10 ELSE 0.15 END
        ,0), 'FM9G999G999') AS "Bono Antiguedad",

    A.NOMBRE_AFP AS "Nombre AFP",

    EC.DESC_ESTCIVIL AS "Estado Civil"

FROM trabajador T

LEFT JOIN (
    SELECT numrut_t, COUNT(*) AS num_cargas
    FROM asignacion_familiar
    GROUP BY numrut_t
) CF ON CF.numrut_t = T.numrut

LEFT JOIN isapre I ON T.cod_isapre = I.cod_isapre
LEFT JOIN afp   A ON T.cod_afp    = A.cod_afp

LEFT JOIN (
    SELECT numrut_t, id_estcivil_est
    FROM (
        SELECT numrut_t, id_estcivil_est, fecini_estcivil,
               ROW_NUMBER() OVER (PARTITION BY numrut_t ORDER BY fecini_estcivil DESC) rn
        FROM est_civil
        WHERE fecter_estcivil IS NULL OR fecter_estcivil > SYSDATE
    )
    WHERE rn = 1
) EC_ACT ON EC_ACT.numrut_t = T.numrut

LEFT JOIN estado_civil EC ON EC.id_estcivil = EC_ACT.id_estcivil_est

WHERE EXISTS (
    SELECT 1
    FROM est_civil E
    WHERE E.numrut_t = T.numrut
      AND (E.fecter_estcivil IS NULL OR E.fecter_estcivil > SYSDATE)
)

ORDER BY T.numrut ASC;



