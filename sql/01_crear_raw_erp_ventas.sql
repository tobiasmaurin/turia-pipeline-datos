USE TuriaDW;
GO

IF OBJECT_ID('raw.erp_ventas', 'U') IS NULL
CREATE TABLE raw.erp_ventas (
    id_fila        INT IDENTITY(1,1) NOT NULL,   -- número interno de cada fila
    id_carga       INT               NOT NULL,   -- de qué carga viene
    nombre_archivo NVARCHAR(255)     NOT NULL,   -- de qué archivo viene
    num_pedido     NVARCHAR(200)     NULL,
    fecha_pedido   NVARCHAR(200)     NULL,
    cod_cliente    NVARCHAR(200)     NULL,
    cod_comercial  NVARCHAR(200)     NULL,
    linea          NVARCHAR(200)     NULL,
    cod_producto   NVARCHAR(200)     NULL,
    descripcion    NVARCHAR(255)     NULL,
    cantidad       NVARCHAR(255)     NULL,
    precio_unitario NVARCHAR(255)     NULL,
    dto_pct        NVARCHAR(255)     NULL,
    importe_neto   NVARCHAR(255)     NULL,
    CONSTRAINT pk_erp_ventas PRIMARY KEY (id_fila),
    CONSTRAINT fk_erp_ventas_log_cargas FOREIGN KEY (id_carga)
        REFERENCES raw.log_cargas (id_carga)
);
GO