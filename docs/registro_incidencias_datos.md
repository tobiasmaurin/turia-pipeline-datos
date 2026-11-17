# Registro de incidencias de datos

Problemas detectados en las fuentes de Distribuciones Turia **antes de cargarlas**, al perfilar los archivos del histórico (noviembre de 2024 a octubre de 2026). Cada fila describe un **hecho** observado; las decisiones de negocio se recogen en las preguntas del final y, cuando se respondan, pasan al registro de decisiones.

- **Perfilado:** 17-11-2026, con el Bloc de notas (codificación y estructura) y Power Query (perfil de columnas sobre todo el conjunto de datos, valores distintos, duplicados).
- **Archivos revisados:** ERP `ERP_ventas_202411.csv`, `ERP_ventas_202508.csv`, `ERP_ventas_202601.csv` y `ERP_ventas_202610.csv` (y los meses intermedios para fechar el cambio de formato); CRM `clientes_CRM_2026-10.xlsx` (hojas Clientes y Comerciales); catálogo `catalogo_productos_2026-10.xlsx`.
- **Alcance observado:** recuentos de los archivos revisados. Los totales de los 24 meses se medirán en la carga y se publicarán en el informe de calidad de datos.

Estado: **Abierta** (pendiente de tratar), **Pregunta** (necesita una decisión de negocio), **Por confirmar** (hay que volver a comprobarla).

## ERP: exportación mensual de ventas (CSV)

| ID | Archivo | Columna | Problema | Ejemplo real | Alcance observado | Impacto si no se trata | Tratamiento propuesto | Preguntar a | Estado |
|---|---|---|---|---|---|---|---|---|---|
| ERP-01 | Todos | (archivo) | La codificación cambia: Windows-1252 (ANSI) hasta 202506 y UTF-8 desde 202507 (actualización del ERP) | `Alubias garrofó 1 kg` | 8 archivos ANSI, 16 UTF-8 | Si se cargan todos con la misma codificación, los acentos y la ñ se rompen en la mitad de los archivos y una misma descripción aparece con dos valores distintos | Cargar cada archivo indicando su codificación (`CODEPAGE` 1252 o 65001) | — | Abierta |
| ERP-02 | Todos | FechaPedido | Dos formatos de fecha: `dd/mm/aaaa` hasta 202506 y `aaaa-mm-dd` desde 202507 | `01/11/2024` / `2026-01-01` | Todos los archivos (cambio en 202507) | Si se convierte con el formato equivocado, da error o intercambia día y mes sin avisar | Convertir con el formato explícito según el archivo; las filas que no conviertan se rechazan y se registran | — | Abierta |
| ERP-03 | Todos | PrecioUnitario, ImporteNeto | Números con coma decimal, guardados como texto | `7,71` / `38,55` | Todas las filas | SQL no los reconoce como números: error o valores mal leídos | Reemplazar la coma por punto y convertir a `DECIMAL` | — | Abierta |
| ERP-04 | Todos | DtoPct | El formato del descuento cambia: entero hasta 202506 y con dos decimales desde 202507. Es el **mismo porcentaje**, no una fracción | `10` / `10,00` | Todas las filas | Si se interpreta `10,00` como fracción, el importe recalculado sale mal | Tratarlo como porcentaje en los dos formatos (dividir por 100 una sola vez) | — | Por confirmar |
| ERP-05 | Todos | (fila 1) | La primera fila es la cabecera, no un dato | `NumPedido;FechaPedido;...` | 1 fila por archivo | Se cargaría como una venta con texto en lugar de números | Saltarla al cargar | — | Abierta |
| ERP-06 | Todos | (última fila) | La última fila es un pie de control: `TOTAL`, número de líneas del archivo y suma de `ImporteNeto`. Cuenta las filas **tal como llegan, duplicados incluidos** | `TOTAL;;;;2880;;;;;;278252,01` (202601) | 1 fila por archivo | Si se carga como dato, duplica la facturación del mes | Usarla como **control de la carga** (filas y suma cargadas en `raw` = pie) y excluirla después. Control de la limpieza: filas en `raw` − filas eliminadas = filas limpias | — | Abierta |
| ERP-07 | Todos | CodCliente | Códigos en minúsculas | `cl0092` | 15 líneas en 202601 | El mismo cliente aparece como dos clientes distintos | Pasar a mayúsculas | — | Abierta |
| ERP-08 | Todos | CodCliente | Espacio invisible al final del código (longitud 7 en lugar de 6) | `CL0231␣` | 19 líneas en 202601 | El mismo cliente aparece como dos clientes distintos y falla el cruce con el CRM | Quitar espacios (`TRIM`) | — | Abierta |
| ERP-09 | Todos | CodProducto | Espacio invisible delante del código (longitud 6 en lugar de 5) | `␣P0103` | ~20 líneas en 202601 | Falla el cruce con el catálogo | Quitar espacios (`TRIM`) | — | Por confirmar |
| ERP-10 | Todos | NumPedido + Linea | Líneas duplicadas dentro del mismo archivo (misma clave de pedido y línea) | — | 9 claves repetidas (9 filas sobrantes) en 202601 | La facturación del mes se infla | Quedarse con una fila por clave; registrar las eliminadas | — | Abierta (falta confirmar si las dos filas son idénticas en todas las columnas) |
| ERP-11 | Todos | Cantidad, ImporteNeto | Líneas con cantidad e importe negativos | `-2` / `-25,65` (Vino tinto bag in box, 202601) | 6 líneas en 202601 | Restan facturación. Si son devoluciones, quitarlas sobrevalora las ventas; si son errores, dejarlas las infravalora | Pendiente de la respuesta de negocio | Jordi | Pregunta |
| ERP-12 | Todos | CodProducto | Líneas con el código `PORTES`, que no sigue el formato de producto y no existe en el catálogo | `PORTES;Portes;1;13,00` | 185 líneas en 202601 | Si se excluyen o se incluyen sin criterio, la facturación no cuadra con contabilidad; además no tienen categoría en el modelo | Pendiente de la respuesta de negocio | Jordi | Pregunta |
| ERP-13 | 202508 | CodComercial, CodCliente | Líneas con comercial `ADM` y cliente `CL0000`. Ninguno de los dos existe en los maestros (hoja Comerciales y CRM) | `25080988;2025-08-02;CL0000;ADM;...` | 9 líneas en 202508 | Ventas sin cliente ni comercial válidos: aparecerían "(En blanco)" en los informes y no se sabe si son ventas reales | Pendiente de la respuesta de negocio | Jordi | Pregunta |

