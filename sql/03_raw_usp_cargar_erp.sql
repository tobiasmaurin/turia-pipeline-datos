USE TuriaDW;
GO

CREATE OR ALTER PROCEDURE raw.usp_cargar_erp
    @archivo  NVARCHAR(255),          -- p. ej. N'ERP_ventas_202412.csv'
    @codepage NVARCHAR(10)            -- N'1252' (ANSI) o N'65001' (UTF-8)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @carpeta  NVARCHAR(500) = N'C:\Proyectos\turia-pipeline-datos\entrada\erp\';
    DECLARE @id_carga INT;
    DECLARE @sql      NVARCHAR(MAX);

    IF EXISTS (SELECT 1 FROM raw.log_cargas WHERE nombre_archivo = @archivo AND estado = N'OK')
    BEGIN
        PRINT N'El archivo ' + @archivo + N' ya esta cargado: no se hace nada';
        RETURN;
    END

    BEGIN TRANSACTION;

    -- Paso 1: abrir el registro
    INSERT INTO raw.log_cargas (nombre_archivo, fuente)
    VALUES (@archivo, N'ERP');

    -- Paso 2: anotar el número de la carga
    SET @id_carga = SCOPE_IDENTITY();

    -- Paso 3a: tabla temporal (fuera del SQL dinámico)
   DROP TABLE IF EXISTS #erp;

    CREATE TABLE #erp (               
        num_pedido     NVARCHAR(200)     NULL,
        fecha_pedido   NVARCHAR(200)     NULL,
        cod_cliente    NVARCHAR(200)     NULL,
        cod_comercial  NVARCHAR(200)     NULL,
        linea          NVARCHAR(200)     NULL,
        cod_producto   NVARCHAR(200)     NULL,
        descripcion    NVARCHAR(255)     NULL,
        cantidad       NVARCHAR(255)     NULL,
        precio_unitario NVARCHAR(255)    NULL,
        dto_pct        NVARCHAR(255)     NULL,
        importe_neto   NVARCHAR(255)     NULL
    );

    -- Paso 3b: archivo → #erp con BULK INSERT dinámico (tu juguete 2, con #erp en lugar de #socios)
    SET @sql = N'BULK INSERT #erp
                FROM ''' + @carpeta + @archivo + N'''
                    WITH (
                    FIELDTERMINATOR = '';'',      
                    ROWTERMINATOR   = ''\n'',     
                    FIRSTROW        = 2,        
                    CODEPAGE        = ''' + @codepage + N''');';
    PRINT @sql;
    EXEC sp_executesql @sql;

    -- Paso 4: #erp → raw.erp_ventas
    INSERT INTO raw.erp_ventas (id_carga, nombre_archivo,
                            num_pedido, fecha_pedido, cod_cliente, cod_comercial, linea,
                            cod_producto, descripcion, cantidad, precio_unitario, dto_pct, importe_neto)
    SELECT @id_carga, @archivo,
           num_pedido, fecha_pedido, cod_cliente, cod_comercial, linea,
           cod_producto, descripcion, cantidad, precio_unitario, dto_pct, importe_neto
    FROM #erp;

    -- Paso 5: cerrar el registro
    UPDATE raw.log_cargas
    SET fecha_fin        = SYSDATETIME(),
        filas_leidas     = (SELECT COUNT(*) FROM #erp),
        filas_cargadas   = (SELECT COUNT(*) FROM raw.erp_ventas WHERE id_carga = @id_carga),
        filas_rechazadas = 0,
        estado           = N'OK'
    WHERE id_carga = @id_carga;

    COMMIT;
END;
GO

--EXEC raw.usp_cargar_erp @archivo = N'ERP_ventas_202412.csv', @codepage = N'1252'; YA CARGADO (CARGA 2)
--EXEC raw.usp_listar_cargas;