/* GestionHospitalaria - Paso 8: IMPORTACION DESDE CSV (BULK INSERT)
   Requiere los pasos 1 y 2.
   Carga datos/pacientes_nuevos.csv en una tabla de paso (Stg_Paciente), valida cada
   fila y solo pasa las buenas a Paciente. Las malas se listan con su motivo.
   Se puede repetir: los pacientes que ya existen se rechazan, no se duplican.

   ANTES DE CORRER:
   1. El servidor de SQL Server tiene que poder leer el CSV (no basta con tenerlo en tu PC):
        Windows: copia pacientes_nuevos.csv a C:\Temp\  (Descargas suele dar "Access denied")
        Docker/Linux: docker cp pacientes_nuevos.csv <contenedor>:/var/opt/mssql/data/
   2. El script detecta solo si SQL Server corre en Windows o en Linux y usa la ruta de arriba.
      Si guardaste el archivo en otro lugar, cambia @ruta en la seccion 2.
   3. Tu login necesita el permiso ADMINISTER BULK OPERATIONS (sysadmin ya lo tiene).
   4. En Linux la opcion CODEPAGE no existe: si las tildes se dañan, el script rechaza esas filas
      ("Tildes dañadas...") y hay que usar pacientes_nuevos_sin_tildes.csv (mismos datos, sin tildes).

   Resultado esperado con el CSV incluido: 30 filas leidas, 24 insertadas, 6 rechazadas. */

USE GestionHospitalaria;
GO

/* ===================== 1. TABLA DE PASO ===================== */
/* Todo como texto: asi BULK INSERT no falla por una fecha o un genero mal escrito;
   los datos se validan despues, en la seccion 3. */
DROP TABLE IF EXISTS Stg_Paciente;

CREATE TABLE Stg_Paciente (
    Nombre NVARCHAR (100) NULL,
    Apellido NVARCHAR (100) NULL,
    FechaNacimiento NVARCHAR (30) NULL,
    Genero NVARCHAR (30) NULL,
    Telefono NVARCHAR (30) NULL,
    Direccion NVARCHAR (300) NULL,
    ContactoEmergenciaNombre NVARCHAR (300) NULL,
    ContactoEmergenciaParentesco NVARCHAR (100) NULL,
    ContactoEmergenciaTelefono NVARCHAR (30) NULL
);
GO

/* ===================== 2. BULK INSERT ===================== */
/* BULK INSERT no acepta una variable como ruta, por eso se arma con SQL dinamico.
   FIRSTROW = 2 salta el encabezado; ROWTERMINATOR 0x0a sirve tanto para archivos con LF como CRLF.
   En Windows se agrega CODEPAGE 65001 (UTF-8, para tildes y ñ); en Linux esa opcion no existe. */
DECLARE @linux BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.dm_os_host_info WHERE host_platform = N'Linux')
                          THEN 1 ELSE 0 END;
DECLARE @ruta NVARCHAR (260) = CASE WHEN @linux = 1
                                    THEN N'/var/opt/mssql/data/pacientes_nuevos.csv'
                                    ELSE N'C:\Temp\pacientes_nuevos.csv' END;
