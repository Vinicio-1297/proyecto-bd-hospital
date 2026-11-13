/* GestionHospitalaria - Paso 2: DATOS DE PRUEBA
   Requiere el paso 1. Carga 300 pacientes, 12 medicos, 1500 citas, etc.
   Si ya hay datos no hace nada (para repetir la carga, corre antes 01_tablas.sql). */

USE GestionHospitalaria;
GO



/* ===================== 4. DATOS DE PRUEBA ===================== */
/* Todo en un solo lote (sin GO) porque usa variables y tablas temporales. */
/*#SrcF es una tabla temporal*/
SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM Paciente)
BEGIN
    PRINT N'Ya hay datos cargados: no se insertó nada. Corre 01_tablas.sql para empezar de cero.';
    RETURN;
END

DECLARE @ahora DATETIME2(0) = SYSDATETIME();
DECLARE @hoy   DATE         = CAST(@ahora AS DATE);

CREATE TABLE #Nums (n INT NOT NULL PRIMARY KEY);
INSERT #Nums (n)
SELECT TOP (1500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

DECLARE @Nom TABLE (id INT IDENTITY(1,1) PRIMARY KEY, v NVARCHAR(50), g NVARCHAR(20));
INSERT @Nom (v, g) VALUES
 (N'Carlos',N'Masculino'),(N'María',N'Femenino'),(N'José',N'Masculino'),(N'Ana',N'Femenino'),(N'Luis',N'Masculino'),
 (N'Carmen',N'Femenino'),(N'Jorge',N'Masculino'),(N'Sofía',N'Femenino'),(N'Miguel',N'Masculino'),(N'Lucía',N'Femenino'),
 (N'Pedro',N'Masculino'),(N'Valeria',N'Femenino'),(N'Diego',N'Masculino'),(N'Daniela',N'Femenino'),(N'Fernando',N'Masculino'),
 (N'Gabriela',N'Femenino'),(N'Ricardo',N'Masculino'),(N'Andrea',N'Femenino'),(N'Roberto',N'Masculino'),(N'Paola',N'Femenino');

DECLARE @Ape TABLE (id INT IDENTITY(1,1) PRIMARY KEY, v NVARCHAR(50));
INSERT @Ape (v) VALUES
 (N'Hernández'),(N'Martínez'),(N'López'),(N'García'),(N'Rodríguez'),
 (N'Pérez'),(N'González'),(N'Ramírez'),(N'Flores'),(N'Castillo'),
 (N'Cruz'),(N'Morales'),(N'Vásquez'),(N'Mejía'),(N'Ortiz'),
 (N'Reyes'),(N'Aguilar'),(N'Mendoza'),(N'Rivera'),(N'Castro');

/* --- Consultorios (8) --- */
INSERT Consultorio (NumeroConsultorio, Piso) VALUES
 (N'C-101',1),(N'C-102',1),(N'C-103',1),(N'C-104',1),
 (N'C-201',2),(N'C-202',2),(N'C-203',2),(N'C-204',2);

/* --- Medicos (12, comparten consultorio: relacion N:1) --- */
INSERT Medico (ConsultorioID, Nombre, Apellido, Especialidad, Telefono, Correo) VALUES
 (1, N'Alberto',  N'Menjívar', N'Medicina General',        N'72110001', N'a.menjivar@hospital.test'),
 (1, N'Beatriz',  N'Orellana', N'Pediatría',               N'72110002', N'b.orellana@hospital.test'),
 (2, N'Camilo',   N'Rosales',  N'Cardiología',             N'72110003', N'c.rosales@hospital.test'),
 (2, N'Dina',     N'Alvarado', N'Ginecología',             N'72110004', N'd.alvarado@hospital.test'),
 (3, N'Eduardo',  N'Salinas',  N'Traumatología',           N'72110005', N'e.salinas@hospital.test'),
 (3, N'Fabiola',  N'Quintanilla', N'Dermatología',         N'72110006', N'f.quintanilla@hospital.test'),
 (4, N'Gustavo',  N'Escobar',  N'Neurología',              N'72110007', N'g.escobar@hospital.test'),
 (5, N'Hilda',    N'Barrera',  N'Oftalmología',            N'72110008', N'h.barrera@hospital.test'),
 (5, N'Ismael',   N'Cañas',    N'Urología',                N'72110009', N'i.canas@hospital.test'),
 (6, N'Julia',    N'Portillo', N'Gastroenterología',       N'72110010', N'j.portillo@hospital.test'),
 (7, N'Kevin',    N'Argueta',  N'Endocrinología',          N'72110011', N'k.argueta@hospital.test'),
 (8, N'Laura',    N'Villalta', N'Otorrinolaringología',    N'72110012', N'l.villalta@hospital.test');

/* --- Paciente (300) --- */
INSERT Paciente (Nombre, Apellido, FechaNacimiento, Genero, Telefono, Direccion,
                    ContactoEmergenciaNombre, ContactoEmergenciaParentesco, ContactoEmergenciaTelefono)
SELECT  nm.v,
        ap.v,
        DATEADD(DAY, -(365 + (k.n * 9973) % 29000), @hoy),
        nm.g,
        N'7' + CAST(1000000 + (k.n * 7919) % 9000000 AS NVARCHAR(7)),
        CHOOSE((k.n % 5) + 1, N'Col. Escalón, San Salvador', N'Col. San Benito, San Salvador',
                            N'Santa Tecla, La Libertad', N'Soyapango, San Salvador', N'Antiguo Cuscatlán, La Libertad'),
        ne.v + N' ' + ap.v,
        CHOOSE((k.n % 5) + 1, N'Madre', N'Padre', N'Cónyuge', N'Hermano/a', N'Hijo/a'),
        N'7' + CAST(1000000 + (k.n * 6857) % 9000000 AS NVARCHAR(7))
FROM    #Nums k
JOIN    @Nom nm ON nm.id = (k.n % 20) + 1
JOIN    @Ape ap ON ap.id = ((k.n / 20 + k.n * 3) % 20) + 1
JOIN    @Nom ne ON ne.id = ((k.n + 7) % 20) + 1
WHERE   k.n <= 300;

/* --- Citas (1500): cada medico tiene 125; las futuras quedan 'Programada' ---
   Cada (medico, k) genera una fecha/hora distinta => no choca con UX_Citas_Medico_FechaHora */
INSERT Citas (PacienteID, MedicoID, FechaHora, Estado, Costo, Motivo)
SELECT  ((k.n * 37) % 300) + 1,
        ((k.n - 1) % 12) + 1,
        f.fh,
        CASE WHEN f.fh > @ahora   THEN N'Programada'
             WHEN k.n % 9  = 0    THEN N'Cancelada'
             WHEN k.n % 13 = 0    THEN N'No asistió'
             ELSE N'Atendida' END,
        CASE WHEN f.fh > @ahora OR k.n % 9 = 0 OR k.n % 13 = 0 THEN 0   /* solo las atendidas tienen costo */
             ELSE 30 + ((((k.n - 1) % 12) + 1) % 4) * 15 END,
        CHOOSE((k.n % 6) + 1, N'Control general', N'Dolor abdominal', N'Chequeo de presión arterial',
                            N'Revisión de resultados', N'Dolor de cabeza persistente', N'Seguimiento de tratamiento')
FROM    #Nums k
CROSS APPLY (SELECT DATEADD(MINUTE, 480 + 30 * (((k.n - 1) / 12) % 8),
                     CAST(DATEADD(DAY, 10 - 3 * ((k.n - 1) / 12), @hoy) AS DATETIME2(0))) AS fh) f
WHERE   k.n <= 1500;

/* --- Admisiones (120): las 5 mas recientes siguen internadas (FechaAlta NULL) --- */
INSERT Admisiones (PacienteID, MedicoID, FechaIngreso, FechaAlta, DiagnosticoIngreso)
SELECT  ((k.n * 11) % 300) + 1,
        (k.n % 12) + 1,
        x.ing,
        CASE WHEN k.n <= 5 THEN NULL ELSE DATEADD(DAY, 1 + (k.n % 9), x.ing) END,
        CHOOSE((k.n % 8) + 1, N'Neumonía', N'Deshidratación severa', N'Fractura de fémur', N'Apendicitis aguda',
                            N'Crisis hipertensiva', N'Infección urinaria complicada', N'Dengue con signos de alarma', N'Cólico biliar')
FROM    #Nums k
CROSS APPLY (SELECT DATEADD(HOUR, 6 + (k.n % 12),
                     CAST(DATEADD(DAY, -(k.n * 3), @hoy) AS DATETIME2(0))) AS ing) x
WHERE   k.n <= 120;

/* --- Recetas: 1 de cada 3 citas atendidas --- */
INSERT RecetasMedicas (CitaID, Fecha, Indicaciones)
SELECT  c.CitaID,
        CAST(c.FechaHora AS DATE),
        CHOOSE((c.CitaID % 5) + 1,
               N'Paracetamol 500 mg cada 8 horas por 5 días.',
               N'Amoxicilina 500 mg cada 8 horas por 7 días.',
               N'Reposo relativo e hidratación abundante.',
               N'Ibuprofeno 400 mg cada 8 horas con alimentos.',
               N'Control en 15 días con exámenes de laboratorio.')
FROM    Citas c
WHERE   c.Estado = N'Atendida' AND c.CitaID % 3 = 0;

/* --- Tratamiento: 1 de cada 4 citas atendidas + uno por cada admision --- */
CREATE TABLE #TSrc (Seq INT IDENTITY(1,1) PRIMARY KEY, CitaID INT NULL, AdmisionID INT NULL, Ini DATE NOT NULL);

INSERT #TSrc (CitaID, AdmisionID, Ini)
SELECT c.CitaID, NULL, CAST(c.FechaHora AS DATE)
FROM   Citas c
WHERE  c.Estado = N'Atendida' AND c.CitaID % 4 = 0
ORDER BY c.CitaID;

INSERT #TSrc (CitaID, AdmisionID, Ini)
SELECT NULL, a.AdmisionID, CAST(a.FechaIngreso AS DATE)
FROM   Admisiones a
ORDER BY a.AdmisionID;

INSERT Tratamiento (CitaID, AdmisionID, Descripcion, FechaInicio, FechaFin, Estado, Costo)
SELECT  s.CitaID,
        s.AdmisionID,
        CHOOSE((s.Seq % 8) + 1, N'Antibioticoterapia oral', N'Fisioterapia', N'Terapia de rehidratación',
                            N'Control de hipertensión', N'Manejo del dolor', N'Terapia respiratoria',
                            N'Curación de heridas', N'Control de diabetes'),
        s.Ini,
        CASE WHEN DATEADD(DAY, 5 + (s.Seq % 20), s.Ini) <= @hoy
             THEN DATEADD(DAY, 5 + (s.Seq % 20), s.Ini) END,
        CASE WHEN s.Seq % 17 = 0 THEN N'Suspendido'
             WHEN DATEADD(DAY, 5 + (s.Seq % 20), s.Ini) <= @hoy THEN N'Finalizado'
             ELSE N'Activo' END,
        40 + (s.Seq % 8) * 25
FROM    #TSrc s;

/* --- Facturas: una por cada 2da cita atendida y una por cada admision con alta --- */
CREATE TABLE #SrcF (Origen CHAR(1) NOT NULL, OrigenID INT NOT NULL, PacienteID INT NOT NULL,
                    Fecha DATE NOT NULL, Estado NVARCHAR(20) NOT NULL);
