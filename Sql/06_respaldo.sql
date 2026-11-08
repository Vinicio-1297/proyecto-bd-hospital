/* GestionHospitalaria - Respaldo y recuperacion */

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

/* 2. Cambio de prueba + backup DIFERENCIAL */
USE GestionHospitalaria;
INSERT Paciente (Nombre, Apellido, FechaNacimiento, Genero)
VALUES (N'Prueba', N'Diferencial', '1990-01-01', N'Femenino');
GO

USE master;
BACKUP DATABASE GestionHospitalaria
TO DISK = N'/var/opt/mssql/data/GestionHospitalaria_Diff.bak'
WITH DIFFERENTIAL, INIT, NAME = N'Diff GestionHospitalaria';
GO

/* 3. Otro cambio + backup de LOG */
USE GestionHospitalaria;
INSERT Paciente (Nombre, Apellido, FechaNacimiento, Genero)
VALUES (N'Prueba', N'Log', '1985-05-05', N'Masculino');
GO

USE master;
BACKUP LOG GestionHospitalaria
TO DISK = N'/var/opt/mssql/data/GestionHospitalaria_Log.trn'
WITH INIT, NAME = N'Log GestionHospitalaria';
GO

/* 4. RESTAURACION de prueba (a una base nueva) */
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

/* 5. Verificacion: deben salir las 2 filas de prueba */
SELECT PacienteID, Nombre, Apellido
FROM   GestionHospitalaria_Test.dbo.Paciente
WHERE  Nombre = N'Prueba';
GO