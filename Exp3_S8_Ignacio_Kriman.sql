-- TRABAJO SUMATIVO 3 IGNACIO KRIMAN
/* creacion de usuarios (con otorgacion de roles y privilegios) con responsabilidades
   fijas para el calculo y vista de multas con otorgacion de descuentos por carrera si aplica.*/ 
   
--==============================================================================--   
                               --ADMIN--
--==============================================================================--

-- creacion de usuarios con sus respectivos nombres y claves ademas del su quota
CREATE USER PRY2205_USER1 IDENTIFIED BY Hola12345678
DEFAULT TABLESPACE DATA
QUOTA UNLIMITED ON DATA;

CREATE USER PRY2205_USER2 IDENTIFIED BY Hola12345678
DEFAULT TABLESPACE DATA
QUOTA UNLIMITED ON DATA;

-- creacion de los roles D y P
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_P;

-- asignacion de privilegios
GRANT CREATE TABLE, CREATE VIEW, CREATE INDEX, CREATE SYNONYM
TO PRY2205_ROL_D;

GRANT CREATE SEQUENCE
TO PRY2205_ROL_P;

GRANT PRY2205_ROL_D TO PRY2205_USER1;
GRANT PRY2205_ROL_P TO PRY2205_USER2;
GRANT CREATE TABLE TO PRY2205_USER2;
GRANT CREATE VIEW TO PRY2205_USER2;

GRANT SELECT ON PRY2205_USER1.LIBRO TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.EJEMPLAR TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.PRESTAMO TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.ALUMNO TO PRY2205_USER2;      
GRANT SELECT ON PRY2205_USER1.CARRERA TO PRY2205_USER2;     
GRANT SELECT ON PRY2205_USER1.REBAJA_MULTA TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.EMPLEADO TO PRY2205_USER2;

-- sinonimos publicos
CREATE PUBLIC SYNONYM LIBRO FOR PRY2205_USER1.LIBRO;
CREATE PUBLIC SYNONYM EJEMPLAR FOR PRY2205_USER1.EJEMPLAR;
CREATE PUBLIC SYNONYM PRESTAMO FOR PRY2205_USER1.PRESTAMO;
CREATE PUBLIC SYNONYM ALUMNO FOR PRY2205_USER1.ALUMNO;
CREATE PUBLIC SYNONYM CARRERA FOR PRY2205_USER1.CARRERA;
CREATE PUBLIC SYNONYM REBAJA_MULTA FOR PRY2205_USER1.REBAJA_MULTA;

--==============================================================================-- 
                               --USER1--
--==============================================================================--

-- VISTA DE MULTAS 
-- creamos vistas las cuales nos permitiran visualizar, atrasos, descuentos, valor de las multas, etc.
-- ademas otorgamos permisos para el usuario que utilice el rol P (en este caso user2)
-- tambien creamos indices para mejorar la eficiencia de las busquedas


-- permisos
-- otorgamos permiso de lectura SELECT sobre las tablas del user1 a los usuarios con rol P
GRANT SELECT ON LIBRO TO PRY2205_ROL_P;
GRANT SELECT ON EJEMPLAR TO PRY2205_ROL_P;
GRANT SELECT ON PRESTAMO TO PRY2205_ROL_P;
GRANT SELECT ON EMPLEADO TO PRY2205_ROL_P;
GRANT SELECT ON ALUMNO TO PRY2205_ROL_P;
GRANT SELECT ON CARRERA TO PRY2205_ROL_P;


-- sinonimos publicos

-- creamos los sinonimos para que cualquier usuario con privilegios pueda acceder
--  a las tablas con los nombres dados
CREATE PUBLIC SYNONYM LIBRO_S FOR PRY2205_USER1.LIBRO;
CREATE PUBLIC SYNONYM EJEMPLAR_S FOR PRY2205_USER1.EJEMPLAR;
CREATE PUBLIC SYNONYM PRESTAMO_S FOR PRY2205_USER1.PRESTAMO;


-- view detalle de multas
CREATE OR REPLACE VIEW VW_DETALLE_MULTAS AS
SELECT
    p.prestamoid AS ID_PRESTAMO,
    a.nombre || ' ' || a.apaterno || ' ' || a.amaterno AS NOMBRE_ALUMNO,
    c.descripcion AS CARRERA,
    l.libroid AS ID_LIBRO,
    l.precio AS PRECIO_LIBRO,
    p.fecha_termino,
    p.fecha_entrega,
    (p.fecha_entrega - p.fecha_termino) AS DIAS_ATRASO, -- calculamos dias de atraso
    -- redondeamos el 3% del valor a base de los dias
    ROUND((p.fecha_entrega - p.fecha_termino) * (l.precio * 0.03)) AS VALOR_MULTA, 
    -- creamos los porcentajes de rebaja con las carreras solicitadas
    CASE
        WHEN c.descripcion IN ('Ing. en prevencion de riesgos','Gastronomia','Publicidad','Diseno industrial')
        THEN 20
        ELSE 0
    END AS PORCENTAJE_REBAJA_MULTA,
    ROUND(
        (p.fecha_entrega - p.fecha_termino) * (l.precio * 0.03) *
        (1 - CASE
                WHEN UPPER(TRIM(c.descripcion)) IN (
                    'ING. EN PREVENCION DE RIESGOS',
                    'GASTRONOMIA',
                    'PUBLICIDAD',
                    'DISENO INDUSTRIAL'
                )
                THEN 0.20
                ELSE 0
            END)
    ) AS VALOR_REBAJADO
    