CREATE TABLE #MapF (FacturacionID INT NOT NULL, Origen CHAR(1) NOT NULL, OrigenID INT NOT NULL);

INSERT #SrcF (Origen, OrigenID, PacienteID, Fecha, Estado)
SELECT 'C', c.CitaID, c.PacienteID, CAST(c.FechaHora AS DATE),
       CASE WHEN c.CitaID % 23 = 0 THEN N'Anulada'
            WHEN c.CitaID % 5  = 0 THEN N'Pendiente'
            ELSE N'Pagada' END
FROM   Citas c
WHERE  c.Estado = N'Atendida' AND c.CitaID % 2 = 0;

INSERT #SrcF (Origen, OrigenID, PacienteID, Fecha, Estado)
SELECT 'A', a.AdmisionID, a.PacienteID, CAST(a.FechaAlta AS DATE),
       CASE WHEN a.AdmisionID % 7 = 0 THEN N'Pendiente' ELSE N'Pagada' END
FROM   Admisiones a
WHERE  a.FechaAlta IS NOT NULL;

/* MERGE ... ON 1 = 0 permite capturar el FacturacionID generado junto a su origen */
MERGE Facturacion AS t
USING #SrcF AS s ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT (PacienteID, FechaEmision, Estado) VALUES (s.PacienteID, s.Fecha, s.Estado)
OUTPUT inserted.FacturacionID, s.Origen, s.OrigenID INTO #MapF (FacturacionID, Origen, OrigenID);

