-- =================================================
--                  STORE PROCEDURES
-- =================================================

-- Store Procedure para crear una suscripción y factura inicial
CREATE PROCEDURE sp_crear_suscripcion
    @idUsuario INT,
    @idNivel INT,
    @idMetodoPago INT
AS
BEGIN
    SET NOCOUNT ON; -- Esto evita que SQL muestre cuántas filas se afectan tras cada consulta

    BEGIN TRY
        BEGIN TRAN; -- Todo lo que hice desde aquí puede ser deshecho si ocurre un error

        -- Obtener el id del creador relacionado al nivel
        DECLARE @idCreador INT;
        SELECT @idCreador = idCreador
        FROM NivelSuscripcion
        WHERE id = @idNivel;

        -- Validar que no exista una suscripción activa para este usuario y creador
        IF EXISTS (
            SELECT N.id
            FROM Suscripcion S
            INNER JOIN NivelSuscripcion N ON S.idNivel = N.id
            WHERE S.idUsuario = @idUsuario
                  AND N.idCreador = @idCreador
                  AND S.estado = 'Activa'
        )
        BEGIN
            -- Abortamos, ya existe una suscripción activa
            RAISERROR('El usuario ya tiene una suscripción activa a este creador.', 16, 1);
            ROLLBACK TRAN; -- Se deshace todo lo hecho con bluetooth
            RETURN; -- Aquí termina el procedimiento si salió mal
        END

        -- Obtener el precio actual del nivel
        DECLARE @precio_actual DECIMAL(10,2);
        SELECT @precio_actual = precio_actual
        FROM NivelSuscripcion
        WHERE id = @idNivel;

        -- Insertar la nueva suscripción
        INSERT INTO Suscripcion (
            idUsuario, idNivel, fecha_inicio, fecha_renovacion,
            fecha_fin, estado, precio_pactado
        ) VALUES (
            @idUsuario, @idNivel, GETDATE(), NULL, NULL, 'Activa', @precio_actual
        );

        -- Obtener el ID de la suscripción creada (función para obtener el último id insertado)
        DECLARE @idSuscripcion INT = SCOPE_IDENTITY();

        -- Generar la primera factura asociada
        -- El impuesto es del 16%
        DECLARE @sub_total DECIMAL(10,2) = @precio_actual;
        DECLARE @monto_impuesto DECIMAL(10,2) = @sub_total * 0.16;
        DECLARE @monto_total DECIMAL(10,2) = @sub_total + @monto_impuesto;
        DECLARE @codigo_transaccion VARCHAR(30) = CONVERT(VARCHAR(30), NEWID()); -- Genera un código único para la transacción

        -- Inserta la factura
        INSERT INTO Factura (
            idSuscripcion, codigo_transaccion, fecha_emision,
            sub_total, monto_impuesto, monto_total
        ) VALUES (
            @idSuscripcion, @codigo_transaccion, GETDATE(),
            @sub_total, @monto_impuesto, @monto_total
        );

        COMMIT TRAN; -- Si todo salió bien, guarda los cambios en la base de datos.
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN; -- Si hubo error, regresa la base de datos a su estado previo.

        -- Captura el mensaje de error actual
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        -- Muestra el error para saber que la transacción no se pudo hacer
        THROW 51000, @error, 1;
    END CATCH
END
GO

