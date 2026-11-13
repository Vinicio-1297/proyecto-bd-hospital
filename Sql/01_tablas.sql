

IF DB_ID(N'GestionHospitalaria') IS NULL
    CREATE DATABASE GestionHospitalaria;
GO

USE GestionHospitalaria;
GO


/* ===================== 1. TABLAS ===================== */

/* Se borran de hijas a padres para respetar las llaves foraneas */
DROP TABLE IF EXISTS DetalleFactura;
DROP TABLE IF EXISTS Facturacion;
DROP TABLE IF EXISTS Tratamiento;
DROP TABLE IF EXISTS RecetasMedicas;
DROP TABLE IF EXISTS Admisiones;
DROP TABLE IF EXISTS Citas;
DROP TABLE IF EXISTS Medico;
DROP TABLE IF EXISTS Consultorio;
DROP TABLE IF EXISTS Paciente;


GO
CREATE TABLE Paciente (
    PacienteID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Paciente PRIMARY KEY,
    Nombre NVARCHAR (50) NOT NULL,
    Apellido NVARCHAR (50) NOT NULL,
    FechaNacimiento DATE NOT NULL CONSTRAINT CK_Paciente_FechaNac CHECK (FechaNacimiento <= CAST (GETDATE() AS DATE)),
    Genero NVARCHAR (20) NOT NULL CONSTRAINT CK_Paciente_Genero CHECK (Genero IN (N'Masculino', N'Femenino')),
    Telefono NVARCHAR (20) NULL,
    Direccion NVARCHAR (255) NULL,
    ContactoEmergenciaNombre NVARCHAR (255) NULL,
    ContactoEmergenciaParentesco NVARCHAR (50) NULL,
    ContactoEmergenciaTelefono NVARCHAR (20) NULL
);

CREATE TABLE Consultorio (
    ConsultorioID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Consultorio PRIMARY KEY,
    NumeroConsultorio NVARCHAR (10) NOT NULL CONSTRAINT UQ_Consultorio_Numero UNIQUE,
    Piso INT NOT NULL CONSTRAINT CK_Consultorio_Piso CHECK (Piso >= 0)
);

CREATE TABLE Medico (
    MedicoID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Medico PRIMARY KEY,
    ConsultorioID INT NULL CONSTRAINT Medico_ConsultorioID_fk FOREIGN KEY REFERENCES Consultorio (ConsultorioID),
    Nombre NVARCHAR (50) NOT NULL,
    Apellido NVARCHAR (50) NOT NULL,
    Especialidad NVARCHAR (70) NOT NULL,
    Telefono NVARCHAR (20) NULL,
    Correo NVARCHAR (100) NULL CONSTRAINT UQ_Medico_Correo UNIQUE
);

CREATE TABLE Citas (
    CitaID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Citas PRIMARY KEY,
    PacienteID INT NOT NULL CONSTRAINT Citas_PacienteID_fk FOREIGN KEY REFERENCES Paciente (PacienteID),
    MedicoID INT NOT NULL CONSTRAINT Citas_MedicoID_fk FOREIGN KEY REFERENCES Medico (MedicoID),
    FechaHora DATETIME NOT NULL,
    Estado NVARCHAR (20) CONSTRAINT DF_Citas_Estado DEFAULT (N'Programada') NOT NULL CONSTRAINT CK_Citas_Estado CHECK (Estado IN (N'Programada', N'Atendida', N'Cancelada', N'No asistió')),
    Costo DECIMAL (10, 2) CONSTRAINT DF_Citas_Costo DEFAULT (0) NOT NULL CONSTRAINT CK_Citas_Costo CHECK (Costo >= 0),
    Motivo NVARCHAR (200) NULL
);

CREATE TABLE Admisiones (
    AdmisionID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Admisiones PRIMARY KEY,
    PacienteID INT NOT NULL CONSTRAINT Admisiones_PacienteID_fk FOREIGN KEY REFERENCES Paciente (PacienteID),
    MedicoID INT NOT NULL CONSTRAINT Admisiones_MedicoID_fk FOREIGN KEY REFERENCES Medico (MedicoID),
    FechaIngreso DATETIME NOT NULL,
    FechaAlta DATETIME NULL,
    DiagnosticoIngreso NVARCHAR (500) NOT NULL,
    CONSTRAINT CK_Admisiones_Fechas CHECK (FechaAlta IS NULL
                                           OR FechaAlta >= FechaIngreso)
);