INSERT DetalleFactura (FacturacionID, Concepto, CitaID, Monto)
SELECT m.FacturacionID, N'Consulta médica', c.CitaID, c.Costo
FROM   #MapF m
JOIN   Citas c ON m.Origen = 'C' AND c.CitaID = m.OrigenID;

INSERT DetalleFactura (FacturacionID, Concepto, TratamientoID, Monto)
SELECT m.FacturacionID, N'Tratamiento: ' + t.Descripcion, t.TratamientoID, t.Costo
FROM   #MapF m
JOIN   Tratamiento t ON (m.Origen = 'C' AND t.CitaID      = m.OrigenID)
                     OR (m.Origen = 'A' AND t.AdmisionID = m.OrigenID);

INSERT DetalleFactura (FacturacionID, Concepto, AdmisionID, Monto)
SELECT m.FacturacionID, N'Hospitalización', a.AdmisionID,
       CASE WHEN DATEDIFF(DAY, a.FechaIngreso, a.FechaAlta) < 1 THEN 1
            ELSE DATEDIFF(DAY, a.FechaIngreso, a.FechaAlta) END * 120.00
FROM   #MapF m
JOIN   Admisiones a ON m.Origen = 'A' AND a.AdmisionID = m.OrigenID;

DROP TABLE #TSrc;
DROP TABLE #SrcF;
DROP TABLE #MapF;
DROP TABLE #Nums;
GO

