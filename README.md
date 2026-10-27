# Sistema de Reservas de Salones — Eventos Premier S.A.S.

Base de datos en **MySQL 8.0+ (InnoDB)** para administrar los salones, clientes, reservas y pagos de Eventos Premier S.A.S. Incluye funciones, triggers de auditoría, vistas, procedimientos almacenados y consultas de análisis.

## Estructura del proyecto

| # | Archivo | Qué hace |
|---|---|---|
| 01 | `01_schema_ddl.sql` | Crea la base `eventos_premier_db` con sus tablas, llaves, restricciones e índices. |
| 02 | `02_functions.sql` | Funciones `calcular_total_reserva` (total con IVA del 19 %) y `verificar_disponibilidad`. |
| 03 | `03_triggers.sql` | Triggers que cambian el estado del salón y auditan cambios de precio y de estado de reserva. |
| 04 | `04_views_queries.sql` | Vista `vista_resumen_reservas` y seis consultas de negocio. |
| 05 | `05_sample_data.sql` | Datos de demostración: 3 salones y 3 clientes. |
| 06 | `06_procedures.sql` | Procedimiento `crear_reserva`, que crea reservas validando fechas, cliente y cruces de horario. |
| 07 | `07_payment_reports.sql` | Módulo de pagos y facturación. |
| 08 | `08_consultas_clientes_reservas.sql` | Módulo de clientes y reservas: consultas, vista `vista_reservas_cliente` y procedimiento `consultarHistorialCliente`. |

## Modelo de datos

```
clientes 1 ──< reservas >── 1 salones
                   │
                   1
                   │
                   ^
                 pagos
```

- **salones:** nombre, capacidad, precio por hora, estado (`Disponible`, `Ocupado`, `En mantenimiento`) y encargado.
- **clientes:** nombre completo, identificación única, contacto y tipo (`Individual` o `Corporativo`).
- **reservas:** salón, cliente, fecha y hora de inicio y fin, horas, valor total, estado (`Confirmada`, `Cancelada`, `Finalizada`) y observaciones.
- **pagos:** abonos de cada reserva con monto, método y referencia.
- **auditoria_precios** y **auditoria_reservas:** historial de cambios de precio y de estado.

## Instalación

### Requisitos

- MySQL Server 8.0 o superior.
- MySQL Workbench o la consola de MySQL.
- Un usuario con permiso para crear bases de datos, funciones, triggers y procedimientos.

### Orden de ejecución

Los archivos se ejecutan **completos y en este orden**, porque cada uno usa lo que creó el anterior:

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08
```

**En MySQL Workbench:** abre cada archivo, ejecútalo completo con el rayo (⚡) y pasa al siguiente. Ejecutarlos completos es necesario para que Workbench lea bien los bloques `DELIMITER`. Al terminar, actualiza el panel **Schemas** y selecciona `eventos_premier_db`.

**Desde la consola**, en la carpeta del proyecto:

```bash
mysql -u root -p < 01_schema_ddl.sql
mysql -u root -p < 02_functions.sql
mysql -u root -p < 03_triggers.sql
mysql -u root -p < 04_views_queries.sql
mysql -u root -p < 05_sample_data.sql
mysql -u root -p < 06_procedures.sql
mysql -u root -p < 07_payment_reports.sql
mysql -u root -p < 08_consultas_clientes_reservas.sql
```

Si tu usuario no es `root`, cámbialo por el tuyo.

## Módulos

### Funciones (02)

```sql
SELECT calcular_total_reserva(160000.00, 3.00) AS total;
-- 571200.00  (160.000 × 3 horas + 19 % de IVA)

