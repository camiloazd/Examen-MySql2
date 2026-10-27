-- Eventos Premier S.A.S. | Módulo 2: funciones
USE eventos_premier_db;

DROP FUNCTION IF EXISTS calcular_total_reserva;
DROP FUNCTION IF EXISTS verificar_disponibilidad;

DELIMITER //

CREATE FUNCTION calcular_total_reserva(
    p_precio_hora DECIMAL(10,2),
    p_horas DECIMAL(5,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_total DECIMAL(12,2);

    IF p_precio_hora IS NULL OR p_horas IS NULL
       OR p_precio_hora < 0 OR p_horas <= 0 THEN
        RETURN NULL;
    END IF;

    SET v_total = ROUND(p_precio_hora * p_horas * 1.19, 2);
    RETURN v_total;
END//

CREATE FUNCTION verificar_disponibilidad(
    p_salon_id INT,
    p_fecha_inicio DATETIME,
    p_fecha_fin DATETIME
)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_salon_existe INT DEFAULT 0;
    DECLARE v_salon_estado VARCHAR(30);
    DECLARE v_cruces INT DEFAULT 0;

    IF p_salon_id IS NULL OR p_fecha_inicio IS NULL OR p_fecha_fin IS NULL
       OR p_fecha_fin <= p_fecha_inicio THEN
        RETURN 0;
    END IF;

    SELECT COUNT(*), MAX(estado)
      INTO v_salon_existe, v_salon_estado
      FROM salones
     WHERE id = p_salon_id;

    IF v_salon_existe = 0 OR v_salon_estado = 'En mantenimiento' THEN
        RETURN 0;
    END IF;

    -- Dos intervalos se cruzan si inicio_existente < fin_nuevo
    -- y fin_existente > inicio_nuevo. Los extremos pueden coincidir.
    SELECT COUNT(*)
      INTO v_cruces
      FROM reservas
     WHERE salon_id = p_salon_id
       AND estado_reserva = 'Confirmada'
       AND fecha_hora_inicio < p_fecha_fin
       AND fecha_hora_fin > p_fecha_inicio;

    RETURN IF(v_cruces = 0, 1, 0);
END//

DELIMITER ;
