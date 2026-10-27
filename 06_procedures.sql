-- Eventos Premier S.A.S. | Módulo adicional: reserva transaccional
-- Esta rutina centraliza validaciones y reduce el riesgo de reservas solapadas.
-- En aplicaciones concurrentes, invocarla dentro de transacciones y mantener
-- las operaciones de reserva centralizadas en este procedimiento.
USE eventos_premier_db;

DROP PROCEDURE IF EXISTS crear_reserva;

DELIMITER //

CREATE PROCEDURE crear_reserva(
    IN p_salon_id INT,
    IN p_cliente_id INT,
    IN p_fecha_inicio DATETIME,
    IN p_fecha_fin DATETIME,
    IN p_observaciones VARCHAR(500)
)
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_horas DECIMAL(5,2);
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_estado VARCHAR(30);
    DECLARE v_cliente INT DEFAULT 0;
    DECLARE v_cruces INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL OR p_fecha_fin <= p_fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El rango de fechas de la reserva no es válido.';
    END IF;

    START TRANSACTION;

    -- Bloquea el registro del salón para serializar las reservas de ese salón.
    SELECT precio_hora, estado
      INTO v_precio, v_estado
      FROM salones
     WHERE id = p_salon_id
     FOR UPDATE;

    IF v_estado = 'En mantenimiento' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El salón está en mantenimiento.';
    END IF;

    SELECT COUNT(*) INTO v_cliente FROM clientes WHERE id = p_cliente_id;
    IF v_cliente = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El cliente indicado no existe.';
    END IF;

    SELECT COUNT(*) INTO v_cruces
      FROM reservas
     WHERE salon_id = p_salon_id
       AND estado_reserva = 'Confirmada'
       AND fecha_hora_inicio < p_fecha_fin
       AND fecha_hora_fin > p_fecha_inicio;

    IF v_cruces > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El salón ya tiene una reserva que se cruza con ese horario.';
    END IF;

    SET v_horas = ROUND(TIMESTAMPDIFF(MINUTE, p_fecha_inicio, p_fecha_fin) / 60, 2);
    IF v_horas <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La duración calculada debe ser mayor que cero.';
    END IF;

    SET v_total = calcular_total_reserva(v_precio, v_horas);

    INSERT INTO reservas
        (salon_id, cliente_id, fecha_hora_inicio, fecha_hora_fin,
         total_horas, valor_total, estado_reserva, observaciones)
    VALUES
        (p_salon_id, p_cliente_id, p_fecha_inicio, p_fecha_fin,
         v_horas, v_total, 'Confirmada', p_observaciones);

    COMMIT;

    SELECT LAST_INSERT_ID() AS reserva_id,
           v_horas AS total_horas,
           v_total AS valor_total_con_iva;
END//

DELIMITER ;
