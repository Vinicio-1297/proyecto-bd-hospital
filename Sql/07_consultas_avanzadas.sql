/* GestionHospitalaria - Paso 7: CONSULTAS AVANZADAS (funciones ventana)
   Requiere los pasos 1 a 3 (tablas, datos y vistas).
   Solo lectura: se puede ejecutar las veces que se quiera.
   Una funcion ventana calcula sobre un grupo de filas SIN colapsarlas (a diferencia de GROUP BY). */

USE GestionHospitalaria;
GO

/* 1. RANKING GENERAL: medicos ordenados por ingresos de citas atendidas.
   RANK() asigna la posicion segun el orden; si hay empate, comparten posicion. */
SELECT Medico, Especialidad,
       COUNT(*)   AS CitasAtendidas,
       SUM(Costo) AS Ingresos,
       RANK() OVER (ORDER BY SUM(Costo) DESC) AS Posicion
FROM   vw_CitasDetalle
WHERE  Estado = N'Atendida'
GROUP BY Medico, Especialidad
ORDER BY Posicion;
GO

/* 2. RANKING POR GRUPO: medicos ordenados dentro de su especialidad.
   PARTITION BY reinicia el ranking en cada especialidad. */
SELECT Especialidad, Medico,
       COUNT(*) AS CitasAtendidas,
       DENSE_RANK() OVER (PARTITION BY Especialidad ORDER BY COUNT(*) DESC) AS PosEnEspecialidad
FROM   vw_CitasDetalle
WHERE  Estado = N'Atendida'
GROUP BY Especialidad, Medico
ORDER BY Especialidad, PosEnEspecialidad;
GO

/* 3. ACUMULADO: facturacion pagada por mes y total acumulado.
   SUM() OVER (... ROWS UNBOUNDED PRECEDING) suma desde la primera fila hasta la actual. */
WITH Mensual AS (
    SELECT DATEFROMPARTS(YEAR(FechaEmision), MONTH(FechaEmision), 1) AS Mes,
           SUM(MontoTotal) AS TotalMes
    FROM   vw_FacturacionResumen
    WHERE  Estado = N'Pagada'
    GROUP BY DATEFROMPARTS(YEAR(FechaEmision), MONTH(FechaEmision), 1)
)
SELECT Mes, TotalMes,
       SUM(TotalMes) OVER (ORDER BY Mes ROWS UNBOUNDED PRECEDING) AS Acumulado
FROM   Mensual
ORDER BY Mes;
GO

/* 4. LAG: dias entre citas atendidas consecutivas de cada paciente.
   LAG() trae el valor de la fila anterior dentro del grupo definido por PARTITION BY. */
WITH Citas_Pac AS (
    SELECT PacienteID, Paciente, FechaHora,
           LAG(FechaHora) OVER (PARTITION BY PacienteID ORDER BY FechaHora) AS CitaAnterior
    FROM   vw_CitasDetalle
    WHERE  Estado = N'Atendida'
)
SELECT Paciente, CitaAnterior, FechaHora AS CitaActual,
       DATEDIFF(DAY, CitaAnterior, FechaHora) AS DiasEntreCitas
FROM   Citas_Pac
WHERE  CitaAnterior IS NOT NULL
ORDER BY Paciente, FechaHora;
GO

/* 5. LAG sobre totales: variacion de la facturacion pagada de un mes al siguiente. */
WITH Mensual AS (
    SELECT DATEFROMPARTS(YEAR(FechaEmision), MONTH(FechaEmision), 1) AS Mes,
           SUM(MontoTotal) AS TotalMes
    FROM   vw_FacturacionResumen
    WHERE  Estado = N'Pagada'
    GROUP BY DATEFROMPARTS(YEAR(FechaEmision), MONTH(FechaEmision), 1)
)
SELECT Mes, TotalMes,
       LAG(TotalMes) OVER (ORDER BY Mes) AS MesAnterior,
       TotalMes - LAG(TotalMes) OVER (ORDER BY Mes) AS Diferencia
FROM   Mensual
ORDER BY Mes;
GO

/* 6. ROW_NUMBER: ultima cita atendida de cada paciente.
   ROW_NUMBER() numera las filas de cada grupo; rn = 1 es la mas reciente. */
WITH x AS (
    SELECT Paciente, FechaHora, Medico, Especialidad,
           ROW_NUMBER() OVER (PARTITION BY PacienteID ORDER BY FechaHora DESC) AS rn
    FROM   vw_CitasDetalle
    WHERE  Estado = N'Atendida'
)
SELECT Paciente, FechaHora AS UltimaCita, Medico, Especialidad
FROM   x
WHERE  rn = 1
ORDER BY Paciente;
GO