USE FANHUB;
GO

-- 1. Tablas de relación de muchos a muchos y detalles específicos (Hijas de tercer nivel)
DROP TABLE IF EXISTS PublicacionEtiqueta;
DROP TABLE IF EXISTS UsuarioReaccionPublicacion;
DROP TABLE IF EXISTS Video;
DROP TABLE IF EXISTS Texto;
DROP TABLE IF EXISTS Imagen;
DROP TABLE IF EXISTS Factura;

-- Tablas que dependen de Creador, Usuario o Publicacion (Hijas de segundo nivel)
DROP TABLE IF EXISTS Comentario;
DROP TABLE IF EXISTS Suscripcion;
DROP TABLE IF EXISTS NivelSuscripcion;
DROP TABLE IF EXISTS Publicacion;
DROP TABLE IF EXISTS MetodoPago;

-- Tablas base / principales (Las que no dependen de nadie)
DROP TABLE IF EXISTS Creador;
DROP TABLE IF EXISTS Usuario;
DROP TABLE IF EXISTS Categoria;
DROP TABLE IF EXISTS TipoReaccion;
DROP TABLE IF EXISTS Etiqueta;
GO

-- Creación de Tablas

CREATE TABLE Usuario (
    id INT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    fecha_registro DATE NOT NULL DEFAULT GETDATE(),
    fecha_nacimiento DATE NOT NULL,
    pais VARCHAR(50) NOT NULL,
    esta_activo BIT NOT NULL DEFAULT 1,
    
CONSTRAINT Usuarios_mayores_13  CHECK (DATEADD(YEAR, 13, fecha_nacimiento) <= CAST(GETDATE() AS DATE)),
	CONSTRAINT nickname_unico UNIQUE(nickname),
	CONSTRAINT email_unico UNIQUE(email),
	CONSTRAINT formato_email check(email LIKE '%@%.%' and email NOT LIKE '% %' and email NOT LIKE '%@%@%')
);
GO
CREATE TABLE Categoria (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    descripcion NVARCHAR(500) NOT NULL,
    
    CONSTRAINT nombre_categoria_unico UNIQUE(nombre)
);
GO

CREATE TABLE Creador (
    idUsuario INT PRIMARY KEY,
    biografia NVARCHAR(2000),
    banco_nombre VARCHAR(60),
    banco_cuenta VARCHAR(50),
    es_nsfw BIT NOT NULL,
    idCategoria INT NOT NULL,
    
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idCategoria) REFERENCES Categoria(id)
);
GO

CREATE TABLE MetodoPago (
    id INT PRIMARY KEY,
    idUsuario INT NOT NULL,
    ultimos_4_digitos CHAR(4) NOT NULL,
    marca VARCHAR(50) NOT NULL,
    titular VARCHAR(255) NOT NULL,
    fecha_expiracion DATE NOT NULL,
    es_predeterminado BIT NOT NULL,
    
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id)
);
GO

CREATE TABLE NivelSuscripcion (
    id INT PRIMARY KEY,
    idCreador INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(1000),
    precio_actual DECIMAL(10,2) NOT NULL,
    esta_activo BIT NOT NULL,
    orden INT NOT NULL,
    
    FOREIGN KEY (idCreador) REFERENCES Creador(idUsuario),
    CONSTRAINT nivel_por_creador_unico UNIQUE(idCreador, nombre)
);
GO

CREATE TABLE Suscripcion (
    id INT PRIMARY KEY,
    idUsuario INT NOT NULL,
    idNivel INT NOT NULL,
    fecha_inicio DATE NOT NULL DEFAULT GETDATE(),
    fecha_renovacion DATE,
    fecha_fin DATE,
    estado VARCHAR(11) NOT NULL,
    precio_pactado DECIMAL(10,2) NOT NULL,
    
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idNivel) REFERENCES NivelSuscripcion(id),
    CONSTRAINT estados_suscripcion CHECK (estado IN ('Activa','Cancelada','Vencida')),
    CONSTRAINT coherencia_fechafin_fechainicio CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT precio_positivo CHECK(precio_pactado >= 0)
);
GO