-- Store Procedure para mostrar un dashboard de un creador
CREATE PROCEDURE sp_dashboard_creador
    @idCreador INT,
    @fechaInicio DATE,
    @fechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que el creador exista
    IF NOT EXISTS (SELECT 1 FROM Creador WHERE idUsuario = @idCreador)
    BEGIN
        RAISERROR('El creador especificado no existe.', 16, 1);
        RETURN;
    END

    -- Validar que el rango de fechas tenga sentido lógico
    IF @fechaInicio > @fechaFin
    BEGIN
        RAISERROR('La fecha de inicio no puede ser mayor que la fecha final.', 16, 1);
        RETURN;
    END
    -- =================================================
    -- Tabla 1: Resumen de KPIs (Total Ganado, Total Nuevos Subs)
    SELECT 
    -- Se dividió la solucion en subconsultas por comodidad aunque quizas se ve un poco feo
    -- La primera subconsulta calcula el total ganado en el periodo dado, 
    -- sumando el monto_total de las facturas emitidas para las suscripciones del creador en ese periodo
    -- Si no hay facturas, devuelve 0, para ello es el isnull
        (SELECT ISNULL(SUM(f.monto_total), 0)
         FROM Factura AS f JOIN Suscripcion AS s ON f.idSuscripcion = s.id
              JOIN NivelSuscripcion AS n ON s.idNivel = n.id
         WHERE f.fecha_emision BETWEEN @fechaInicio AND @fechaFin AND n.idCreador = @idCreador) AS TotalGanado,
        
        (SELECT COUNT(*)
         FROM Suscripcion AS s JOIN NivelSuscripcion AS n ON s.idNivel = n.id
         WHERE s.fecha_inicio BETWEEN @fechaInicio AND @fechaFin AND s.estado = 'Activa'
               AND n.idCreador = @idCreador) AS NuevasSuscripciones;

    -- =================================================
    -- Tabla 2: Listado de sus 5 fans más activos
    -- Obtenemos los suscriptores del creador y su fecha de suscripción para desempatar
    WITH Suscriptores AS (
        SELECT s.idUsuario, MIN(s.fecha_inicio) AS FechaSuscripcion
        FROM Suscripcion AS s JOIN NivelSuscripcion AS n ON s.idNivel = n.id
        WHERE n.idCreador = @idCreador AND s.estado = 'Activa'
        GROUP BY s.idUsuario
    ),
    -- Obtenemos todos los comentarios hechos por cada usuario a las publicaciones del creador en el periodo dado
    ConteoComentarios AS (
        SELECT c.idUsuario, COUNT(c.id) AS TotalComentarios
        FROM Comentario AS c JOIN Publicacion AS p ON c.idPublicacion = p.id
        WHERE p.idCreador = @idCreador AND c.fecha BETWEEN @fechaInicio AND @fechaFin
        GROUP BY c.idUsuario
    ),
    -- Obtenemos todas las reacciones hechas por cada usuario a las publicaciones del creador en el periodo dado
    ConteoReacciones AS (
        SELECT urp.idUsuario, COUNT(urp.idPublicacion) AS TotalReacciones
        FROM UsuarioReaccionPublicacion AS urp JOIN Publicacion AS p ON urp.idPublicacion = p.id
        WHERE p.idCreador = @idCreador AND urp.fecha_reaccion BETWEEN @fechaInicio AND @fechaFin
        GROUP BY urp.idUsuario
    )
    -- Seleccionamos el top 5 de los mecenas
    SELECT TOP 5 u.nickname, (ISNULL(cc.TotalComentarios, 0) + ISNULL(cr.TotalReacciones, 0)) AS TotalInteracciones
    FROM Suscriptores AS sub JOIN Usuario AS u ON sub.idUsuario = u.id
    LEFT JOIN ConteoComentarios AS cc ON sub.idUsuario = cc.idUsuario
    LEFT JOIN ConteoReacciones AS cr ON sub.idUsuario = cr.idUsuario
    ORDER BY TotalInteracciones DESC, sub.FechaSuscripcion ASC; -- Si tienen 0 interacciones, se prioriza a los más antiguos

    -- =================================================
    -- Tabla 3: Publicación con mejor rendimiento en el periodo

    WITH InteraccionesPub AS (
        SELECT p.id AS idPublicacion,
            -- Subconsulta para los comentarios de esta publicación en el periodo dado
            (SELECT COUNT(*) 
             FROM Comentario AS c 
             WHERE c.idPublicacion = p.id AND c.fecha BETWEEN @fechaInicio AND @fechaFin) AS TotalComentarios,
            -- Subconsulta para las reacciones de esta publicación en el periodo
            (SELECT COUNT(*) 
             FROM UsuarioReaccionPublicacion AS urp 
             WHERE urp.idPublicacion = p.id AND urp.fecha_reaccion BETWEEN @fechaInicio AND @fechaFin) AS TotalReacciones
        FROM Publicacion AS p
        WHERE p.idCreador = @idCreador
    )
    -- Aquí es donde se selecciona la mejor publicación
    SELECT TOP 1 idPublicacion, (TotalComentarios + TotalReacciones) AS TotalInteracciones
    FROM InteraccionesPub
    ORDER BY TotalInteracciones DESC;
END
GO