SELECT verificar_disponibilidad(1, '2026-12-10 09:00:00', '2026-12-10 12:00:00') AS disponible;
-- 1 = libre | 0 = ocupado, en mantenimiento, rango inválido o salón inexistente
```

### Triggers (03)

| Trigger | Cuándo se activa | Qué hace |
|---|---|---|
| `actualizar_estado_salon_trigger` | Al crear una reserva | Marca el salón como `Ocupado`. |
| `liberar_salon_trigger` | Al borrar una reserva | Deja el salón `Disponible` si ya no tiene reservas confirmadas. |
| `auditoria_precios_trigger` | Al cambiar `precio_hora` | Guarda el precio anterior, el nuevo, el usuario y la fecha. |
| `auditoria_estado_reserva_trigger` | Al cambiar `estado_reserva` | Guarda el estado anterior y el nuevo. |

### Consultas de negocio (04)

1. Reservas que empiezan dentro de un rango de fechas.
2. Salones disponibles con capacidad mayor a 50 personas.
3. Clientes corporativos con más de 3 reservas confirmadas o finalizadas.
4. Saldo pendiente de cada reserva.
5. Ingresos contratados por salón.
6. Historial de cambios de precio.

### Crear reservas (06)

```sql
CALL crear_reserva(1, 1, '2026-12-10 09:00:00', '2026-12-10 12:00:00', 'Reunión empresarial');
```

Calcula las horas y el valor con IVA, verifica que el cliente exista y que el salón no esté en mantenimiento, y rechaza la reserva si se cruza con otra confirmada. Si algo falla, revierte toda la operación.

### Pagos y facturación (07)

- `calcular_valor_pendiente`: calcula el saldo que falta por pagar.
- `vista_facturacion_reservas`: total de la reserva, abonos y saldo pendiente.
- `auditar_abono_insert_trigger` y `auditar_abono_update_trigger`: registran los abonos nuevos y sus cambios.
- Consultas de reservas con saldo pendiente, top 3 de clientes con reservas pagadas por completo e historial de abonos.

```sql
SELECT calcular_valor_pendiente(500000, 200000) AS valor_pendiente;
SELECT * FROM vista_facturacion_reservas WHERE valor_pendiente > 0;
SELECT * FROM auditoria_abonos ORDER BY fecha_movimiento DESC;
```

### Clientes y reservas (08)

Primero carga datos de prueba: un cliente sin reservas y cinco reservas creadas con `crear_reserva`, con fechas calculadas a partir del día en que se ejecuta. Una de ellas queda cancelada. Así todas las consultas muestran resultados.

| Requerimiento | Qué muestra |
|---|---|
| Clientes con más reservas | Nombre, total de reservas y fecha de la última, de mayor a menor. |
| Reservas de los próximos 7 días | Cliente, salón, fecha del evento y estado. |
| Vista `vista_reservas_cliente` | Por cliente: reservas confirmadas y canceladas (incluye a los que tienen 0). |
| Clientes sin reservas | Clientes que nunca han reservado, en orden alfabético. |
| Procedimiento `consultarHistorialCliente(id)` | Todas las reservas del cliente con salón, fechas, estado y observaciones. |

```sql
SELECT * FROM vista_reservas_cliente;
CALL consultarHistorialCliente(2);
```

Cada consulta tiene un comentario en el archivo que explica su propósito.

## Decisiones de diseño

- **Dinero en `DECIMAL`:** evita los errores de redondeo de `FLOAT`.
- **Integridad:** no se puede borrar un salón o un cliente que tenga reservas. Los pagos sí se borran junto con su reserva.
- **Cruces de horario:** dos reservas se cruzan si una empieza antes de que la otra termine. Una reserva que termina justo cuando empieza otra no cuenta como cruce.
- **Índices:** aceleran las búsquedas por estado, capacidad, cliente, salón y fechas.
- **Auditoría:** las tablas de auditoría no tienen llave foránea, para no perder el historial si se archiva un salón.

### Nota sobre el estado del salón

Por requerimiento del ejercicio, el salón pasa a `Ocupado` apenas se crea cualquier reserva, aunque sea para dentro de un mes. En un sistema real convendría usar `estado` solo para cosas como el mantenimiento y calcular la disponibilidad por fecha con `verificar_disponibilidad`. Por eso las reservas se crean siempre con `crear_reserva`.

## Autores

| Módulo | Autor |
|---|---|
| 07 — Pagos y facturación | Nestor Santiago Cobos Manrique |
| 08 — Clientes y reservas | Juan Camilo Lopera Escamilla |

**Tecnología:** MySQL 8.0+, SQL, InnoDB.
