-- EXAMEN FINAL TRANSVERSAL IGNACIO KRIMAN
/* creacion de usuarios (con otorgacion de privilegios) con responsabilidades
   fijas para el calculo y vista.*/ 
   
--==============================================================================--   
                               --ADMIN--
--==============================================================================--

SHOW USER;

DROP USER PRY2205_EFT CASCADE;
DROP USER PRY2205_EFT_DES CASCADE;
DROP USER PRY2205_EFT_CON CASCADE;
-- creacion de usuarios con politicas de contraseñas
CREATE USER PRY2205_EFT IDENTIFIED BY "Admin2024_EFT"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;
CREATE USER PRY2205_EFT_DES IDENTIFIED BY "Dev2024_Tasks"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;
CREATE USER PRY2205_EFT_CON IDENTIFIED BY "Consult_2024"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;
-- asignación de cuota 
ALTER USER PRY2205_EFT QUOTA 10M ON USERS;
-- Asignación de privilegios y roles (principio de menor privilegio)
-- Duenio: control total 
GRANT CONNECT, RESOURCE TO PRY2205_EFT;
GRANT CREATE VIEW, CREATE INDEX, CREATE SEQUENCE, CREATE PUBLIC SYNONYM TO PRY2205_EFT;
-- Desarrollador: Solo sesion y vistas para manipular datos 
GRANT CREATE SESSION, CREATE VIEW TO PRY2205_EFT_DES;
-- Consultor: Solo sesion para ver informes
GRANT CREATE SESSION TO PRY2205_EFT_CON;


-- acceso directo a la tabla del dueño
CREATE SYNONYM SYN_CARTOLA FOR PRY2205_EFT.CARTOLA_PROFESIONALES;

--==============================================================================-- 
                               --DUENIO--
--==============================================================================--

SHOW USER;

-- sinonimo para la vista de empresas
CREATE PUBLIC SYNONYM SYN_VISTA_EMPRESAS FOR PRY2205_EFT.VW_EMPRESAS_ASESORADAS;
-- sinonimo para la tabla de cartola 
CREATE PUBLIC SYNONYM SYN_CARTOLA_INFORME FOR PRY2205_EFT.CARTOLA_PROFESIONALES;

-- damos permiso a los usuarios
GRANT SELECT ON PROFESIONAL TO PRY2205_EFT_DES, PRY2205_EFT_CON;
GRANT SELECT ON ISAPRE TO PRY2205_EFT_DES;
GRANT SELECT ON TIPO_CONTRATO TO PRY2205_EFT_DES;
GRANT SELECT ON RANGOS_SUELDOS TO PRY2205_EFT_DES;
GRANT SELECT ON PROFESION TO PRY2205_EFT_DES;
GRANT INSERT, SELECT ON CARTOLA_PROFESIONALES TO PRY2205_EFT_DES;
GRANT SELECT ON CARTOLA_PROFESIONALES TO PRY2205_EFT_CON;
GRANT SELECT ON EMPRESA TO PRY2205_EFT_CON;
GRANT SELECT ON ASESORIA TO PRY2205_EFT_CON;
GRANT SELECT ON VW_EMPRESAS_ASESORADAS TO PRY2205_EFT_CON;
GRANT SELECT ON VW_EMPRESAS_ASESORADAS TO PRY2205_EFT_DES;

-- caso 3.1: Vista de optimizacion de empresas
/*creamos una vista para ver la lista de empresas, anios de antiguedad y mas, esto con el fin de ver
  que tipo de beneficio tienen.*/
