
--Script para crear base de datos 'TuriaDW', esquemas 'raw, stg y dw' y tabla 'log_cargas' - Tobias Maurin - 21/10/2026

-- 01- Consulta para crear base de datos
IF DB_ID ('TuriaDW') IS NULL
CREATE DATABASE TuriaDW;

GO
USE TuriaDW; 
GO


-- 02- Consulta para crear esquemas
-- Datos originales
IF SCHEMA_ID ('raw') IS NULL
EXEC('CREATE SCHEMA raw');

GO

-- Datos preparados
IF SCHEMA_ID ('stg') IS NULL
EXEC('CREATE SCHEMA stg');

GO

-- Datos listos para analizar
IF SCHEMA_ID ('dw') IS NULL
EXEC('CREATE SCHEMA dw');

GO


--03-Consulta para crear tabla

IF OBJECT_ID ('raw.log_cargas', 'U') IS NULL
	CREATE TABLE raw.log_cargas (
		id_carga				INT IDENTITY (1,1) NOT NULL,
		nombre_archivo			NVARCHAR (255)     NOT NULL,
		fuente					NVARCHAR (50)     NOT NULL,
		fecha_inicio			DATETIME2(0)	   NOT NULL CONSTRAINT df_log_cargas_fecha_inicio DEFAULT SYSDATETIME(),
		fecha_fin				DATETIME2(0)	   NULL,
		filas_leidas			INT				   NULL,
		filas_cargadas			INT				   NULL,
		filas_rechazadas		INT				   NULL,
		estado					NVARCHAR (20)	   NOT NULL CONSTRAINT df_log_cargas_estado DEFAULT N'EN CURSO',
		mensaje_error			NVARCHAR (MAX)     NULL,
		CONSTRAINT pk_log_cargas PRIMARY KEY (id_carga)
	    );
GO

