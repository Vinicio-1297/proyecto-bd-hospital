

USE GestionHospitalaria;
GO

/* ===== 0. Reinicio: borra los índices del paso 5 si existen (para que "antes" sea de verdad "antes") ===== */
DROP INDEX IF EXISTS IX_Citas_PacienteID_FechaHora ON dbo.Citas;
DROP INDEX IF EXISTS IX_Citas_Estado_FechaHora ON dbo.Citas;
DROP INDEX IF EXISTS IX_Facturacion_PacienteID ON dbo.Facturacion;
DROP INDEX IF EXISTS IX_DetalleFactura_FacturacionID ON dbo.DetalleFactura;
DROP INDEX IF EXISTS IX_Tratamiento_CitaID ON dbo.Tratamiento;
DROP INDEX IF EXISTS IX_Tratamiento_AdmisionID ON dbo.Tratamiento;
GO

/* ===== 1. Índices que existen ANTES (captura del Results) ===== */
SELECT OBJECT_NAME(i.object_id) AS Tabla,
       i.name                  AS Indice,
       i.type_desc             AS Tipo,
       i.is_unique             AS EsUnico,
       i.has_filter            AS TieneFiltro,
       STUFF((SELECT N', ' + c.name
              FROM sys.index_columns ic JOIN sys.columns c
                   ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 2, N'') AS Columnas_Clave,
       STUFF((SELECT N', ' + c.name
              FROM sys.index_columns ic JOIN sys.columns c
                   ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
              ORDER BY c.column_id FOR XML PATH('')), 1, 2, N'') AS Columnas_Incluidas
FROM   sys.indexes AS i
WHERE  i.type > 0
  AND  OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY Tabla, i.index_id;
GO

/* ===== 2. Tamaño de las tablas (explica por qué las lecturas son pocas con datos de prueba) ===== */
SELECT t.name AS Tabla,
       SUM(ps.row_count)       AS Filas,
       SUM(ps.used_page_count) AS PaginasDatos,
       SUM(ps.used_page_count) * 8 AS KB_Datos
FROM   sys.dm_db_partition_stats AS ps
JOIN   sys.tables AS t ON t.object_id = ps.object_id
WHERE  ps.index_id IN (0, 1)          -- solo el heap/clustered (los datos)
GROUP BY t.name
ORDER BY PaginasDatos DESC;
GO

/* ===== 3. CONSULTAS DE PRUEBA (las mismas se repiten en 05_indices.sql) ===== */

/* ---------- CONSULTA 1: historial de citas de un paciente ----------
   Caso de uso: recepción/médico abre la ficha de un paciente. Filtra Citas por PacienteID (una FK sin índice).
  . */
CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- solo en servidor de desarrollo: deja la caché limpia
DECLARE @PacienteID INT = (SELECT TOP (1) PacienteID FROM dbo.Facturacion
                          GROUP BY PacienteID ORDER BY COUNT(*) DESC, PacienteID);
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT c.CitaID, c.FechaHora, c.Estado, c.Costo,
       m.Nombre + N' ' + m.Apellido AS Medico, m.Especialidad
FROM   dbo.Citas  AS c
JOIN   dbo.Medico AS m ON m.MedicoID = c.MedicoID
WHERE  c.PacienteID = @PacienteID
ORDER BY c.FechaHora DESC
OPTION (RECOMPILE);

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/* ---------- CONSULTA 2: ingresos por especialidad (últimos 30 días) ----------
   Caso de uso: reporte/dashboard. Filtra Citas por Estado y rango de FechaHora y agrupa por especialidad.
    */
CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- solo en servidor de desarrollo: deja la caché limpia
DECLARE @Hasta DATETIME = GETDATE();
DECLARE @Desde DATETIME = DATEADD(DAY, -30, @Hasta);
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT m.Especialidad,
       COUNT(*)     AS CitasAtendidas,
       SUM(c.Costo) AS Ingreso
FROM   dbo.Citas  AS c
JOIN   dbo.Medico AS m ON m.MedicoID = c.MedicoID
WHERE  c.Estado = N'Atendida'
  AND  c.FechaHora >= @Desde AND c.FechaHora < @Hasta
GROUP BY m.Especialidad
ORDER BY Ingreso DESC
OPTION (RECOMPILE);

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/* ---------- CONSULTA 3: estado de cuenta de un paciente (facturas + detalle) ----------
   Caso de uso: facturación revisa lo que debe un paciente. Une Facturacion y DetalleFactura por FK sin índice.
   */
CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- solo en servidor de desarrollo: deja la caché limpia
DECLARE @PacienteID INT = (SELECT TOP (1) PacienteID FROM dbo.Facturacion
                          GROUP BY PacienteID ORDER BY COUNT(*) DESC, PacienteID);
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT f.FacturacionID, f.FechaEmision, f.Estado,
       d.Concepto, d.Monto
FROM   dbo.Facturacion    AS f
JOIN   dbo.DetalleFactura AS d ON d.FacturacionID = f.FacturacionID
WHERE  f.PacienteID = @PacienteID
ORDER BY f.FechaEmision, f.FacturacionID
OPTION (RECOMPILE);

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO