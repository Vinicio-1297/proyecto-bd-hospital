/* ===================== 2. VISTAS (para Power BI) ===================== */
CREATE OR ALTER VIEW vw_CitasDetalle
AS
SELECT c.CitaID,
       c.FechaHora,
       c.Estado,
       c.Costo,
       c.Motivo,
       p.PacienteID,
       p.Nombre + N' ' + p.Apellido AS Paciente,
       m.MedicoID,
       m.Nombre + N' ' + m.Apellido AS Medico,
       m.Especialidad,
       k.NumeroConsultorio,
       k.Piso
FROM   Citas AS c
       INNER JOIN
       Paciente AS p
       ON p.PacienteID = c.PacienteID
       INNER JOIN
       Medico AS m
       ON m.MedicoID = c.MedicoID
       LEFT OUTER JOIN
       Consultorio AS k
       ON k.ConsultorioID = m.ConsultorioID;


GO
/* MontoTotal suma todas las facturas (tambien las Anuladas).
   Para ingresos se usara MontoPagado; para lo que falta cobrar, MontoPendiente. */
CREATE OR ALTER VIEW vw_FacturacionResumen
AS
SELECT   f.FacturacionID,
         f.FechaEmision,
         f.Estado,
         p.PacienteID,
         p.Nombre + N' ' + p.Apellido AS Paciente,
         COUNT(d.DetalleID) AS Lineas,
         ISNULL(SUM(d.Monto), 0) AS MontoTotal,
         ISNULL(SUM(CASE WHEN f.Estado = N'Pagada'    THEN d.Monto END), 0) AS MontoPagado,
         ISNULL(SUM(CASE WHEN f.Estado = N'Pendiente' THEN d.Monto END), 0) AS MontoPendiente
FROM     Facturacion AS f
         INNER JOIN
         Paciente AS p
         ON p.PacienteID = f.PacienteID
         LEFT OUTER JOIN
         DetalleFactura AS d
         ON d.FacturacionID = f.FacturacionID
GROUP BY f.FacturacionID, f.FechaEmision, f.Estado, p.PacienteID, p.Nombre, p.Apellido;


GO
/* Paciente y medico de un tratamiento salen de su cita o de su admision */
CREATE OR ALTER VIEW vw_TratamientoDetalle
AS
SELECT t.TratamientoID,
       t.Descripcion,
       t.FechaInicio,
       t.FechaFin,
       t.Estado,
       t.Costo,
       CASE WHEN t.CitaID IS NOT NULL THEN N'Cita' ELSE N'Admisión' END AS Origen,
       p.PacienteID,
       p.Nombre + N' ' + p.Apellido AS Paciente,
       m.MedicoID,
       m.Nombre + N' ' + m.Apellido AS Medico,
       m.Especialidad
FROM   Tratamiento AS t
       LEFT OUTER JOIN
       Citas AS c
       ON c.CitaID = t.CitaID
       LEFT OUTER JOIN
       Admisiones AS a
       ON a.AdmisionID = t.AdmisionID
       INNER JOIN
       Paciente AS p
       ON p.PacienteID = COALESCE (c.PacienteID, a.PacienteID)
       INNER JOIN
       Medico AS m
       ON m.MedicoID = COALESCE (c.MedicoID, a.MedicoID);


GO
--comprobacion 
SELECT TOP 5 *
FROM   dbo.vw_CitasDetalle;