## CRM: clientes (Excel)

| ID | Hoja | Columna | Problema | Ejemplo real | Alcance observado | Impacto si no se trata | Tratamiento propuesto | Preguntar a | Estado |
|---|---|---|---|---|---|---|---|---|---|
| CRM-01 | Clientes | Código, CIF, Nombre cliente | Clientes duplicados: misma empresa con dos códigos distintos (mismo CIF una vez normalizado, nombre escrito distinto) | — | 11 clientes por CIF normalizado + 1 por nombre (Getafe, uno de los dos con CIF vacío) = 12 | Las ventas de un cliente quedan partidas en dos códigos: rankings, número de clientes y clientes en riesgo salen mal | Tabla de equivalencias código duplicado → código que se conserva | Marta | Pregunta (el n.º 12 está por confirmar) |
| CRM-02 | Clientes | Provincia | 7 provincias reales (Valencia, Castellón, Alicante, Murcia, Madrid, Barcelona, Illes Balears) escritas de unas 30 formas: mayúsculas, minúsculas, valenciano o catalán, espacios al final, nombres compuestos | `València`, `VALENCIA`, `Alacant`, `Región de Murcia`, `I. Baleares` | 337 filas, ~30 valores distintos | Las ventas por provincia se reparten en grupos falsos | Tabla de equivalencias valor escrito → provincia normalizada | — | Abierta |
| CRM-03 | Clientes | CIF | Formatos sucios: minúsculas, guiones, espacios, puntos. Los NIF de autónomo (8 dígitos + letra) **son válidos** | `b46723482`, `B-46758108`, `B 46948675`, `␣E46078176␣` | Varias decenas de filas | Impide detectar duplicados y cruzar con otros sistemas | Normalizar: mayúsculas y sin guiones, espacios ni puntos | — | Abierta |
| CRM-04 | Clientes | CIF | CIF vacío | — | 9 filas | Esos clientes no se pueden comparar por CIF (un vacío no es un duplicado) | Buscar duplicados por nombre normalizado y avisar a Comercial para completarlos | Marta | Abierta |
| CRM-05 | Clientes | Código postal | Guardado como número: pierde el 0 inicial en Alicante (03), Illes Balears (07) y Barcelona (08) | `3173` en lugar de `03173` | Clientes de esas 3 provincias | Códigos postales inválidos (4 dígitos); fallaría un cruce con datos geográficos | Guardar como texto de 5 caracteres, completando con ceros a la izquierda | — | Abierta |
| CRM-06 | Clientes | Fecha alta | Algunas fechas son texto en lugar de fecha | `03/09/2013` (texto) | 14 filas | La columna no se puede convertir de una sola vez | Convertir los dos casos (fecha de Excel y texto `dd/mm/aaaa`) | — | Abierta |
| CRM-07 | Clientes | Comercial asignado | Vacío | — | 11 filas | Clientes sin comercial: no se pueden asignar sus ventas a nadie en el informe de ventas frente a objetivos | Pendiente de la respuesta de negocio | Marta | Pregunta |
| CRM-08 | Clientes | Tipo cliente, Población, Email, Teléfono | Campos vacíos | — | Tipo 15, Población 6, Email 43, Teléfono 25 | Análisis por tipo de cliente incompleto ("Sin informar"); no afecta a la facturación | Mostrar "Sin informar" y avisar a Comercial | — | Abierta |
| CRM-09 | Clientes | Estado | El estado "Activo" no está comprobado con las compras: puede haber clientes "Activo" que ya no compran | — | Sin medir todavía | Recuentos de clientes activos inflados | Definir "activo" como "con compras en los últimos N meses" y medirlo con el ERP | Marta (valor de N) | Pregunta |
| CRM-10 | Clientes / ERP | Comercial asignado / CodComercial | El CRM guarda el comercial asignado **hoy**; el ERP guarda el comercial de **cada pedido**. C08 aparece en 2026 | — | Sin analizar todavía | Si un cliente cambió de comercial, sus ventas antiguas se atribuirían a quien no las hizo | Pendiente de análisis y de la respuesta de negocio | Marta | Pregunta |

