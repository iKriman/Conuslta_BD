-- Consulta BD trabajo sumativo 2 Ignacio Kriman

-- CASO 1: Reporteria de Asesorias

SELECT
    -- nombre completo del profesional
    p.id_profesional AS "ID",
    p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre AS "PROFESIONAL",
    
    -- usamos un CASE/WHEN para filtrar las filas con el codigo sector 3
    -- si la fila pertenece se le asigna 1 (true), si no, 0 (false)
    -- al sumar con SUM, contaremos cuantas filas tienen el codigo 3
    SUM(CASE WHEN e.cod_sector = 3 THEN 1 ELSE 0 END) AS "NRO ASESORIA BANCA",
    
    -- generamos el formateo de los montos de dinero
    '$' || TO_CHAR(ROUND(SUM(CASE WHEN e.cod_sector = 3 THEN a.honorario ELSE 0 END)),
    'FM999G999G999' -- fm = fill mode para no dejar espacios en blanco
    ) AS "MONTO_TOTAL_BANCA",
    
    SUM(CASE WHEN e.cod_sector = 4 THEN 1 ELSE 0 END) AS "NRO ASESORIA RETAIL",
    
    '$' || TO_CHAR(
    ROUND(SUM(CASE WHEN e.cod_sector = 4 THEN a.honorario ELSE 0 END)),
    'FM999G999G999' 
    ) AS "MONTO_TOTAL_RETAIL",
    
    SUM(CASE WHEN e.cod_sector IN (3, 4) THEN 1 ELSE 0 END) AS "TOTAL ASESORIAS",
    
    '$' || TO_CHAR(
        ROUND(SUM(CASE WHEN e.cod_sector IN (3, 4) THEN a.honorario ELSE 0 END)),
        'FM999G999G999'
    ) AS "TOTAL HONORARIOS"
    
    FROM profesional p
    -- utilizamos los JOIN para obtener las filas de asesorias 
    JOIN asesoria a ON p.id_profesional = a.id_profesional
    -- con este JOIN rescatamos las filas de retail o banca
    JOIN empresa e ON a.cod_empresa = e.cod_empresa
    -- seleccionamos los profesionales que sean sector 3 o 4
    WHERE p.id_profesional IN (
    SELECT a1.id_profesional FROM asesoria a1
    JOIN empresa e1 ON a1.cod_empresa = e1.cod_empresa WHERE e1.cod_sector = 3
    INTERSECT -- nos aseguramos de obtener las filas de los sectores correspondientes
    SELECT a2.id_profesional FROM asesoria a2
    JOIN empresa e2 ON a2.cod_empresa = e2.cod_empresa WHERE e2.cod_sector = 4
    )
    GROUP BY p.id_profesional, p.appaterno, p.apmaterno, p.nombre
    ORDER BY "ID" ASC;

-- CASO 2: Resumen de Honorarios

-- drop opcional para asegurar funcionamiento entre equipos
DROP TABLE REPORTE_MES;

-- creamos la tabla para el reporte
CREATE TABLE REPORTE_MES AS

SELECT
    -- nombramos nuestras columnas 
    p.id_profesional AS "ID_PROF",
    p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre AS "NOMBRE_COMPLETO",
    pr.nombre_profesion AS "NOMBRE_PROFESION",
    c.nom_comuna AS "NOM_COMUNA",
    
    -- contamos el numero de asesorias que cada profesional tiene
    COUNT(*) AS "NRO_ASESORIAS",
    
    -- formateamos los resultados en dinero
    '$' || TO_CHAR(ROUND(SUM(a.honorario)),'FM999G999G999') AS "MONTO_TOTAL_HONORARIOS",
    
    '$' || TO_CHAR(ROUND(AVG(a.honorario)),'FM999G999G999') AS "PROMEDIO_HONORARIO",
    
    '$' || TO_CHAR(ROUND(MIN(a.honorario)),'FM999G999G999') AS "HONORARIO_MINIMO",
    
    '$' || TO_CHAR(ROUND(MAX(a.honorario)),'FM999G999G999') AS "HONORARIO_MAXIMO"

FROM profesional p

    JOIN asesoria a ON p.id_profesional = a.id_profesional
    JOIN empresa e ON a.cod_empresa = e.cod_empresa
    JOIN profesion pr ON p.cod_profesion = pr.cod_profesion
    JOIN comuna c ON p.cod_comuna = c.cod_comuna
    
WHERE -- fijamos la linea de tiempo del reporte
        EXTRACT(MONTH FROM a.fin_asesoria) = 4
    AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM add_months(sysdate, -12)) 
    
GROUP BY
    p.id_profesional,
    p.appaterno,
    p.apmaterno,
    p.nombre,
    pr.nombre_profesion,
    c.nom_comuna
ORDER BY
    "ID_PROF" ASC;
    
-- luego de generar el reporte, podemos consultarlo desde una simple consulta SELECT    
SELECT * FROM REPORTE_MES;



-- CASO 3: Modificacion de Honorarios

-- generamos un reporte previo para visualizar el sueldo actual de los profesionales
SELECT 
    p.id_profesional AS "ID_PROFESIONAL",
    p.numrun_prof AS "NUMRUN_PROF",
    '$' || TO_CHAR(ROUND(SUM(a.honorario)),'FM999G999G999') AS "HONORARIO",
    '$' || TO_CHAR(p.sueldo, 'FM999G999G999') AS "SUELDO"
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
WHERE EXTRACT(MONTH FROM a.fin_asesoria) = 3
  AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))  
GROUP BY p.id_profesional, p.sueldo, P.numrun_prof
ORDER BY p.id_profesional;

-- luego generamos la actualizacion del sueldo dependiendo del desempeno, se aumenta un 10% o 15%
UPDATE profesional p
SET p.sueldo = ROUND(
    p.sueldo * 
    CASE 
        WHEN (
            SELECT SUM(a.honorario)
            FROM asesoria a
            WHERE a.id_profesional = p.id_profesional
              AND EXTRACT(MONTH FROM a.fin_asesoria) = 3
              AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
        ) < 1000000 THEN 1.10
        ELSE 1.15
    END
)
WHERE EXISTS (
    SELECT 1
    FROM asesoria a
    WHERE a.id_profesional = p.id_profesional
      AND EXTRACT(MONTH FROM a.fin_asesoria) = 3
      AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
);

COMMIT;


SELECT 
    p.id_profesional AS "ID_PROFESIONAL",
    p.numrun_prof AS "NUMRUN_PROF",                                         
    '$' || TO_CHAR(ROUND(SUM(a.honorario)),'FM999G999G999') AS "HONORARIO",
    '$' || TO_CHAR(p.sueldo, 'FM999G999G999') AS "SUELDO"
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
WHERE EXTRACT(MONTH FROM a.fin_asesoria) = 3
  AND EXTRACT(YEAR FROM a.fin_asesoria) = EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
GROUP BY p.id_profesional, p.sueldo, p.numrun_prof 
ORDER BY p.id_profesional;