-- Eventos Premier S.A.S. | Módulo 4: vista y consultas analíticas
USE eventos_premier_db;

CREATE OR REPLACE VIEW vista_resumen_reservas AS
SELECT
    r.id AS reserva_id,
    c.nombre_completo AS nombre_cliente,
    s.nombre AS nombre_salon,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.total_horas,
    r.valor_total,
    s.estado AS estado_salon,
    r.estado_reserva
FROM reservas AS r
INNER JOIN clientes AS c ON c.id = r.cliente_id
INNER JOIN salones AS s ON s.id = r.salon_id;

-- 1. Reservas cuyo inicio ocurre dentro del rango indicado (cambiar fechas).
SELECT r.id, c.nombre_completo, s.nombre, r.fecha_hora_inicio,
       r.fecha_hora_fin, r.valor_total, r.estado_reserva
FROM reservas r
JOIN clientes c ON c.id = r.cliente_id
JOIN salones s ON s.id = r.salon_id
WHERE r.fecha_hora_inicio BETWEEN '2026-01-01 00:00:00' AND '2026-12-31 23:59:59'
ORDER BY r.fecha_hora_inicio;

-- 2. Salones disponibles para consulta con capacidad mayor a 50 personas.
SELECT id, nombre, capacidad, precio_hora, encargado_responsable
FROM salones
WHERE capacidad > 50
  AND estado = 'Disponible'
ORDER BY capacidad DESC;

-- 3. Clientes corporativos con más de 3 reservas confirmadas o finalizadas.
SELECT c.id, c.nombre_completo, c.identificacion,
       COUNT(r.id) AS total_reservas
FROM clientes c
JOIN reservas r ON r.cliente_id = c.id
WHERE c.tipo_cliente = 'Corporativo'
  AND r.estado_reserva IN ('Confirmada', 'Finalizada')
GROUP BY c.id, c.nombre_completo, c.identificacion
HAVING COUNT(r.id) > 3
ORDER BY total_reservas DESC;

-- 4. Ingresos recibidos por reserva, comparados con el valor contratado.
SELECT r.id AS reserva_id, c.nombre_completo, r.valor_total,
       COALESCE(SUM(p.monto_pagado), 0) AS total_pagado,
       r.valor_total - COALESCE(SUM(p.monto_pagado), 0) AS saldo_pendiente
FROM reservas r
JOIN clientes c ON c.id = r.cliente_id
LEFT JOIN pagos p ON p.reserva_id = r.id
GROUP BY r.id, c.nombre_completo, r.valor_total
ORDER BY saldo_pendiente DESC;

-- 5. Salones que más ingresos contratados acumulan.
SELECT s.id, s.nombre, COUNT(r.id) AS cantidad_reservas,
       COALESCE(SUM(CASE WHEN r.estado_reserva <> 'Cancelada'
                         THEN r.valor_total ELSE 0 END), 0) AS ingresos_contratados
FROM salones s
LEFT JOIN reservas r ON r.salon_id = s.id
GROUP BY s.id, s.nombre
ORDER BY ingresos_contratados DESC;

-- 6. Historial de cambios de precio.
SELECT ap.id, s.nombre AS salon, ap.usuario, ap.fecha_cambio,
       ap.precio_anterior, ap.precio_nuevo,
       (ap.precio_nuevo - ap.precio_anterior) AS variacion
FROM auditoria_precios ap
LEFT JOIN salones s ON s.id = ap.salon_id
ORDER BY ap.fecha_cambio DESC;
