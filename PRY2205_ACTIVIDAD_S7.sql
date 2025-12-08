-- caso 1:

INSERT INTO DETALLE_BONIFICACIONES_TRABAJADOR (
    num,
    rut,
    nombre_trabajador,
    sueldo_base,
    num_ticket,
    direccion,
    sistema_salud,
    monto,
    bonif_x_ticket,
    simulacion_x_ticket,
    simulacion_antiguedad
)
SELECT
  
    seq_det_bonif.NEXTVAL AS num,
    t.numrut || '-' || t.dvrut AS rut,
    INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno) || ' ' || INITCAP(t.apmaterno) AS nombre_trabajador,
    TO_CHAR(t.sueldo_base, 'FM9G999G990') AS sueldo_base,
    NVL(TO_CHAR(mt.nro_ticket), 'No hay info') AS num_ticket,
    t.direccion AS direccion,
    a.nombre_afp || ' ' || i.nombre_isapre AS sistema_salud,
    NVL(TO_CHAR(mt.max_monto, 'FM9G999G990'), 'No hay info') AS monto,
    NVL(TO_CHAR(
        ROUND(
            CASE
                WHEN mt.max_monto > 100000 THEN mt.max_monto * 0.07 
                WHEN mt.max_monto > 50000 AND mt.max_monto <= 100000 THEN mt.max_monto * 0.05 
                ELSE 0
            END
        ), 'FM9G999G990'
    ), 'No hay info') AS bonif_x_ticket,
    TO_CHAR(
        ROUND(t.sueldo_base +
            CASE
                WHEN mt.max_monto > 100000 THEN mt.max_monto * 0.07
                WHEN mt.max_monto > 50000 AND mt.max_monto <= 100000 THEN mt.max_monto * 0.05
                ELSE 0
            END
        ), 'FM9G999G990'
    ) AS simulacion_x_ticket,
    TO_CHAR(
        ROUND(t.sueldo_base * (1 + ba.porcentaje)) , 'FM9G999G990'
    ) AS simulacion_antiguedad
FROM trabajador t
JOIN afp a ON t.cod_afp = a.cod_afp
JOIN isapre i ON t.cod_isapre = i.cod_isapre
JOIN comuna_ciudad cc ON t.id_ciudad = cc.id_ciudad
JOIN bono_antiguedad ba 
    ON TRUNC(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12) 
        BETWEEN ba.limite_inferior AND ba.limite_superior
LEFT JOIN ( 
    SELECT
        numrut_t,
        MAX(monto_ticket) AS max_monto,
        MAX(nro_ticket) KEEP (DENSE_RANK LAST ORDER BY monto_ticket) AS nro_ticket
    FROM tickets_concierto
    GROUP BY numrut_t
) mt ON t.numrut = mt.numrut_t;


COMMIT;


SELECT * FROM DETALLE_BONIFICACIONES_TRABAJADOR;


-- caso 2:

CREATE OR REPLACE VIEW V_AUMENTOS_ESTUDIOS AS
SELECT
    t.numrut || '-' || t.dvrut AS RUT_TRABAJADOR,
    INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno) || ' ' || INITCAP(t.apmaterno) AS TRABAJADOR,
    be.descrip AS DESCRIP,
    be.porc_bono AS PCT_ESTUDIOS,
    t.sueldo_base AS SUELDO_ACTUAL,

    ROUND(t.sueldo_base * (be.porc_bono / 100)) AS AUMENTO,

    ROUND(t.sueldo_base * (1 + (be.porc_bono / 100))) AS SUELDO_AUMENTADO,

    NVL(COUNT(af.numrut_carga), 0) AS cant_cargas_familiares,
    cc.nombre_ciudad,
    tt.desc_categoria AS tipo_contrato
FROM
    trabajador t
JOIN
    bono_escolar be ON t.id_escolaridad_t = be.id_escolar
JOIN
    comuna_ciudad cc ON t.id_ciudad = cc.id_ciudad
JOIN
    tipo_trabajador tt ON t.id_categoria_t = tt.id_categoria
LEFT JOIN 
    asignacion_familiar af ON t.numrut = af.numrut_t
GROUP BY
    t.numrut, t.dvrut, t.nombre, t.appaterno, t.apmaterno, t.sueldo_base,
    be.descrip, be.porc_bono, cc.nombre_ciudad, tt.desc_categoria
ORDER BY
    be.porc_bono DESC, 
    TRABAJADOR ASC;
    

SELECT 
    RUT_TRABAJADOR, 
    TRABAJADOR, 
    DESCRIP, 
    PCT_ESTUDIOS, 
    SUELDO_ACTUAL, 
    AUMENTO, 
    SUELDO_AUMENTADO
FROM V_AUMENTOS_ESTUDIOS;


CREATE SYNONYM V_AUMENTOS FOR V_AUMENTOS_ESTUDIOS;
CREATE SYNONYM T_EMP FOR trabajador;

-- indices
CREATE INDEX idx_trab_apmaterno 
ON trabajador (apmaterno);

CREATE INDEX idx_trab_apmat_upper 
ON trabajador (UPPER(apmaterno));

SELECT numrut, appaterno, apmaterno, nombre, sueldo_base
FROM trabajador
WHERE apmaterno = 'CASTILLO';


SELECT numrut, appaterno, apmaterno, nombre, sueldo_base
FROM   trabajador
WHERE  UPPER(apmaterno) = 'CASTILLO';








