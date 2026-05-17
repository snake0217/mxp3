import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import psycopg2
import shutil
import os

# ==========================================
# CONFIGURACIÓN DEL SERVIDOR Y BASE DE DATOS
# ==========================================
DB_CONFIG = {
    "dbname": "mxp3",
    "user": "snake",        
    "password": "123456", 
    "host": "localhost",       
    "port": "5432"
}

LOCAL_STATIC_DIR = "mxp3_api/static" 
BASE_URL = "http://192.168.1.201:8000/static"
# ==========================================

class Mxp3AdminPanel:
    def __init__(self, root):
        self.root = root
        self.root.title("Mxp3 - Panel de Administración")
        self.root.geometry("950x600")
        self.root.configure(bg="#121212")

        self.audio_path = tk.StringVar()
        self.image_path = tk.StringVar()
        
        # Variables de control para saber si estamos editando
        self.current_track_id = None
        self.current_album_id = None
        self.current_artist_id = None

        self._build_ui()
        self.load_data()

    def _build_ui(self):
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TLabel", background="#121212", foreground="white", font=("Arial", 10))
        style.configure("Treeview", background="#1E1E1E", foreground="white", fieldbackground="#1E1E1E", rowheight=25)
        style.map('Treeview', background=[('selected', '#E6007E')])

        # Layout Principal: Izquierda (Formulario) | Derecha (Tabla)
        left_frame = tk.Frame(self.root, bg="#121212", width=400)
        left_frame.pack(side="left", fill="y", padx=20, pady=20)
        
        right_frame = tk.Frame(self.root, bg="#121212")
        right_frame.pack(side="right", fill="both", expand=True, padx=20, pady=20)

        # === FORMULARIO (Izquierda) ===
        tk.Label(left_frame, text="Gestión de Canciones", bg="#121212", fg="#E6007E", font=("Arial", 16, "bold")).pack(pady=(0, 20))

        ttk.Label(left_frame, text="Nombre del Artista:").pack(anchor="w")
        self.entry_artist = tk.Entry(left_frame, bg="#1E1E1E", fg="white", insertbackground="white", font=("Arial", 12))
        self.entry_artist.pack(fill="x", pady=(0, 10))

        ttk.Label(left_frame, text="Título del Álbum:").pack(anchor="w")
        self.entry_album = tk.Entry(left_frame, bg="#1E1E1E", fg="white", insertbackground="white", font=("Arial", 12))
        self.entry_album.pack(fill="x", pady=(0, 10))

        ttk.Label(left_frame, text="Título de la Canción:").pack(anchor="w")
        self.entry_track = tk.Entry(left_frame, bg="#1E1E1E", fg="white", insertbackground="white", font=("Arial", 12))
        self.entry_track.pack(fill="x", pady=(0, 10))

        ttk.Label(left_frame, text="Duración (segundos):").pack(anchor="w")
        self.entry_duration = tk.Entry(left_frame, bg="#1E1E1E", fg="white", insertbackground="white", font=("Arial", 12))
        self.entry_duration.pack(fill="x", pady=(0, 20))

        # Archivos
        btn_frame = tk.Frame(left_frame, bg="#121212")
        btn_frame.pack(pady=10, fill="x")
        tk.Button(btn_frame, text="Portada", command=self.select_image, bg="#2A2A2A", fg="white").pack(side="left", expand=True, padx=5)
        tk.Button(btn_frame, text="Audio", command=self.select_audio, bg="#2A2A2A", fg="white").pack(side="right", expand=True, padx=5)

        # Botones de Acción
        action_frame = tk.Frame(left_frame, bg="#121212")
        action_frame.pack(pady=20, fill="x")
        
        self.btn_save = tk.Button(action_frame, text="Guardar Nuevo", command=self.save_new, bg="#E6007E", fg="white", font=("Arial", 11, "bold"))
        self.btn_save.pack(fill="x", pady=5)
        
        self.btn_update = tk.Button(action_frame, text="Actualizar Seleccionado", command=self.update_selected, bg="#008CBA", fg="white", font=("Arial", 11, "bold"))
        
        self.btn_delete = tk.Button(action_frame, text="Eliminar", command=self.delete_selected, bg="#f44336", fg="white", font=("Arial", 11, "bold"))
        
        tk.Button(left_frame, text="Limpiar Formulario", command=self.clear_form, bg="#555", fg="white").pack(fill="x", pady=10)

        # === TABLA (Derecha) ===
        columns = ("id", "artist", "album", "track", "duration", "album_id", "artist_id")
        self.tree = ttk.Treeview(right_frame, columns=columns, show="headings")
        self.tree.heading("artist", text="Artista")
        self.tree.heading("album", text="Álbum")
        self.tree.heading("track", text="Canción")
        self.tree.heading("duration", text="Segundos")
        
        # Ocultar IDs internos
        self.tree.column("id", width=0, stretch=tk.NO)
        self.tree.column("album_id", width=0, stretch=tk.NO)
        self.tree.column("artist_id", width=0, stretch=tk.NO)
        
        self.tree.column("artist", width=120)
        self.tree.column("album", width=120)
        self.tree.column("track", width=150)
        self.tree.column("duration", width=70, anchor="center")

        self.tree.pack(fill="both", expand=True)
        self.tree.bind("<ButtonRelease-1>", self.on_tree_select)

    def select_image(self):
        path = filedialog.askopenfilename(filetypes=[("Imágenes", "*.jpg *.jpeg *.png")])
        if path: self.image_path.set(path)

    def select_audio(self):
        path = filedialog.askopenfilename(filetypes=[("Audio", "*.mp3 *.wav")])
        if path: self.audio_path.set(path)

    def clear_form(self):
        self.current_track_id = None
        self.current_album_id = None
        self.current_artist_id = None
        
        self.entry_artist.delete(0, tk.END)
        self.entry_album.delete(0, tk.END)
        self.entry_track.delete(0, tk.END)
        self.entry_duration.delete(0, tk.END)
        self.audio_path.set("")
        self.image_path.set("")
        
        self.btn_save.pack(fill="x", pady=5)
        self.btn_update.pack_forget()
        self.btn_delete.pack_forget()

    def get_db_connection(self):
        return psycopg2.connect(**DB_CONFIG)

    def load_data(self):
        for item in self.tree.get_children():
            self.tree.delete(item)
            
        try:
            conn = self.get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                SELECT t.track_id, ar.name, a.title, t.title, t.duration_seconds, a.album_id, ar.artist_id
                FROM tracks t
                JOIN albums a ON t.album_id = a.album_id
                JOIN artists ar ON a.artist_id = ar.artist_id
                ORDER BY t.created_at DESC;
            """)
            rows = cur.fetchall()
            for row in rows:
                self.tree.insert("", tk.END, values=row)
            cur.close()
            conn.close()
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo cargar la base de datos: {e}")

    def on_tree_select(self, event):
        selected = self.tree.focus()
        if not selected: return
        
        values = self.tree.item(selected, 'values')
        self.current_track_id = values[0]
        self.current_album_id = values[5]
        self.current_artist_id = values[6]

        self.entry_artist.delete(0, tk.END)
        self.entry_artist.insert(0, values[1])
        
        self.entry_album.delete(0, tk.END)
        self.entry_album.insert(0, values[2])
        
        self.entry_track.delete(0, tk.END)
        self.entry_track.insert(0, values[3])
        
        self.entry_duration.delete(0, tk.END)
        self.entry_duration.insert(0, values[4])

        # Cambiar botones
        self.btn_save.pack_forget()
        self.btn_update.pack(fill="x", pady=5)
        self.btn_delete.pack(fill="x", pady=5)

    def _process_files(self):
        # Lógica para mover archivos si se seleccionaron nuevos
        img_src = self.image_path.get()
        audio_src = self.audio_path.get()
        final_img_url = None
        final_audio_url = None

        if img_src:
            img_filename = os.path.basename(img_src).replace(" ", "_")
            img_dest = os.path.join(LOCAL_STATIC_DIR, "images", img_filename)
            os.makedirs(os.path.dirname(img_dest), exist_ok=True)
            shutil.copy(img_src, img_dest)
            final_img_url = f"{BASE_URL}/images/{img_filename}"
            
        if audio_src:
            audio_filename = os.path.basename(audio_src).replace(" ", "_")
            audio_dest = os.path.join(LOCAL_STATIC_DIR, "audio", audio_filename)
            os.makedirs(os.path.dirname(audio_dest), exist_ok=True)
            shutil.copy(audio_src, audio_dest)
            final_audio_url = f"{BASE_URL}/audio/{audio_filename}"
            
        return final_img_url, final_audio_url

    def save_new(self):
        artist = self.entry_artist.get().strip()
        album = self.entry_album.get().strip()
        track = self.entry_track.get().strip()
        duration = self.entry_duration.get().strip()

        if not all([artist, album, track, duration, self.image_path.get(), self.audio_path.get()]):
            messagebox.showerror("Error", "Para una nueva canción, todos los campos y archivos son obligatorios.")
            return

        try:
            final_img_url, final_audio_url = self._process_files()
            conn = self.get_db_connection()
            cur = conn.cursor()

            cur.execute("INSERT INTO artists (name, profile_image_url) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING artist_id;", (artist, final_img_url))
            result = cur.fetchone()
            artist_id = result[0] if result else cur.execute("SELECT artist_id FROM artists WHERE name = %s;", (artist,)) or cur.fetchone()[0]

            cur.execute("INSERT INTO albums (artist_id, title, album_type, cover_image_url) VALUES (%s, %s, 'single', %s) RETURNING album_id;", (artist_id, album, final_img_url))
            album_id = cur.fetchone()[0]

            cur.execute("INSERT INTO tracks (album_id, title, duration_seconds, audio_file_url, track_number) VALUES (%s, %s, %s, %s, 1);", (album_id, track, int(duration), final_audio_url))

            conn.commit()
            cur.close()
            conn.close()
            
            messagebox.showinfo("Éxito", "Canción guardada.")
            self.clear_form()
            self.load_data()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def update_selected(self):
        if not self.current_track_id: return
        
        artist = self.entry_artist.get().strip()
        album = self.entry_album.get().strip()
        track = self.entry_track.get().strip()
        duration = self.entry_duration.get().strip()

        try:
            final_img_url, final_audio_url = self._process_files()
            conn = self.get_db_connection()
            cur = conn.cursor()

            # Actualizar textos
            cur.execute("UPDATE artists SET name = %s WHERE artist_id = %s;", (artist, self.current_artist_id))
            cur.execute("UPDATE albums SET title = %s WHERE album_id = %s;", (album, self.current_album_id))
            cur.execute("UPDATE tracks SET title = %s, duration_seconds = %s WHERE track_id = %s;", (track, int(duration), self.current_track_id))

            # Actualizar URLs si se subieron nuevos archivos
            if final_img_url:
                cur.execute("UPDATE artists SET profile_image_url = %s WHERE artist_id = %s;", (final_img_url, self.current_artist_id))
                cur.execute("UPDATE albums SET cover_image_url = %s WHERE album_id = %s;", (final_img_url, self.current_album_id))
            if final_audio_url:
                cur.execute("UPDATE tracks SET audio_file_url = %s WHERE track_id = %s;", (final_audio_url, self.current_track_id))

            conn.commit()
            cur.close()
            conn.close()

            messagebox.showinfo("Éxito", "Registro actualizado correctamente.")
            self.clear_form()
            self.load_data()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def delete_selected(self):
        if not self.current_track_id: return
        
        if messagebox.askyesno("Confirmar", f"¿Estás seguro de eliminar '{self.entry_track.get()}'? Esto no se puede deshacer."):
            try:
                conn = self.get_db_connection()
                cur = conn.cursor()
                # Gracias al ON DELETE CASCADE en tu SQL, al borrar el track (o album), se limpia en cascada si es necesario.
                cur.execute("DELETE FROM tracks WHERE track_id = %s;", (self.current_track_id,))
                conn.commit()
                cur.close()
                conn.close()
                
                messagebox.showinfo("Eliminado", "Canción eliminada de la base de datos.")
                self.clear_form()
                self.load_data()
            except Exception as e:
                messagebox.showerror("Error", str(e))

if __name__ == "__main__":
    root = tk.Tk()
    app = Mxp3AdminPanel(root)
    root.mainloop()