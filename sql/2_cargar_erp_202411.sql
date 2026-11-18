USE TuriaDW;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @archivo  NVARCHAR(255) = N'ERP_ventas_202411.csv';
DECLARE @id_carga INT;

-- Paso 1: abrir el registro
INSERT INTO raw.log_cargas (nombre_archivo, fuente)
VALUES (@archivo, N'ERP');

-- Paso 2: anotar el número de la carga
SET @id_carga = SCOPE_IDENTITY();

-- Paso 3: archivo → #erp (tu código de F2-02a: DROP, CREATE y BULK INSERT, sin los SELECT)
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

BULK INSERT #erp
FROM 'C:\Proyectos\turia-pipeline-datos\entrada\erp\ERP_ventas_202411.csv'
WITH (
    FIELDTERMINATOR = ';',      -- las columnas están separadas por punto y coma
    ROWTERMINATOR   = '\n',     -- cada fila termina con un salto de línea
    FIRSTROW        = 2,        -- la fila 1 es la cabecera: empezar en la 2
    CODEPAGE        = '1252');   -- el archivo está en ANSI

-- Paso 4: #erp → raw.erp_ventas (13 columnas: las 2 fijas + las 11 del archivo, en el mismo orden arriba y abajo)
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

