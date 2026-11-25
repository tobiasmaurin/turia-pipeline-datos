USE TuriaDW;
GO

CREATE OR ALTER PROCEDURE raw.usp_cargar_erp
    @archivo  NVARCHAR(255),          -- p. ej. N'ERP_ventas_202412.csv'
    @codepage NVARCHAR(10)            -- N'1252' (ANSI) o N'65001' (UTF-8)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @carpeta         NVARCHAR(500) = N'C:\Proyectos\turia-pipeline-datos\entrada\erp\';
    DECLARE @id_carga        INT;
    DECLARE @sql             NVARCHAR(MAX);
    DECLARE @lineas_pie      INT;
    DECLARE @importe_pie     DECIMAL(14,2);
    DECLARE @lineas_archivo  INT;
    DECLARE @importe_archivo DECIMAL(14,2);
    DECLARE @msg             NVARCHAR(4000);

    -- Control: no cargar dos veces el mismo archivo (antes de abrir la transacción)
    IF EXISTS (SELECT 1 FROM raw.log_cargas WHERE nombre_archivo = @archivo AND estado = N'OK')
    BEGIN
        PRINT N'El archivo ' + @archivo + N' ya esta cargado: no se hace nada';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Paso 1: abrir el registro
        INSERT INTO raw.log_cargas (nombre_archivo, fuente)
        VALUES (@archivo, N'ERP');

        -- Paso 2: anotar el número de la carga
        SET @id_carga = SCOPE_IDENTITY();

        -- Paso 3a: tabla temporal (fuera del SQL dinámico)
        DROP TABLE IF EXISTS #erp;

        CREATE TABLE #erp (
            num_pedido      NVARCHAR(200) NULL,
            fecha_pedido    NVARCHAR(200) NULL,
            cod_cliente     NVARCHAR(200) NULL,
            cod_comercial   NVARCHAR(200) NULL,
            linea           NVARCHAR(200) NULL,
            cod_producto    NVARCHAR(200) NULL,
            descripcion     NVARCHAR(255) NULL,
            cantidad        NVARCHAR(255) NULL,
            precio_unitario NVARCHAR(255) NULL,
            dto_pct         NVARCHAR(255) NULL,
            importe_neto    NVARCHAR(255) NULL
        );

        -- Paso 3b: archivo → #erp con BULK INSERT dinámico
        SET @sql = N'BULK INSERT #erp
                    FROM ''' + @carpeta + @archivo + N'''
                    WITH (
                        FIELDTERMINATOR = '';'',
                        ROWTERMINATOR   = ''\n'',
                        FIRSTROW        = 2,
                        CODEPAGE        = ''' + @codepage + N''');';
        PRINT @sql;
        EXEC sp_executesql @sql;

        -- Control: el archivo tiene que cuadrar con su fila TOTAL
        SELECT @lineas_pie  = CAST(linea AS INT),
               @importe_pie = CAST(REPLACE(importe_neto, ',', '.') AS DECIMAL(14,2))
        FROM #erp
        WHERE num_pedido = 'TOTAL';                       -- solo la fila TOTAL

        SELECT @lineas_archivo  = COUNT(*),               -- cuántas líneas hay sin la TOTAL
               @importe_archivo = SUM(CAST(REPLACE(importe_neto, ',', '.') AS DECIMAL(14,2)))   -- cuánto suman
        FROM #erp
        WHERE num_pedido <> 'TOTAL';                      -- todas menos la TOTAL

        IF @lineas_pie IS NULL OR @lineas_archivo <> @lineas_pie OR @importe_archivo <> @importe_pie
        BEGIN
            SET @msg = CONCAT(N'El archivo ', @archivo, N' no cuadra con su fila TOTAL. Líneas: ',
                              @lineas_archivo, N' (pie: ', @lineas_pie, N'). Importe: ',
                              @importe_archivo, N' (pie: ', @importe_pie, N').');
            THROW 50001, @msg, 1;
        END

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
    END TRY
    BEGIN CATCH
        -- 1. Anular todo lo de esta carga
        IF @@TRANCOUNT > 0 ROLLBACK;

        -- 2. Dejar constancia del error (después del ROLLBACK, para que no se deshaga)
        INSERT INTO raw.log_cargas (nombre_archivo, fuente, fecha_fin, estado, mensaje_error)
        VALUES (@archivo, N'ERP', SYSDATETIME(), N'ERROR', ERROR_MESSAGE());

        -- 3. Volver a lanzar el error para que quien llamó se entere
        THROW;
    END CATCH
END;
GO