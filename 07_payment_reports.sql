
-- ============================================================
-- EVENTOS PREMIER S.A.S.
-- MODULO 7: PAGOS, FACTURACION Y AUDITORIA DE ABONOS
-- MySQL 8.0+
-- ============================================================

USE eventos_premier_db;

-- 1. TABLA PARA AUDITAR LOS CAMBIOS EN LOS PAGOS
CREATE TABLE IF NOT EXISTS auditoria_abonos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_pago INT UNSIGNED NOT NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valor_anterior DECIMAL(12,2) NULL,
    valor_nuevo DECIMAL(12,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    INDEX idx_auditoria_abonos_pago (id_pago)
) ENGINE=InnoDB;


-- 2. FUNCION: CALCULAR EL SALDO PENDIENTE
DROP FUNCTION IF EXISTS calcular_valor_pendiente;

DELIMITER //

CREATE FUNCTION calcular_valor_pendiente(
    p_total_reserva DECIMAL(12,2),
    p_abono DECIMAL(12,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_reserva IS NULL OR p_abono IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN GREATEST(
        ROUND(p_total_reserva - p_abono, 2),
        0.00
    );
END//


-- 3. TRIGGER: AUDITAR LA INSERCION DE UN PAGO
DROP TRIGGER IF EXISTS auditar_abono_insert_trigger;

CREATE TRIGGER auditar_abono_insert_trigger
AFTER INSERT ON pagos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_abonos (
        id_pago,
        fecha_movimiento,
        valor_anterior,
        valor_nuevo,
        usuario
    )
    VALUES (
        NEW.id,
        CURRENT_TIMESTAMP,
        NULL,
        NEW.monto_pagado,
        USER()
    );
END//


-- 4. TRIGGER: AUDITAR LA ACTUALIZACION DE UN PAGO
DROP TRIGGER IF EXISTS auditar_abono_update_trigger;

CREATE TRIGGER auditar_abono_update_trigger
AFTER UPDATE ON pagos
FOR EACH ROW
BEGIN
    IF OLD.monto_pagado <> NEW.monto_pagado THEN
        INSERT INTO auditoria_abonos (
            id_pago,
            fecha_movimiento,
            valor_anterior,
            valor_nuevo,
            usuario
        )
        VALUES (
            NEW.id,
            CURRENT_TIMESTAMP,
            OLD.monto_pagado,
            NEW.monto_pagado,
            USER()
        );
    END IF;
END//

DELIMITER ;


-- 5. VISTA: FACTURACION CONSOLIDADA POR RESERVA
CREATE OR REPLACE VIEW vista_facturacion_reservas AS
SELECT
    c.nombre_completo AS nombre_cliente,
    r.fecha_hora_inicio AS fecha_reserva,
    r.id AS reserva_id,
    r.valor_total AS total_reserva,
    COALESCE(SUM(p.monto_pagado), 0.00) AS abono,
    calcular_valor_pendiente(
        r.valor_total,
        COALESCE(SUM(p.monto_pagado), 0.00)
    ) AS valor_pendiente
FROM reservas r
INNER JOIN clientes c
    ON c.id = r.cliente_id
LEFT JOIN pagos p
    ON p.reserva_id = r.id
WHERE r.estado_reserva <> 'Cancelada'
GROUP BY
    r.id,
    c.nombre_completo,
    r.fecha_hora_inicio,
    r.valor_total;


-- 6. CONSULTA: RESERVAS CON PAGOS PENDIENTES
SELECT
    nombre_cliente,
    fecha_reserva,
    total_reserva AS total,
    abono,
    valor_pendiente
FROM vista_facturacion_reservas
WHERE valor_pendiente > 0
ORDER BY fecha_reserva;


-- 7. CONSULTA: TOP 3 DE CLIENTES CUMPLIDOS
-- Primero se calcula cuánto se ha pagado de cada reserva y luego se cuentan,
-- por cliente, las reservas que ya están pagadas por completo.
SELECT
    c.id AS cliente_id,
    c.nombre_completo AS nombre_cliente,
    COUNT(*) AS reservas_pagadas_completamente
FROM clientes c
INNER JOIN (
    SELECT
        r.id,
        r.cliente_id
    FROM reservas r
    LEFT JOIN pagos p
        ON p.reserva_id = r.id
    WHERE r.estado_reserva <> 'Cancelada'
    GROUP BY
        r.id,
        r.cliente_id,
        r.valor_total
    HAVING r.valor_total <= COALESCE(SUM(p.monto_pagado), 0.00)
) AS reservas_pagadas
    ON reservas_pagadas.cliente_id = c.id
GROUP BY
    c.id,
    c.nombre_completo
ORDER BY
    reservas_pagadas_completamente DESC,
    nombre_cliente ASC
LIMIT 3;


-- 8. CONSULTA: HISTORIAL DE AUDITORIA DE ABONOS
SELECT
    id_pago,
    fecha_movimiento,
    valor_anterior,
    valor_nuevo,
    usuario
FROM auditoria_abonos
ORDER BY fecha_movimiento DESC;




SELECT calcular_valor_pendiente(500000.00, 200000.00);