## Catálogo de productos (Excel)

| ID | Columna | Problema | Ejemplo real | Alcance observado | Impacto si no se trata | Tratamiento propuesto | Preguntar a | Estado |
|---|---|---|---|---|---|---|---|---|
| CAT-01 | Código | Sin problemas: formato homogéneo (`P` + 4 dígitos) y sin repetidos | `P0001` | 103 productos | — | — | — | Sin incidencia |
| CAT-02 | Categoría | Misma categoría escrita de varias formas: mayúsculas, minúsculas, espacios al final, abreviaturas, singular y plural | `Bebidas sin alcohol`, `BEBIDAS SIN ALCOHOL`, `Bebidas s/alcohol`, `Cervezas` / `cervezas` | Recuento de categorías reales y de formas escritas pendiente | Las ventas por categoría se reparten en grupos falsos | Tabla de equivalencias valor escrito → categoría normalizada | — | Por confirmar (contar) |
| CAT-03 | Precio tarifa | Guardado como texto, con varios formatos: con y sin `€`, coma o punto decimal, espacios | `18,48 €`, `14,15€`, `3.59`, `␣7,28␣` | Todas las filas; 2 vacíos | No se puede operar con el precio | Quitar `€` y espacios, unificar el decimal y convertir a `DECIMAL` | — | Abierta |
| CAT-04 | Precio tarifa | Es el precio **actual** (coincide con el ERP de 202610) y no el histórico: hubo subidas de tarifa | `P0001`: catálogo 7,28 = ERP 202610 7,28; ERP 202411 6,90 | Todos los productos | Valorar ventas pasadas con el precio del catálogo daría importes que no existieron | Para las ventas usar siempre el precio y el importe del ERP; el precio del catálogo solo como tarifa vigente | — | Abierta |
| CAT-05 | Coste unitario | Valores con decimales de coma flotante | `8.130000000000001`, `9.859999999999999` | Varios productos | Diferencias de fracciones de céntimo en los márgenes | Guardar como `DECIMAL(10,2)` | — | Abierta |
| CAT-06 | Activo | Mismo valor escrito de varias formas y vacíos | `Sí`, `SI`, `si`, `No`, (vacío) | 103 productos | No se puede filtrar productos activos de forma fiable | Normalizar a Sí / No; definir qué significa el vacío | Marta / Compras | Pregunta |
| CAT-07 | Activo | Productos marcados como activos que ya no se venden | `P0004`: "Sí" en el catálogo, sin ventas en 202601 | Sin medir todavía | El catálogo "activo" incluye productos descatalogados | Medir la última venta de cada producto con el ERP y aplicar el criterio de descatalogado | Marta / Compras | Pregunta |

## Preguntas para el negocio

**Jordi Peris (Finanzas)**: todo lo que cambia la facturación.
1. **ERP-11:** las líneas con cantidad e importe negativos, ¿son devoluciones? ¿Contabilidad las resta de la facturación?
2. **ERP-12:** los `PORTES`, ¿se facturan al cliente y cuentan como facturación? ¿Se informan aparte de los productos?
3. **ERP-13:** las líneas con comercial `ADM` y cliente `CL0000`, ¿qué son? ¿Son ventas reales?

**Marta Ferrer (Comercial)**: clientes y comerciales.
4. **CRM-01:** los clientes duplicados, ¿son la misma empresa? ¿Qué código se conserva?
5. **CRM-07:** ¿qué comercial tienen los 11 clientes sin comercial asignado?
6. **CRM-10:** para el informe de ventas frente a objetivos, ¿las ventas se atribuyen al comercial que hizo cada pedido o al que tiene el cliente hoy?
7. **CRM-09:** ¿cuántos meses sin comprar hacen que un cliente deje de considerarse activo?
8. **CAT-06 / CAT-07:** ¿cuándo se considera descatalogado un producto? ¿Qué significa el "Activo" vacío? (o Compras, si es quien lo decide)

## Pendiente de revisar
- **Posibles duplicados entre archivos distintos:** no se ven mirando un archivo cada vez. Se revisan al juntar los 24 archivos en la carga.
- **Objetivos de Finanzas e incidencias de Logística:** solo vistos por encima. Se perfilan al trabajarlos en Power Query.
