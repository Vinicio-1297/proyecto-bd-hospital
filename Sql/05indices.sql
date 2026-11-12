

USE GestionHospitalaria;
GO

/* ===== 1. CREACIÓN DE ÍNDICES ===== */

/* Citas por paciente, de la más reciente a la más antigua (consulta 1) */
DROP INDEX IF EXISTS IX_Citas_PacienteID_FechaHora ON dbo.Citas;
CREATE NONCLUSTERED INDEX IX_Citas_PacienteID_FechaHora
    ON dbo.Citas (PacienteID, FechaHora DESC)
    INCLUDE (MedicoID, Estado, Costo);

/* Citas por estado y rango de fechas: reportes y dashboard (consulta 2) */
DROP INDEX IF EXISTS IX_Citas_Estado_FechaHora ON dbo.Citas;
CREATE NONCLUSTERED INDEX IX_Citas_Estado_FechaHora
    ON dbo.Citas (Estado, FechaHora)
    INCLUDE (MedicoID, Costo);

/* Facturas de un paciente (consulta 3) */
DROP INDEX IF EXISTS IX_Facturacion_PacienteID ON dbo.Facturacion;
CREATE NONCLUSTERED INDEX IX_Facturacion_PacienteID
    ON dbo.Facturacion (PacienteID)
    INCLUDE (FechaEmision, Estado);

/* Líneas de una factura: JOIN Facturacion-DetalleFactura (consulta 3 y vw_FacturacionResumen) */
DROP INDEX IF EXISTS IX_DetalleFactura_FacturacionID ON dbo.DetalleFactura;
CREATE NONCLUSTERED INDEX IX_DetalleFactura_FacturacionID
    ON dbo.DetalleFactura (FacturacionID)
    INCLUDE (Concepto, Monto);

/* Soportan el JOIN de vw_TratamientoDetalle y las facturas por cita/admisión (no se miden aparte) */
DROP INDEX IF EXISTS IX_Tratamiento_CitaID ON dbo.Tratamiento;
CREATE NONCLUSTERED INDEX IX_Tratamiento_CitaID
    ON dbo.Tratamiento (CitaID);

DROP INDEX IF EXISTS IX_Tratamiento_AdmisionID ON dbo.Tratamiento;
CREATE NONCLUSTERED INDEX IX_Tratamiento_AdmisionID
    ON dbo.Tratamiento (AdmisionID);
GO

/* ===== 2. VERIFICACIÓN (captura del Results) ===== */
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

/* Espacio que ocupa cada índice nuevo (costo de tenerlos; útil para el informe y el dimensionamiento) */
SELECT OBJECT_NAME(i.object_id) AS Tabla, i.name AS Indice,
       SUM(ps.used_page_count) AS Paginas, SUM(ps.used_page_count) * 8 AS KB
FROM   sys.indexes AS i
JOIN   sys.dm_db_partition_stats AS ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE  i.name LIKE N'IX[_]%'
GROUP BY i.object_id, i.name
ORDER BY Tabla, Indice;
GO

/* ===== 3. MEDICIÓN "DESPUÉS" (mismas consultas que 05a) ===== */

/* ---------- CONSULTA 1: historial de citas de un paciente ----------
   Caso de uso: recepción/médico abre la ficha de un paciente. Filtra Citas por PacienteID (una FK sin índice).
   Selecciona TODO este bloque (hasta el GO) y pulsa F5 con el plan real activado (Ctrl+M). */
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
   Selecciona TODO este bloque (hasta el GO) y pulsa F5 con el plan real activado (Ctrl+M). */
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
   Selecciona TODO este bloque (hasta el GO) y pulsa F5 con el plan real activado (Ctrl+M). */
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

/* ===== 4. ¿SE USARON LOS ÍNDICES? (correr DESPUÉS de las 3 consultas; captura del Results) =====
   user_seeks > 0 prueba que el optimizador los eligió. user_updates muestra el costo de mantenerlos. */
SELECT OBJECT_NAME(s.object_id) AS Tabla, i.name AS Indice,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM   sys.dm_db_index_usage_stats AS s
JOIN   sys.indexes AS i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE  s.database_id = DB_ID()
  AND  i.name LIKE N'IX[_]%'
ORDER BY Tabla, Indice;
GO