/* GestionHospitalaria - Paso 6: Respaldo y recuperacion
   NOTA: las rutas /var/opt/mssql/data/ son de SQL Server en Linux/Docker.
   Si SQL Server corre en Windows, reemplazar (Ctrl + H) por la ruta propia, por ejemplo
   C:\Backups\ o el resultado de: SELECT SERVERPROPERTY('InstanceDefaultBackupPath');
   Ejecutar por secciones y UNA sola vez (las secciones 2 y 3 insertan datos).
   Requiere los pasos 1 a 4 ya ejecutados. */

/* 0. Modelo de recuperacion FULL (necesario para el backup de log) */
USE master;
GO
ALTER DATABASE GestionHospitalaria SET RECOVERY FULL;
GO

/* 1. Backup COMPLETO */
BACKUP DATABASE GestionHospitalaria
TO DISK = N'/var/opt/mssql/data/GestionHospitalaria_Full.bak'
WITH INIT, NAME = N'Full GestionHospitalaria';
GO

/* 2. Cambio real: nueva paciente con cita + backup DIFERENCIAL */
USE GestionHospitalaria;
INSERT Paciente (Nombre, Apellido, FechaNacimiento, Genero, Telefono)
VALUES (N'Rosa', N'Menjívar', '1988-04-12', N'Femenino', N'71234567');

INSERT Citas (PacienteID, MedicoID, FechaHora, Motivo)
VALUES (SCOPE_IDENTITY(), 1, '2027-03-15 10:00', N'Control general');
GO

USE master;
BACKUP DATABASE GestionHospitalaria
TO DISK = N'/var/opt/mssql/data/GestionHospitalaria_Diff.bak'
WITH DIFFERENTIAL, INIT, NAME = N'Diff GestionHospitalaria';
GO

/* 3. Cambio real: la cita se atiende y se factura + backup de LOG */
USE GestionHospitalaria;
DECLARE @c INT = (SELECT c.CitaID FROM Citas c
                  JOIN Paciente p ON p.PacienteID = c.PacienteID
                  WHERE p.Nombre = N'Rosa' AND p.Apellido = N'Menjívar');

UPDATE Citas SET Estado = N'Atendida', Costo = 45 WHERE CitaID = @c;

INSERT Facturacion (PacienteID)
SELECT PacienteID FROM Citas WHERE CitaID = @c;

INSERT DetalleFactura (FacturacionID, Concepto, CitaID, Monto)
VALUES (SCOPE_IDENTITY(), N'Consulta médica', @c, 45);
GO

USE master;
BACKUP LOG GestionHospitalaria
TO DISK = N'/var/opt/mssql/data/GestionHospitalaria_Log.trn'
WITH INIT, NAME = N'Log GestionHospitalaria';
GO

/* 4. RESTAURACION de prueba (a una base nueva) */
IF DB_ID(N'GestionHospitalaria_Test') IS NOT NULL
    DROP DATABASE GestionHospitalaria_Test;
GO

RESTORE DATABASE GestionHospitalaria_Test
FROM DISK = N'/var/opt/mssql/data/GestionHospitalaria_Full.bak'
WITH MOVE N'GestionHospitalaria'     TO N'/var/opt/mssql/data/GH_Test.mdf',
     MOVE N'GestionHospitalaria_log' TO N'/var/opt/mssql/data/GH_Test_log.ldf',
     NORECOVERY;

RESTORE DATABASE GestionHospitalaria_Test
FROM DISK = N'/var/opt/mssql/data/GestionHospitalaria_Diff.bak'
WITH NORECOVERY;

RESTORE LOG GestionHospitalaria_Test
FROM DISK = N'/var/opt/mssql/data/GestionHospitalaria_Log.trn'
WITH RECOVERY;
GO

/* 5. Verificacion: la base restaurada debe ser igual a la original */
SELECT 'Original' AS Base,
       (SELECT COUNT(*) FROM GestionHospitalaria.dbo.Paciente)       AS Pacientes,
       (SELECT COUNT(*) FROM GestionHospitalaria.dbo.Citas)          AS Citas,
       (SELECT COUNT(*) FROM GestionHospitalaria.dbo.Facturacion)    AS Facturas,
       (SELECT COUNT(*) FROM GestionHospitalaria.dbo.DetalleFactura) AS Detalles
UNION ALL
SELECT 'Restaurada',
       (SELECT COUNT(*) FROM GestionHospitalaria_Test.dbo.Paciente),
       (SELECT COUNT(*) FROM GestionHospitalaria_Test.dbo.Citas),
       (SELECT COUNT(*) FROM GestionHospitalaria_Test.dbo.Facturacion),
       (SELECT COUNT(*) FROM GestionHospitalaria_Test.dbo.DetalleFactura);

/* La paciente nueva, con su cita atendida y su factura */
SELECT p.PacienteID, p.Nombre, p.Apellido, c.Estado, c.Costo, d.Monto
FROM   GestionHospitalaria_Test.dbo.Paciente p
JOIN   GestionHospitalaria_Test.dbo.Citas c ON c.PacienteID = p.PacienteID
JOIN   GestionHospitalaria_Test.dbo.Facturacion f ON f.PacienteID = p.PacienteID
JOIN   GestionHospitalaria_Test.dbo.DetalleFactura d ON d.FacturacionID = f.FacturacionID
WHERE  p.Nombre = N'Rosa' AND p.Apellido = N'Menjívar';
GO