/* ===================== 5. VERIFICACION ===================== */

SELECT 'Paciente' AS Tabla, COUNT(*) AS Filas FROM Paciente
UNION ALL SELECT 'Consultorio',    COUNT(*) FROM Consultorio
UNION ALL SELECT 'Medico',         COUNT(*) FROM Medico
UNION ALL SELECT 'Citas',          COUNT(*) FROM Citas
UNION ALL SELECT 'Admisiones',     COUNT(*) FROM Admisiones
UNION ALL SELECT 'RecetasMedicas', COUNT(*) FROM RecetasMedicas
UNION ALL SELECT 'Tratamiento',    COUNT(*) FROM Tratamiento
UNION ALL SELECT 'Facturacion',    COUNT(*) FROM Facturacion
UNION ALL SELECT 'DetalleFactura', COUNT(*) FROM DetalleFactura;

/* Citas por estado y facturacion por estado (sanity check) */
SELECT Estado, COUNT(*) AS Citas FROM Citas GROUP BY Estado ORDER BY Citas DESC;
SELECT f.Estado, COUNT(DISTINCT f.FacturacionID) AS Facturas, SUM(d.Monto) AS Monto
FROM Facturacion f JOIN DetalleFactura d ON d.FacturacionID = f.FacturacionID
GROUP BY f.Estado;
GO

--comprobacion 
SELECT COUNT(*) FROM Citas