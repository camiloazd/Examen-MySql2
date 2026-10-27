-- Eventos Premier S.A.S. | Módulo 8: consultas del módulo de clientes y reservas
-- Ejecutar después de los módulos 01 al 06 (no depende del módulo 07 de pagos).
USE eventos_premier_db;

-- Datos de prueba: un cliente sin reservas y cinco reservas creadas con
-- crear_reserva, con fechas relativas a hoy para que las consultas muestren
-- resultados. Una de las reservas queda cancelada.
INSERT INTO clientes
(nombre_completo, identificacion, telefono, correo_electronico, tipo_cliente)
VALUES
('Andrés Felipe Ruiz', 'CC-DEMO-1002', '3104445566', 'andres.demo@example.com', 'Individual')
ON DUPLICATE KEY UPDATE nombre_completo = VALUES(nombre_completo);

CALL crear_reserva(1, 1, DATE_ADD(CURDATE(), INTERVAL '2 10' DAY_HOUR), DATE_ADD(CURDATE(), INTERVAL '2 14' DAY_HOUR), 'Cumpleaños, decoración azul');
CALL crear_reserva(2, 2, DATE_ADD(CURDATE(), INTERVAL '4 08' DAY_HOUR), DATE_ADD(CURDATE(), INTERVAL '4 12' DAY_HOUR), NULL);
CALL crear_reserva(3, 2, DATE_ADD(CURDATE(), INTERVAL '6 15' DAY_HOUR), DATE_ADD(CURDATE(), INTERVAL '6 18' DAY_HOUR), 'Reunión de junta directiva');
CALL crear_reserva(1, 2, DATE_ADD(CURDATE(), INTERVAL '20 09' DAY_HOUR), DATE_ADD(CURDATE(), INTERVAL '20 13' DAY_HOUR), NULL);
CALL crear_reserva(2, 3, DATE_ADD(CURDATE(), INTERVAL '10 16' DAY_HOUR), DATE_ADD(CURDATE(), INTERVAL '10 20' DAY_HOUR), 'Lanzamiento de producto');

UPDATE reservas
   SET estado_reserva = 'Cancelada'
 WHERE cliente_id = 3
   AND observaciones = 'Lanzamiento de producto';


-- 1. Clientes con más reservas.
-- Propósito: identificar a los clientes más frecuentes, con su total de
-- reservas y la fecha de su última reserva, de mayor a menor cantidad.
SELECT
    c.nombre_completo,
    COUNT(r.id) AS total_reservas,
    MAX(r.fecha_hora_inicio) AS ultima_reserva
FROM clientes c
JOIN reservas r ON r.cliente_id = c.id
GROUP BY c.id, c.nombre_completo
ORDER BY total_reservas DESC;


-- 2. Reservas de los próximos 7 días.
-- Propósito: ver los eventos que vienen esta semana para organizar salones
-- y personal.
SELECT
    c.nombre_completo AS cliente,
    s.nombre AS salon,
    r.fecha_hora_inicio AS fecha_evento,
    r.estado_reserva
FROM reservas r
JOIN clientes c ON c.id = r.cliente_id
JOIN salones s ON s.id = r.salon_id
WHERE r.fecha_hora_inicio BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
ORDER BY r.fecha_hora_inicio;


-- 3. Vista vista_reservas_cliente.
-- Propósito: resumen por cliente de cuántas reservas tiene confirmadas y
-- cuántas canceladas. Usa LEFT JOIN para incluir también a los clientes
-- que no tienen reservas (aparecen con 0).
CREATE OR REPLACE VIEW vista_reservas_cliente AS
SELECT
    c.nombre_completo,
    SUM(CASE WHEN r.estado_reserva = 'Confirmada' THEN 1 ELSE 0 END) AS reservas_confirmadas,
    SUM(CASE WHEN r.estado_reserva = 'Cancelada' THEN 1 ELSE 0 END) AS reservas_canceladas
FROM clientes c
LEFT JOIN reservas r ON r.cliente_id = c.id
GROUP BY c.id, c.nombre_completo;

SELECT * FROM vista_reservas_cliente;


-- 4. Clientes sin reservas.
-- Propósito: encontrar clientes registrados que nunca han reservado, para
-- hacerles seguimiento comercial. Se ordenan alfabéticamente.
SELECT
    c.nombre_completo,
    c.identificacion,
    c.tipo_cliente
FROM clientes c
LEFT JOIN reservas r ON r.cliente_id = c.id
WHERE r.id IS NULL
ORDER BY c.nombre_completo;


-- 5. Procedimiento consultarHistorialCliente(id_cliente).
-- Propósito: mostrar el historial completo de un cliente: salón, fechas,
-- estado y observaciones. Si una reserva no tiene observaciones, se muestra
-- 'Sin observaciones'.
DROP PROCEDURE IF EXISTS consultarHistorialCliente;

DELIMITER //

CREATE PROCEDURE consultarHistorialCliente(IN p_id_cliente INT)
BEGIN
    SELECT
        r.id AS reserva_id,
        s.nombre AS salon,
        r.fecha_hora_inicio,
        r.fecha_hora_fin,
        r.estado_reserva,
        COALESCE(r.observaciones, 'Sin observaciones') AS observaciones
    FROM reservas r
    JOIN salones s ON s.id = r.salon_id
    WHERE r.cliente_id = p_id_cliente
    ORDER BY r.fecha_hora_inicio;
END//

DELIMITER ;

-- Ejemplo: historial del cliente con id 2.
CALL consultarHistorialCliente(2);
