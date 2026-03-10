
--Consulta 1: Clasificación de Ganancias

SELECT u.nickname AS Nickname, ct.nombre AS Categoria, COUNT(DISTINCT s.idUsuario) AS [Total Suscriptores Activos], SUM(f.monto_total) AS [Monto Facturado], dbo.fn_clasificar_ingreso(SUM(f.monto_total)) AS [Clasificacion]
FROM Creador c
    JOIN Usuario u ON (c.idUsuario  = u.id)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
    JOIN NivelSuscripcion ns ON (c.idUsuario = ns.idCreador)
    JOIN Suscripcion s ON (ns.id = s.idNivel)
    JOIN Factura f ON (s.id = f.idSuscripcion)
WHERE s.estado = 'Activa' AND f.fecha_emision >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) AND f.fecha_emision <  CAST(GETDATE() AS DATE)
GROUP BY u.nickname, ct.nombre


-- Consulta 2: Viralidad por Categoría

WITH puntajes AS (
    SELECT p.id AS idPublicacion, p.titulo, p.idCreador, ct.id AS idCategoria, ct.nombre AS nombreCategoria, (COUNT(DISTINCT urp.idUsuario) * 1.5) + (COUNT(DISTINCT cm.id) * 3) AS puntaje
    FROM Publicacion p
        JOIN Creador c ON (p.idCreador = c.idUsuario)
        JOIN Categoria ct ON (c.idCategoria = ct.id)
        LEFT JOIN UsuarioReaccionPublicacion urp ON (p.id = urp.idPublicacion)
        LEFT JOIN Comentario cm ON (p.id = cm.idPublicacion)
    GROUP BY p.id, p.titulo, p.idCreador, ct.id, ct.nombre
)
SELECT p.nombreCategoria AS [Nombre Categoría], p.titulo AS [Título Publicacion], u.nickname AS Creador, p.puntaje AS [Puntaje Maximo]
FROM puntajes p JOIN Usuario u ON (p.idCreador = u.id)
WHERE p.puntaje = (
    SELECT MAX(pt.puntaje)
    FROM puntajes pt
    WHERE pt.idCategoria = p.idCategoria)


-- Consulta 3: Análisis de Dominios de Correo

SELECT SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, LEN(u.email)) AS Dominio, COUNT(*) AS [Cantidad Usuarios]
FROM Usuario u
GROUP BY SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, LEN(u.email))
HAVING COUNT(*) > 10


-- Consulta 4: Promedio de Retención

SELECT u.nickname AS [Nickname Creador], ns.nombre AS [Nombre Nivel], AVG(DATEDIFF(DAY, s.fecha_inicio, s.fecha_fin)) AS [Promedio Dias]
FROM Suscripcion s
    JOIN NivelSuscripcion ns ON (s.idNivel = ns.id)
    JOIN Creador c ON (ns.idCreador = c.idUsuario)
    JOIN Usuario u ON (c.idUsuario = u.id)
WHERE s.estado = 'Cancelada' AND s.fecha_fin IS NOT NULL
GROUP BY u.nickname, ns.nombre, ns.orden
ORDER BY ns.orden ASC;


-- Consulta 5: Tiempo y Peso de Contenido (Gaming)

SELECT u.nickname AS Nickname, CAST(SUM(v.duracion_seg) / 3600 AS VARCHAR) + 'h ' + CAST((SUM(v.duracion_seg) % 3600) / 60 AS VARCHAR) + 'm' AS [Tiempo Total Formateado],
       CAST(SUM(
           CASE v.resolucion
               WHEN '4K'    THEN (v.duracion_seg / 60.0) * 0.5
               WHEN '1080p' THEN (v.duracion_seg / 60.0) * 0.1
               ELSE              (v.duracion_seg / 60.0) * 0.05
           END
       ) AS DECIMAL(10,2)) AS [Estimacion GB]
FROM Video v
    JOIN Publicacion p ON (v.idPublicacion = p.id)
    JOIN Creador c ON (p.idCreador = c.idUsuario)
    JOIN Usuario u ON (c.idUsuario = u.id)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
WHERE ct.nombre = 'Gaming'
GROUP BY u.nickname


-- Consulta 6: Mapa de Calor Financiero

WITH total_global AS (
    SELECT SUM(monto_total) AS total
    FROM Factura
)
SELECT u.pais AS País, SUM(f.monto_total) AS [Total Facturado], CAST(SUM(f.monto_total) * 100.0 / tg.total AS DECIMAL(10,2)) AS [Share %]
FROM Factura f
    JOIN Suscripcion s ON (f.idSuscripcion = s.id)
    JOIN Usuario u ON (s.idUsuario = u.id)
    JOIN total_global tg ON (1 = 1)
GROUP BY u.pais, tg.total


-- Consulta 7: Intereses Cruzados

SELECT u.nickname AS Nickname, SUM(f.monto_total) AS [Gasto Total Histórico]
FROM Usuario u
    JOIN Suscripcion s ON (u.id = s.idUsuario)
    JOIN NivelSuscripcion ns ON (s.idNivel = ns.id)
    JOIN Creador c ON (ns.idCreador = c.idUsuario)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
    JOIN Factura f ON (s.id = f.idSuscripcion)
WHERE u.id IN (
    SELECT s2.idUsuario
    FROM Suscripcion s2
        JOIN NivelSuscripcion ns2 ON (s2.idNivel = ns2.id)
        JOIN Creador c2 ON (ns2.idCreador = c2.idUsuario)
        JOIN Categoria ct2 ON (c2.idCategoria = ct2.id)
    WHERE ct2.nombre = 'Tecnología'
    INTERSECT
    SELECT s3.idUsuario
    FROM Suscripcion s3
        JOIN NivelSuscripcion ns3 ON (s3.idNivel = ns3.id)
        JOIN Creador c3 ON (ns3.idCreador = c3.idUsuario)
        JOIN Categoria ct3 ON (c3.idCategoria = ct3.id)
    WHERE ct3.nombre = 'Fitness'
)
GROUP BY u.nickname
HAVING SUM(f.monto_total) > 140