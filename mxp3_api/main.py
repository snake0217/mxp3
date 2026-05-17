from fastapi import FastAPI, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from fastapi.staticfiles import StaticFiles
import psycopg2
from psycopg2.extras import RealDictCursor
import bcrypt
import jwt  # <-- Importamos PyJWT
from datetime import datetime, timedelta

app = FastAPI(
    title="Mxp3 API - Microservicio de Usuarios",
    description="API para gestión de identidad y streaming",
    version="1.0.0"
)

# Montar la carpeta 'static' para servir imágenes y música públicamente
app.mount("/static", StaticFiles(directory="static"), name="static")

# CONFIGURACIÓN DE SEGURIDAD (En producción, usa variables de entorno)
SECRET_KEY = "clave_super_secreta_para_jeje_no_te_la_sabes"  # Cambia esto por una clave segura en producción
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440  # El token durará 24 horas

class UserRegistration(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# Esquema de seguridad Bearer
security = HTTPBearer()

def verify_jwt(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        # Intentamos decodificar el token con tu clave secreta
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload # Si es válido, devolvemos los datos del usuario (id, rol)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="El token ha expirado. Inicia sesión nuevamente.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido o corrupto.")

# Función auxiliar para generar el JWT
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="mxp3", 
            user="snake",    
            password="123456", 
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error de conexión a BD")

@app.post("/api/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(user: UserRegistration):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT email FROM users WHERE email = %s;", (user.email,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="El correo ya está registrado")

        salt = bcrypt.gensalt(rounds=12) 
        hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), salt).decode('utf-8')

        insert_query = """
            INSERT INTO users (full_name, email, password_hash)
            VALUES (%s, %s, %s) RETURNING user_id, full_name, email, role;
        """
        cursor.execute(insert_query, (user.full_name, user.email, hashed_password))
        new_user = cursor.fetchone()
        conn.commit()
        
        return {"message": "Usuario creado exitosamente", "user": new_user}
    except psycopg2.Error as e:
        conn.rollback() 
        raise HTTPException(status_code=500, detail="Error interno de base de datos")
    finally:
        cursor.close()
        conn.close()

@app.post("/api/v1/login", status_code=status.HTTP_200_OK)
async def login_user(user: UserLogin):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT user_id, full_name, email, password_hash, role FROM users WHERE email = %s;", (user.email,))
        db_user = cursor.fetchone()

        if not db_user:
            raise HTTPException(status_code=401, detail="Credenciales inválidas")

        is_password_correct = bcrypt.checkpw(
            user.password.encode('utf-8'), 
            db_user['password_hash'].encode('utf-8')
        )

        if not is_password_correct:
            raise HTTPException(status_code=401, detail="Credenciales inválidas")

        # Generamos el token empaquetando el ID del usuario y su rol
        token_data = {
            "sub": str(db_user['user_id']),
            "email": db_user['email'],
            "role": db_user['role']
        }
        access_token = create_access_token(data=token_data)

        return {
            "message": "Login exitoso",
            "access_token": access_token,
            "token_type": "bearer"
        }
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail="Error interno de base de datos")
    finally:
        cursor.close()
        conn.close()

@app.get("/api/v1/home-feed", status_code=status.HTTP_200_OK)
async def get_home_feed(current_user: dict = Depends(verify_jwt)):
    # Si el código llega aquí, significa que el token es válido
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Consultar la sección "Para ti" (Uniendo álbumes con sus artistas)
        query_for_you = """
            SELECT a.album_id, a.title, a.cover_image_url, a.album_type, art.name as artist_name 
            FROM albums a
            JOIN artists art ON a.artist_id = art.artist_id
            LIMIT 4;
        """
        cursor.execute(query_for_you)
        for_you_data = cursor.fetchall()

        # 2. Consultar la sección "Escuchado Recientemente" 
        # (Por ahora simulado ordenando por fecha de creación)
        query_recent = """
            SELECT a.album_id, a.title, a.cover_image_url, a.album_type, art.name as artist_name 
            FROM albums a
            JOIN artists art ON a.artist_id = art.artist_id
            ORDER BY a.created_at DESC
            LIMIT 2;
        """
        cursor.execute(query_recent)
        recent_data = cursor.fetchall()

        return {
            "for_you": for_you_data,
            "recent": recent_data
        }
        
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail="Error interno al cargar la música")
    finally:
        cursor.close()
        conn.close()

@app.get("/api/v1/albums/{album_id}/tracks", status_code=status.HTTP_200_OK)
async def get_album_tracks(album_id: str, current_user: dict = Depends(verify_jwt)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Buscamos todas las canciones vinculadas a este álbum, ordenadas por su número de pista
        query = """
            SELECT track_id, title, duration_seconds, audio_file_url, track_number
            FROM tracks 
            WHERE album_id = %s 
            ORDER BY track_number ASC;
        """
        cursor.execute(query, (album_id,))
        tracks = cursor.fetchall()

        if not tracks:
            raise HTTPException(status_code=404, detail="No se encontraron canciones para este álbum")

        return {"tracks": tracks}
        
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail="Error interno al buscar canciones")
    finally:
        cursor.close()
        conn.close()

@app.get("/api/v1/artists", status_code=status.HTTP_200_OK)
async def get_all_artists(current_user: dict = Depends(verify_jwt)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT artist_id, name, profile_image_url
            FROM artists
            ORDER BY name ASC;
        """)
        return {"artists": cursor.fetchall()}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error al obtener artistas")
    finally:
        cursor.close()
        conn.close()

@app.get("/api/v1/search", status_code=status.HTTP_200_OK)
async def search_tracks(q: str = "", current_user: dict = Depends(verify_jwt)):
    if not q.strip():
        return {"tracks": []}
        
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        search_term = f"%{q}%"
        
        query = """
            SELECT t.track_id, t.title as track_title, t.duration_seconds, t.audio_file_url, t.track_number,
                   a.album_id, a.title as album_title, a.cover_image_url,
                   art.name as artist_name
            FROM tracks t
            JOIN albums a ON t.album_id = a.album_id
            JOIN artists art ON a.artist_id = art.artist_id
            WHERE t.title ILIKE %s OR a.title ILIKE %s OR art.name ILIKE %s
            ORDER BY t.title ASC
            LIMIT 30;
        """
        cursor.execute(query, (search_term, search_term, search_term))
        return {"tracks": cursor.fetchall()}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error en la búsqueda")
    finally:
        cursor.close()
        conn.close()

@app.get("/api/v1/tracks")
async def get_all_tracks(current_user: dict = Depends(verify_jwt)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        
        # JOIN mágico: Trae la canción, su álbum y su artista en una sola consulta
        cursor.execute("""
            SELECT t.track_id, t.title, t.duration_seconds, t.audio_file_url, t.track_number,
                   a.album_id, a.title as album_title, a.cover_image_url,
                   ar.name as artist_name
            FROM tracks t
            JOIN albums a ON t.album_id = a.album_id
            JOIN artists ar ON a.artist_id = ar.artist_id
            ORDER BY t.created_at DESC;
        """)
        tracks = cursor.fetchall()
        return {"tracks": tracks}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()