-- usamos joints para obtener nombre alumno, carrera y el id y precio del libro
FROM PRESTAMO p
JOIN ALUMNO a ON p.alumnoid = a.alumnoid
JOIN CARRERA c ON a.carreraid = c.carreraid
JOIN LIBRO l ON p.libroid = l.libroid
-- incluimos solo con retraso y en un perido de hace dos anios hasta ahora
WHERE p.fecha_entrega > p.fecha_termino
  AND EXTRACT(YEAR FROM p.fecha_termino) = EXTRACT(YEAR FROM SYSDATE) - 2
ORDER BY p.fecha_entrega DESC;



-- view de prestamos con multa
-- esta es una version mas simplificada de la vista anterior, mas rapida y accesible
CREATE OR REPLACE VIEW VW_PRESTAMOS_MULTA AS
SELECT
    p.prestamoid,
    a.nombre || ' ' || a.apaterno || ' ' || a.amaterno AS ALUMNO,
    c.descripcion AS CARRERA,
    l.libroid,
    l.precio,
    p.fecha_termino,
    p.fecha_entrega,
    (p.fecha_entrega - p.fecha_termino) AS DIAS_ATRASO,
    ROUND((p.fecha_entrega - p.fecha_termino) * (l.precio * 0.03)) AS VALOR_MULTA
FROM PRESTAMO p
JOIN ALUMNO a ON p.alumnoid = a.alumnoid
JOIN CARRERA c ON a.carreraid = c.carreraid
JOIN LIBRO l ON p.libroid = l.libroid
WHERE p.fecha_entrega > p.fecha_termino
  AND EXTRACT(YEAR FROM p.fecha_termino) = EXTRACT(YEAR FROM SYSDATE) - 2;


-- indices para mejorar la eficiencia de la busqueda y no hacer Full Table Scan

-- acelera la busqueda por rango de fechas o filtros en dichas columnas
CREATE INDEX IDX_PRESTAMO_FECHAS ON PRESTAMO(fecha_termino, fecha_entrega);

-- mejora el rendimiento de los JOIN 
CREATE INDEX IDX_PRESTAMO_LIBRO ON PRESTAMO(libroid);

-- acelera tambien el rendimiento de los join
CREATE INDEX IDX_ALUMNO_CARRERA ON ALUMNO(carreraid);


-- consultas para ver las tablas
SELECT * FROM VW_DETALLE_MULTAS;
SELECT * FROM VW_PRESTAMOS_MULTA;

--==============================================================================-- 
                               --USER2--
--==============================================================================--

-- CONTROL DE STOCK BIBLIOGRAFICO
-- informe detallado mostrando prestamos de hace dos anios desde la fecha actual

-- eliminacion de objetos para reejecucion del script
DROP SEQUENCE SEQ_CONTROL_STOCK;
DROP TABLE CONTROL_STOCK_LIBROS CASCADE CONSTRAINTS;

-- creamos la secuencia para generar numeros autoincremtables 
CREATE SEQUENCE SEQ_CONTROL_STOCK
START WITH 1
INCREMENT BY 1;


-- creamos nuestra tabla as select basada en los resultados de la consulta
CREATE TABLE CONTROL_STOCK_LIBROS AS
SELECT
  l.libroid       AS id_libro,
  l.nombre_libro AS nombre_libro,

  -- contamos total de ejemplares de un libro
  COUNT(DISTINCT e.ejemplarid) AS total_ejemplares, 
  -- cuantos ejemplares estan en prestamo
  COUNT(DISTINCT p.ejemplarid) AS en_prestamo,
  -- diferencia entre ejemplares disponibles vs los que estan en prestamo
  COUNT(DISTINCT e.ejemplarid)
  - COUNT(DISTINCT p.ejemplarid) AS disponibles,

  -- calculamos el porcentaje que estan en prestamo
  ROUND(
    COUNT(DISTINCT p.ejemplarid)
    / NULLIF(COUNT(DISTINCT e.ejemplarid), 0) * 100 
  ) AS porcentaje_prestamo,

  -- marcamos el stock dependiendo si es suficente S o es critico N
  CASE
    WHEN
      COUNT(DISTINCT e.ejemplarid)
      - COUNT(DISTINCT p.ejemplarid) > 2
    THEN 'S'
    ELSE 'N'
  END AS stock_critico

-- con JOINS conectamos con los ejemplares para conocer cada copia de un libro
FROM ADMIN.libro l
JOIN ADMIN.ejemplar e
  ON l.libroid = e.libroid
--  a la ves hacemos join con la tabla de prestamo para saber cuales estan prestados
LEFT JOIN ADMIN.prestamo p
  ON p.ejemplarid = e.ejemplarid
  -- extraemos la informacion de hace dos anios hasta la fecha
 AND EXTRACT(YEAR FROM p.fecha_inicio) = EXTRACT(YEAR FROM SYSDATE) - 2
 -- y ademas solo consideramos empleados con id 150, 180 y 190
 AND p.empleadoid IN (150, 180, 190)

-- agrupamos por libro
GROUP BY l.libroid, l.nombre_libro;
COMMIT; -- guardamos los cambios

-- select para ver el informe
SELECT * FROM CONTROL_STOCK_LIBROS;

-- podemos hacer consulta de las vistas del user1 desde el user2 si es necesario
SELECT * FROM VW_DETALLE_MULTAS;
SELECT * FROM VW_PRESTAMOS_MULTA;

--==============================================================================--