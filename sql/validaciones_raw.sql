USE TuriaDW;

-- Pie de la carga 3
SELECT linea AS lineas_segun_pie,
        importe_neto AS importe_segun_pie
FROM raw.erp_ventas 
WHERE id_carga = 3 
AND num_pedido = 'TOTAL';

SELECT COUNT(*) AS lineas_cargadas,
       SUM(CAST(REPLACE(importe_neto, ',', '.') AS DECIMAL(14,2))) AS suma_lineas
FROM raw.erp_ventas 
WHERE id_carga = 3 
AND num_pedido <> 'TOTAL';

-- Total en raw y acentos del archivo UTF-8
SELECT COUNT(*) AS filas 
FROM raw.erp_ventas;

SELECT DISTINCT descripcion 
FROM raw.erp_ventas
WHERE id_carga = 3 
AND descripcion LIKE N'%ó%';