CREATE OR REPLACE VIEW VW_EMPRESAS_ASESORADAS AS
SELECT 
    -- Formato RUT (99.999.999-X)
    TO_CHAR(e.RUT_EMPRESA, '99G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''') || '-' || e.DV_EMPRESA AS "RUT EMPRESA",
    e.NOMEMPRESA AS "NOMBRE EMPRESA",
    '19%' AS "IVA",
    TRUNC(MONTHS_BETWEEN(SYSDATE, e.FECHA_INICIACION_ACTIVIDADES) / 12) AS "ANIOS_EXISTENCIA",
    COUNT(a.IDEMPRESA) AS "TOTAL_ASESORIAS_ANUALES",
    -- Formato Dinero: $999.999.999
    CASE 
        WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, e.FECHA_INICIACION_ACTIVIDADES) / 12) >= 2 
        THEN TO_CHAR(ROUND(e.IVA_DECLARADO * 0.05), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''')
        ELSE '$0' 
    END AS "DEVOLUCION_IVA",
    CASE 
        WHEN COUNT(a.IDEMPRESA) >= 3 THEN 'Gran Cliente'
        WHEN COUNT(a.IDEMPRESA) BETWEEN 1 AND 2 THEN 'Cliente Frecuente'
        ELSE 'Cliente Nuevo'
    END AS "TIPO_CLIENTE",
    CASE 
        WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, e.FECHA_INICIACION_ACTIVIDADES) / 12) >= 10 THEN 'Asesoría Gratis'
        WHEN COUNT(a.IDEMPRESA) = 0 THEN 'Captar Cliente'
        ELSE 'Sin Beneficio'
    END AS "CORRESPONDE"
FROM EMPRESA e
LEFT JOIN ASESORIA a ON e.IDEMPRESA = a.IDEMPRESA
GROUP BY 
    e.RUT_EMPRESA, 
    e.DV_EMPRESA, 
    e.NOMEMPRESA, 
    e.IVA_DECLARADO, 
    e.FECHA_INICIACION_ACTIVIDADES;

-- Caso 3.2: indices para mejorar rendimiento
CREATE INDEX IDX_ASESORIA_FECHAS ON ASESORIA(inicio, fin);

--==============================================================================-- 
                          --DESARROLADOR--
--==============================================================================--

SHOW USER;

-- calculo de remuneracion. logica de bonos segun el tipo de contrato especificado en la pauta.

-- limpieza de datos
TRUNCATE TABLE PRY2205_EFT.CARTOLA_PROFESIONALES;


-- Inserción masiva a través del sinónimo privado SYN_CARTOLA
INSERT INTO SYN_CARTOLA (
    RUT_PROFESIONAL, NOMBRE_PROFESIONAL, PROFESION, ISAPRE, SUELDO_BASE, 
    PORC_COMISION_PROFESIONAL, VALOR_TOTAL_COMISION, PORCENTATE_HONORARIO, 
    BONO_MOVILIZACION, TOTAL_PAGAR
)
SELECT 
    P.RUTPROF,
    P.NOMPRO || ' ' || P.APPPRO,
    PR.NOMPROFESION,
    I.NOMISAPRE,
    P.SUELDO,
    P.COMISION * 100,
    ROUND(P.SUELDO * NVL(P.COMISION, 0)),
    ROUND(P.SUELDO * (R.HONOR_PCT / 100)),
    -- logica de bono de movilicacion 
    CASE 
        WHEN TC.NOM_TIPO_CONTRATO = 'Indefinido Jornada Completa' THEN 150000
        WHEN TC.NOM_TIPO_CONTRATO = 'Indefinido Jornada Parcial' THEN 120000
        WHEN TC.NOM_TIPO_CONTRATO = 'Plazo fijo' THEN 60000
        WHEN TC.NOM_TIPO_CONTRATO = 'Honorarios' THEN 50000
        ELSE TC.INCENTIVO -- Respaldo en caso de otros tipos
    END,
    -- calculo final
    ROUND(
        P.SUELDO + 
        (P.SUELDO * NVL(P.COMISION, 0)) + 
        (P.SUELDO * (R.HONOR_PCT / 100)) + 
        (CASE 
            WHEN TC.NOM_TIPO_CONTRATO = 'Indefinido Jornada Completa' THEN 150000
            WHEN TC.NOM_TIPO_CONTRATO = 'Indefinido Jornada Parcial' THEN 120000
            WHEN TC.NOM_TIPO_CONTRATO = 'Plazo fijo' THEN 60000
            WHEN TC.NOM_TIPO_CONTRATO = 'Honorarios' THEN 50000
            ELSE TC.INCENTIVO 
         END)
    )
FROM PRY2205_EFT.PROFESIONAL P
-- utilizamos varios join para incorporar datos entre tablas
-- en especial el rango de min/max de los sueldos
JOIN PRY2205_EFT.PROFESION PR ON P.IDPROFESION = PR.IDPROFESION
JOIN PRY2205_EFT.ISAPRE I ON P.IDISAPRE = I.IDISAPRE
JOIN PRY2205_EFT.TIPO_CONTRATO TC ON P.ID_TIPO_CONTRATO = TC.ID_TIPO_CONTRATO
JOIN PRY2205_EFT.RANGOS_SUELDOS R ON P.SUELDO BETWEEN R.MIN_SUELDO AND R.MAX_SUELDO;

COMMIT;

--==============================================================================-- 
                               --CONSULTADOR--
--==============================================================================--

SHOW USER;

/* con el usuario consultor podemos ver tanto el view como el informe. este usuario
   solo puede ver mas no cambiar nada ni de las tablas o el codigo */

-- Ver el informe de remuneraciones calculado por el Desarrollador
SELECT * FROM SYN_CARTOLA;

-- Ver el resumen de empresas de la Vista del Dueño
SELECT * FROM SYN_VISTA_EMPRESAS;
