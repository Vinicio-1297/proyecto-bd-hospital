/* GestionHospitalaria - Paso 4: SEGURIDAD (logins, usuarios, roles, permisos, enmascarado)
   */

USE GestionHospitalaria;
GO

/* Enmascarado de datos: quien no tenga UNMASK ve 'XXXX-1234' en los telefonos */ 
ALTER TABLE Paciente ALTER COLUMN Telefono
    ADD MASKED WITH (FUNCTION = 'partial(0,"XXXX-",4)');
ALTER TABLE Paciente ALTER COLUMN ContactoEmergenciaTelefono
    ADD MASKED WITH (FUNCTION = 'partial(0,"XXXX-",4)');
GO

/* ===================== 3. SEGURIDAD ===================== */
/* Las contrasenas son SOLO para el proyecto: no subirlas al repo o repo publico. */

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_recepcion')
    CREATE LOGIN lg_recepcion   WITH PASSWORD = N'Recep#2026Hosp!',  CHECK_POLICY = ON, DEFAULT_DATABASE = GestionHospitalaria;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_medico')
    CREATE LOGIN lg_medico      WITH PASSWORD = N'Medico#2026Hosp!', CHECK_POLICY = ON, DEFAULT_DATABASE = GestionHospitalaria;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_facturacion')
    CREATE LOGIN lg_facturacion WITH PASSWORD = N'Factu#2026Hosp!',  CHECK_POLICY = ON, DEFAULT_DATABASE = GestionHospitalaria;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_powerbi')
    CREATE LOGIN lg_powerbi     WITH PASSWORD = N'PowerBI#2026Hosp!', CHECK_POLICY = ON, DEFAULT_DATABASE = GestionHospitalaria;
GO

IF DATABASE_PRINCIPAL_ID(N'usr_recepcion')   IS NULL CREATE USER usr_recepcion   FOR LOGIN lg_recepcion;
IF DATABASE_PRINCIPAL_ID(N'usr_medico')      IS NULL CREATE USER usr_medico      FOR LOGIN lg_medico;
IF DATABASE_PRINCIPAL_ID(N'usr_facturacion') IS NULL CREATE USER usr_facturacion FOR LOGIN lg_facturacion;
IF DATABASE_PRINCIPAL_ID(N'usr_powerbi')     IS NULL CREATE USER usr_powerbi     FOR LOGIN lg_powerbi;

IF DATABASE_PRINCIPAL_ID(N'rol_recepcion')   IS NULL CREATE ROLE rol_recepcion;
IF DATABASE_PRINCIPAL_ID(N'rol_medico')      IS NULL CREATE ROLE rol_medico;
IF DATABASE_PRINCIPAL_ID(N'rol_facturacion') IS NULL CREATE ROLE rol_facturacion;
IF DATABASE_PRINCIPAL_ID(N'rol_powerbi')     IS NULL CREATE ROLE rol_powerbi;
GO

ALTER ROLE rol_recepcion   ADD MEMBER usr_recepcion;
ALTER ROLE rol_medico      ADD MEMBER usr_medico;
ALTER ROLE rol_facturacion ADD MEMBER usr_facturacion;
ALTER ROLE rol_powerbi     ADD MEMBER usr_powerbi;
GO

/* --- Recepcion: agenda pacientes y citas; no ve clinica ni facturas --- */
GRANT SELECT, INSERT, UPDATE ON Paciente   TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON Citas       TO rol_recepcion;
GRANT SELECT                 ON Medico      TO rol_recepcion;
GRANT SELECT                 ON Consultorio TO rol_recepcion;
DENY  SELECT, INSERT, UPDATE, DELETE ON RecetasMedicas TO rol_recepcion;
DENY  SELECT, INSERT, UPDATE, DELETE ON Tratamiento   TO rol_recepcion;
DENY  SELECT, INSERT, UPDATE, DELETE ON Facturacion    TO rol_recepcion;
DENY  SELECT, INSERT, UPDATE, DELETE ON DetalleFactura TO rol_recepcion;
DENY  DELETE ON Paciente TO rol_recepcion;
DENY  DELETE ON Citas     TO rol_recepcion;
GRANT UNMASK TO rol_recepcion;   -- necesita ver telefonos reales

/* --- Medico: lee historial, registra tratamientos/recetas/admisiones;
       de las citas solo puede cambiar el Estado --- */
GRANT SELECT ON Paciente   TO rol_medico;
GRANT SELECT ON Citas       TO rol_medico;
GRANT UPDATE ON Citas (Estado) TO rol_medico;
GRANT SELECT ON Medico      TO rol_medico;
GRANT SELECT ON Consultorio TO rol_medico;
GRANT SELECT, INSERT, UPDATE ON Admisiones      TO rol_medico;
GRANT SELECT, INSERT, UPDATE ON Tratamiento    TO rol_medico;
GRANT SELECT, INSERT, UPDATE ON RecetasMedicas  TO rol_medico;
DENY  SELECT, INSERT, UPDATE, DELETE ON Facturacion    TO rol_medico;
DENY  SELECT, INSERT, UPDATE, DELETE ON DetalleFactura TO rol_medico;
GRANT UNMASK TO rol_medico;      -- necesita el contacto de emergencia

/* --- Facturacion: cobra; ve datos minimos del paciente y NO el diagnostico/recetas --- */
GRANT SELECT, INSERT, UPDATE ON Facturacion    TO rol_facturacion;
GRANT SELECT, INSERT, UPDATE ON DetalleFactura TO rol_facturacion;
GRANT SELECT ON Paciente   (PacienteID, Nombre, Apellido) TO rol_facturacion;
GRANT SELECT ON Admisiones  (AdmisionID, PacienteID, MedicoID, FechaIngreso, FechaAlta) TO rol_facturacion;
GRANT SELECT ON Citas       TO rol_facturacion;
GRANT SELECT ON Tratamiento TO rol_facturacion;
GRANT SELECT ON vw_FacturacionResumen TO rol_facturacion;
DENY  SELECT ON RecetasMedicas TO rol_facturacion;
DENY  DELETE ON Facturacion    TO rol_facturacion;
DENY  DELETE ON DetalleFactura TO rol_facturacion;

/* --- Power BI: solo lectura de las vistas (sin acceso directo a tablas, sin UNMASK) --- */
GRANT SELECT ON vw_CitasDetalle        TO rol_powerbi;
GRANT SELECT ON vw_FacturacionResumen  TO rol_powerbi;
GRANT SELECT ON vw_TratamientoDetalle TO rol_powerbi;
GO