CREATE TABLE Factura (
    id INT PRIMARY KEY,
    idSuscripcion INT NOT NULL,
    codigo_transaccion VARCHAR(500) NOT NULL,
    fecha_emision DATE NOT NULL,
    sub_total DECIMAL(10,2) NOT NULL,
    monto_impuesto DECIMAL(10,2) NOT NULL,
    monto_total DECIMAL(10,2) NOT NULL,
    
    FOREIGN KEY (idSuscripcion) REFERENCES Suscripcion(id),
    CONSTRAINT codigo_unico UNIQUE(codigo_transaccion),
    CONSTRAINT subtotal_positivo CHECK (sub_total >= 0),
    CONSTRAINT impuesto_positivo CHECK (monto_impuesto >= 0),
    CONSTRAINT total_positivo CHECK (monto_total >= 0),
    CONSTRAINT coherencia_monto_total CHECK (monto_total = sub_total + monto_impuesto)
);
GO

CREATE TABLE Publicacion (
    id INT PRIMARY KEY,
    idCreador INT NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    fecha_publicacion DATE NOT NULL,
    es_publica BIT NOT NULL,
    tipo_contenido VARCHAR(10) NOT NULL,
    
    FOREIGN KEY (idCreador) REFERENCES Creador(idUsuario),
    CONSTRAINT tipos_de_publicacion CHECK (tipo_contenido IN ('VIDEO', 'TEXTO', 'IMAGEN'))
);
GO

CREATE TABLE Video (
    idPublicacion INT PRIMARY KEY,
    duracion_seg INT NOT NULL,
    resolucion VARCHAR(10) NOT NULL,
    url_stream VARCHAR(2000) NOT NULL,
    
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    CONSTRAINT duracion_positiva CHECK (duracion_seg > 0),
    CONSTRAINT resolucion_estandar CHECK (resolucion IN ('144p', '240p', '360p','480p','720p', '1080p', '4K'))
);
GO

CREATE TABLE Texto (
    idPublicacion INT PRIMARY KEY,
    contenido_html VARCHAR(7000) NOT NULL,
    resumen_gratuito VARCHAR(1000),
    
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id)
);
GO

CREATE TABLE Imagen (
    idPublicacion INT PRIMARY KEY,
    ancho INT NOT NULL,
    alto INT NOT NULL,
    formato VARCHAR(100) NOT NULL,
    alt_text VARCHAR(500) NOT NULL,
    url_imagen VARCHAR(1000) NOT NULL,
    
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    CONSTRAINT ancho_positivo CHECK(ancho > 0),
    CONSTRAINT alto_positivo CHECK(alto > 0)
);
GO

CREATE TABLE Comentario (
    id INT PRIMARY KEY,
    idUsuario INT NOT NULL,
    idPublicacion INT NOT NULL,
    idComentarioPadre INT,
    texto VARCHAR(2000) NOT NULL,
    fecha DATE NOT NULL,
    
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idComentarioPadre) REFERENCES Comentario(id)
);
GO

CREATE TABLE TipoReaccion (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    emoji_code NVARCHAR(10) NOT NULL
);
GO

CREATE TABLE UsuarioReaccionPublicacion(
    idUsuario INT NOT NULL,
    idPublicacion INT NOT NULL,
    idTipoReaccion INT NOT NULL,
    fecha_reaccion DATE NOT NULL,
    
    PRIMARY KEY(idUsuario, idPublicacion, idTipoReaccion),
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idTipoReaccion) REFERENCES TipoReaccion(id)
);
GO

CREATE TABLE Etiqueta (
    id INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    
    CONSTRAINT nombre_unico_etiqueta UNIQUE(nombre)
);
GO

CREATE TABLE PublicacionEtiqueta (
    idPublicacion INT NOT NULL,
    idEtiqueta INT NOT NULL,
    
    PRIMARY KEY(idPublicacion, idEtiqueta),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idEtiqueta) REFERENCES Etiqueta(id)
);
GO