DECLARE @sql  NVARCHAR (MAX) =
    N'BULK INSERT Stg_Paciente FROM ''' + REPLACE(@ruta, N'''', N'''''') + N'''
      WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK'
    + CASE WHEN @linux = 0 THEN N', CODEPAGE = ''65001''' ELSE N'' END + N');';
EXEC sys.sp_executesql @sql;

/* Si el archivo traia CRLF, el ultimo campo de cada fila queda con un CR pegado */
UPDATE Stg_Paciente
SET    ContactoEmergenciaTelefono = REPLACE(ContactoEmergenciaTelefono, CHAR(13), N'');

SELECT COUNT(*) AS FilasEnTablaDePaso FROM Stg_Paciente;
GO

/* ===================== 3. VALIDAR Y PASAR A Paciente ===================== */
DROP TABLE IF EXISTS #Clasif;

WITH x AS (
    SELECT s.*,
           TRY_CONVERT(DATE, LTRIM(RTRIM(s.FechaNacimiento)), 23) AS Fecha,
           ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(s.Nombre)), LTRIM(RTRIM(s.Apellido)),
                                           LTRIM(RTRIM(s.FechaNacimiento))
                              ORDER BY (SELECT NULL)) AS rn
    FROM   Stg_Paciente AS s
)
SELECT x.*,
       CASE
            WHEN NULLIF(LTRIM(RTRIM(x.Nombre)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(x.Apellido)), N'') IS NULL
                THEN N'Nombre o apellido vacío'
            WHEN CHARINDEX(NCHAR(195), CONCAT(x.Nombre, x.Apellido, x.Direccion, x.ContactoEmergenciaNombre,
                                              x.ContactoEmergenciaParentesco) COLLATE Latin1_General_BIN2) > 0
              OR CHARINDEX(NCHAR(65533), CONCAT(x.Nombre, x.Apellido, x.Direccion, x.ContactoEmergenciaNombre,
                                                x.ContactoEmergenciaParentesco) COLLATE Latin1_General_BIN2) > 0
                THEN N'Tildes dañadas por la codificación (usar pacientes_nuevos_sin_tildes.csv)'
            WHEN LEN(LTRIM(RTRIM(x.Nombre))) > 50 OR LEN(LTRIM(RTRIM(x.Apellido))) > 50
                THEN N'Nombre o apellido muy largo'
            WHEN LEN(x.Direccion) > 255 OR LEN(x.ContactoEmergenciaNombre) > 255
              OR LEN(x.ContactoEmergenciaParentesco) > 50 OR LEN(x.ContactoEmergenciaTelefono) > 20
                THEN N'Dirección o contacto de emergencia muy largo'
            WHEN x.Fecha IS NULL
                THEN N'Fecha de nacimiento inválida (usar AAAA-MM-DD)'
            WHEN x.Fecha > CAST(GETDATE() AS DATE)
                THEN N'Fecha de nacimiento en el futuro'
            WHEN x.Genero IS NULL OR LTRIM(RTRIM(x.Genero)) NOT IN (N'Masculino', N'Femenino')
                THEN N'Género inválido (Masculino o Femenino)'
            WHEN NULLIF(LTRIM(RTRIM(x.Telefono)), N'') IS NOT NULL
             AND LTRIM(RTRIM(x.Telefono)) NOT LIKE N'[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
                THEN N'Teléfono inválido (8 dígitos)'
            WHEN x.rn > 1
                THEN N'Repetido en el archivo'
            WHEN EXISTS (SELECT 1 FROM Paciente AS p
                         WHERE  p.Nombre = LTRIM(RTRIM(x.Nombre))
                           AND  p.Apellido = LTRIM(RTRIM(x.Apellido))
                           AND  p.FechaNacimiento = x.Fecha)
                THEN N'Ya existe en Paciente'
       END AS Motivo
INTO   #Clasif
FROM   x;

DECLARE @insertadas INT;

INSERT Paciente (Nombre, Apellido, FechaNacimiento, Genero, Telefono, Direccion,
                 ContactoEmergenciaNombre, ContactoEmergenciaParentesco, ContactoEmergenciaTelefono)
SELECT LTRIM(RTRIM(Nombre)),
       LTRIM(RTRIM(Apellido)),
       Fecha,
       CASE WHEN LTRIM(RTRIM(Genero)) = N'Masculino' THEN N'Masculino' ELSE N'Femenino' END,
       NULLIF(LTRIM(RTRIM(Telefono)), N''),
       NULLIF(LTRIM(RTRIM(Direccion)), N''),
       NULLIF(LTRIM(RTRIM(ContactoEmergenciaNombre)), N''),
       NULLIF(LTRIM(RTRIM(ContactoEmergenciaParentesco)), N''),
       NULLIF(LTRIM(RTRIM(ContactoEmergenciaTelefono)), N'')
FROM   #Clasif
WHERE  Motivo IS NULL;

SET @insertadas = @@ROWCOUNT;

/* ===================== 4. RESULTADOS (capturas para el informe) ===================== */
SELECT (SELECT COUNT(*) FROM #Clasif)                          AS FilasLeidas,
       @insertadas                                             AS Insertadas,
       (SELECT COUNT(*) FROM #Clasif WHERE Motivo IS NOT NULL) AS Rechazadas;

/* Filas rechazadas y por que */
SELECT Nombre, Apellido, FechaNacimiento, Genero, Telefono, Motivo
FROM   #Clasif
WHERE  Motivo IS NOT NULL;

/* Pacientes que quedaron en la tabla real */
SELECT TOP (@insertadas) PacienteID, Nombre, Apellido, FechaNacimiento, Genero, Telefono
FROM   Paciente
ORDER BY PacienteID DESC;
GO

/* Stg_Paciente se deja para poder mostrarla en el informe; para borrarla:
   DROP TABLE IF EXISTS Stg_Paciente; */