-- Store Procedure para insertar etiquetas a las publicaciones
CREATE PROCEDURE sp_publicar_con_etiquetas
    @idCreador INT,
    @titulo VARCHAR(255),
    @es_publica BIT,
    @fecha_publicacion DATE,
    @tipo_contenido VARCHAR(50),
    @etiquetas VARCHAR(MAX) -- Cadena con etiquetas separadas por comas
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        -- Se valida que el creador exista
        IF NOT EXISTS (SELECT 1 FROM Creador WHERE idUsuario = @idCreador)
        BEGIN
            RAISERROR('El creador especificado no existe.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END
        -- Se valida que el tipo de publicación exista
        IF @tipo_contenido NOT IN ('TEXTO', 'IMAGEN', 'VIDEO')
        BEGIN
            RAISERROR('El tipo de contenido especificado no es válido.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END
        -- Se valida que haya etiquetas y que el título no esté vacío
        -- LTRIM borra espacios en blanco al inicio de la cadena
        -- RTRIM borra espacios en blanco al final de la cadena
        IF LTRIM(RTRIM(@etiquetas)) = '' OR LTRIM(RTRIM(@titulo)) = ''
        BEGIN
            RAISERROR('El título y las etiquetas no pueden estar vacíos.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END

        -- Insertar la publicación
        DECLARE @nuevoId INT = ISNULL((SELECT MAX(id) FROM Publicacion), 0) + 1;
        INSERT INTO Publicacion (id, idCreador, titulo, fecha_publicacion, es_publica, tipo_contenido)
        VALUES (@nuevoId, @idCreador, @titulo, @fecha_publicacion, @es_publica, @tipo_contenido);

        -- Insertar las etiquetas
        -- Se valida si existen, de no ser así se crean unas nuevas y se insertan en las relaciones PublicacionEtiqueta
        -- Primero buscamos el id máximo actual de la tabla Etiqueta
        DECLARE @maxIdEtiqueta INT = ISNULL((SELECT MAX(id) FROM Etiqueta), 0) + 1;

        INSERT INTO Etiqueta (id, nombre)
        SELECT 
            -- Sumamos el id máximo + un contador secuencial (1, 2, 3...) para cada etiqueta nueva
            @maxIdEtiqueta + ROW_NUMBER() OVER (ORDER BY NuevasEtiquetas.nombre) AS nuevoIdEtiqueta,
            NuevasEtiquetas.nombre
        FROM (
            -- Filtramos para quedarnos solo con etiquetas unicas que no existen en la BD
            SELECT DISTINCT LTRIM(RTRIM(value)) AS nombre
            FROM STRING_SPLIT(@etiquetas, ',')
            WHERE LTRIM(RTRIM(value)) <> '' AND LTRIM(RTRIM(value)) NOT IN (SELECT nombre FROM Etiqueta)
        ) AS NuevasEtiquetas;

        -- Se crean las relaciones en PublicacionEtiqueta
        INSERT INTO PublicacionEtiqueta (idPublicacion, idEtiqueta)
        SELECT @nuevoId, id
        FROM Etiqueta
        WHERE nombre IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@etiquetas, ','));

        COMMIT TRAN
    END TRY
    BEGIN CATCH
        -- Si hubo un error y hay una transacción abierta, deshacemos todo
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO 

-- Store Procedure para generar una factura
CREATE PROCEDURE sp_generar_factura_pago
    @idSuscripcion INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        -- Validar que la suscripción exista y esté activa
        IF NOT EXISTS (SELECT 1 FROM Suscripcion WHERE id = @idSuscripcion AND estado = 'Activa')
        BEGIN
            RAISERROR('La suscripción especificada no existe o no está activa.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END
        -- Obtener suscripcion, nivel de suscripcion y usuario para generar la factura
        DECLARE @sub_total DECIMAL(10,2);
        DECLARE @idUsuario INT;
        DECLARE @idCreador INT;
        DECLARE @idNivel INT;

        SELECT @idUsuario = s.idUsuario, @idCreador = ns.idCreador, @sub_total = s.precio_pactado, @idNivel = ns.id
        FROM NivelSuscripcion AS ns JOIN Suscripcion AS s ON ns.id = s.idNivel
        WHERE s.id = @idSuscripcion

        -- Ahora se calcula el monto
        DECLARE @monto_impuesto DECIMAL(10,2);
        DECLARE @monto_total DECIMAL(10,2);
        DECLARE @codigo_transaccion VARCHAR(100);
        SET @monto_impuesto = dbo.fn_calcular_impuesto(@sub_total);
        SET @monto_total = @sub_total + @monto_impuesto;

        -- Generación del código de transacción
        SET @codigo_transaccion = CONCAT(
            CONVERT(VARCHAR(8), GETDATE(), 112), '-',
            @idUsuario, '-',
            @idSuscripcion, '-',
            @idNivel, '-',
            @idCreador
        );

        -- Insertamos los datos
        DECLARE @nuevaFacturaId INT = ISNULL((SELECT MAX(id) FROM Factura), 0) + 1;
        INSERT INTO Factura (id, idSuscripcion, codigo_transaccion, fecha_emision, sub_total, monto_impuesto, monto_total) 
        VALUES (@nuevaFacturaId, @idSuscripcion, @codigo_transaccion, GETDATE(), @sub_total, @monto_impuesto, @monto_total);
        COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR(@ErrorMessage, 16, 1);
        END CATCH
END
GO
-- =================================================
--                  FUNCIONES
-- =================================================

CREATE FUNCTION fn_calcular_impuesto(@monto DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @impuesto DECIMAL(10,2);
	SET @impuesto = (16*@monto)/100;
	RETURN @impuesto;
END
GO

CREATE FUNCTION fn_clasificar_ingreso(@monto DECIMAL(10,2))
RETURNS NVARCHAR(20)
AS
BEGIN
	DECLARE @calificacion NVARCHAR(20);
	IF @monto > 1000
		SET @calificacion = 'Diamante';
	ELSE IF @monto >=500
		SET @calificacion = 'Oro';
	ELSE
		SET @calificacion = 'Plata';
	RETURN @calificacion;
END
GO

CREATE FUNCTION fn_calcular_reputacion(@idCreador INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @totalSuscriptores INT = 0;
	DECLARE @totalReacciones INT = 0;
	DECLARE @antiguedad INT = 0;
	DECLARE @reputacion DECIMAL(10,2);

	SELECT @totalSuscriptores = COUNT(DISTINCT(s.idUsuario))
	FROM NivelSuscripcion as n JOIN Suscripcion as s ON(n.id = s.idNivel)
	WHERE @idCreador = n.idCreador;

	SELECT @totalReacciones = COUNT(*)
	FROM UsuarioReaccionPublicacion as urp JOIN Publicacion as p ON(urp.idPublicacion = p.id)
	WHERE @idCreador = p.idCreador AND urp.fecha_reaccion >= DATEADD(MONTH, -1, GETDATE());

	SELECT @antiguedad = DATEDIFF(MONTH, u.fecha_registro, GETDATE())
	FROM Creador as c JOIN Usuario as u ON(c.idUsuario = u.id)
	WHERE @idCreador = c.idUsuario;

	SET @reputacion = (@totalSuscriptores * 0.5) + (@totalReacciones * 0.1) + (@antiguedad * 2);
	IF @reputacion > 100
		SET @reputacion = 100
	RETURN @reputacion;
END
GO

--TRUGGERS

-- Trigger 1: Auditoría de Precios (Safety)

CREATE TRIGGER tr_auditar_precio_nivel
ON NivelSuscripcion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
            JOIN deleted d ON (i.id = d.id)
        WHERE ABS(i.precio_actual - d.precio_actual) > (d.precio_actual * 0.50)
    )
    BEGIN
        RAISERROR('El cambio de precio supera el 50% del precio anterior. Operación cancelada.', 16, 1);
        ROLLBACK TRAN;
    END
END
GO


-- Trigger 2: Protección de Menores (NSFW)

CREATE TRIGGER tr_proteger_menores_nsfw
ON Suscripcion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
            JOIN NivelSuscripcion ns ON (i.idNivel = ns.id)
            JOIN Creador c ON (ns.idCreador = c.idUsuario)
            JOIN Usuario u ON (i.idUsuario = u.id)
        WHERE c.es_nsfw = 1
          AND DATEADD(YEAR, 18, u.fecha_nacimiento) > CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR('Contenido restringido por edad.', 16, 1);
        ROLLBACK TRAN;
    END
END
GO