CREATE TABLE RecetasMedicas (
    RecetaID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_RecetasMedicas PRIMARY KEY,
    CitaID INT NOT NULL CONSTRAINT Recetas_CitaID_fk FOREIGN KEY REFERENCES Citas (CitaID),
    Fecha DATE CONSTRAINT DF_Recetas_Fecha DEFAULT (CAST (GETDATE() AS DATE)) NOT NULL,
    Indicaciones NVARCHAR (MAX) NOT NULL
);

CREATE TABLE Tratamiento (
    TratamientoID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Tratamiento PRIMARY KEY,
    CitaID INT NULL CONSTRAINT Tratamiento_CitaID_fk FOREIGN KEY REFERENCES Citas (CitaID),
    AdmisionID INT NULL CONSTRAINT Tratamiento_AdmisionID_fk FOREIGN KEY REFERENCES Admisiones (AdmisionID),
    Descripcion NVARCHAR (255) NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    Estado NVARCHAR (20) CONSTRAINT DF_Tratamiento_Estado DEFAULT (N'Activo') NOT NULL CONSTRAINT CK_Tratamiento_Estado CHECK (Estado IN (N'Activo', N'Finalizado', N'Suspendido')),
    Costo DECIMAL (10, 2) CONSTRAINT DF_Tratamiento_Costo DEFAULT (0) NOT NULL CONSTRAINT CK_Tratamiento_Costo CHECK (Costo >= 0),
    CONSTRAINT CK_Tratamiento_Origen CHECK (CitaID IS NOT NULL
                                            OR AdmisionID IS NOT NULL),
    CONSTRAINT CK_Tratamiento_Fechas CHECK (FechaFin IS NULL
                                            OR FechaFin >= FechaInicio)
);

CREATE TABLE Facturacion (
    FacturacionID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_Facturacion PRIMARY KEY,
    PacienteID INT NOT NULL CONSTRAINT Facturacion_PacienteID_fk FOREIGN KEY REFERENCES Paciente (PacienteID),
    FechaEmision DATETIME CONSTRAINT DF_Facturacion_Fecha DEFAULT (GETDATE()) NOT NULL,
    Estado NVARCHAR (20) CONSTRAINT DF_Facturacion_Estado DEFAULT (N'Pendiente') NOT NULL CONSTRAINT CK_Facturacion_Estado CHECK (Estado IN (N'Pendiente', N'Pagada', N'Anulada'))
);

/* Cada linea de factura cobra exactamente UNA cosa: cita, tratamiento o admision */
CREATE TABLE DetalleFactura (
    DetalleID INT IDENTITY (1, 1) NOT NULL CONSTRAINT PK_DetalleFactura PRIMARY KEY,
    FacturacionID INT NOT NULL CONSTRAINT Detalle_FacturacionID_fk FOREIGN KEY REFERENCES Facturacion (FacturacionID),
    Concepto NVARCHAR (155) NOT NULL,
    CitaID INT NULL CONSTRAINT Detalle_CitaID_fk FOREIGN KEY REFERENCES Citas (CitaID),
    TratamientoID INT NULL CONSTRAINT Detalle_TratamientoID_fk FOREIGN KEY REFERENCES Tratamiento (TratamientoID),
    AdmisionID INT NULL CONSTRAINT Detalle_AdmisionID_fk FOREIGN KEY REFERENCES Admisiones (AdmisionID),
    Monto DECIMAL (10, 2) NOT NULL CONSTRAINT CK_Detalle_Monto CHECK (Monto >= 0),
    CONSTRAINT CK_Detalle_UnSoloOrigen CHECK (
    (CASE WHEN CitaID IS NULL THEN 0 ELSE 1 END) +
    (CASE WHEN TratamientoID IS NULL THEN 0 ELSE 1 END) + 
    (CASE WHEN AdmisionID IS NULL THEN 0 ELSE 1 END) = 1)
);


GO
/* Evita doble reserva: un medico no puede tener 2 citas activas a la misma hora */
CREATE UNIQUE NONCLUSTERED INDEX UX_Citas_Medico_FechaHora
    ON Citas(MedicoID, FechaHora) WHERE Estado <> N'Cancelada';