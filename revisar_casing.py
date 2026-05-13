import os
import re

EXTENSIONS = {'.tscn', '.tres', '.gd'}

def check_case_sensitivity(root_dir):
    real_files = {}
    files_checked = 0
    errors_found = 0

    print(f"--- Iniciando escaneo en: {root_dir} ---")

    # 1. Mapear archivos reales
    for root, _, files in os.walk(root_dir):
        for f in files:
            full_path = os.path.normpath(os.path.join(root, f)).replace("\\", "/")
            real_files[full_path.lower()] = full_path

    # 2. Revisar contenido
    for root, _, files in os.walk(root_dir):
        for f in files:
            if any(f.endswith(ext) for ext in EXTENSIONS):
                files_checked += 1
                file_path = os.path.join(root, f)
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as content:
                        text = content.read()
                        # Busca cualquier cosa que empiece por res://
                        paths = re.findall(r'res://[^\s"\'\)]+', text)
                        
                        for p in paths:
                            # Limpiar posibles caracteres sobrantes al final de la ruta
                            clean_p = p.strip().rstrip(',').rstrip('"').rstrip("'")
                            system_p = os.path.normpath(clean_p.replace("res://", root_dir + "/")).lower().replace("\\", "/")
                            
                            if system_p in real_files:
                                actual_case = real_files[system_p].replace(os.path.normpath(root_dir).replace("\\", "/"), "res:").replace("res:/", "res://")
                                # Comparar con la ruta original limpia
                                if actual_case.lower() == clean_p.lower() and actual_case != clean_p:
                                    print(f"\n[!] ERROR DE MAYÚSCULAS en: {f}")
                                    print(f"    Referencia en código: {clean_p}")
                                    print(f"    Nombre real en disco: {actual_case}")
                                    errors_found += 1
                except Exception as e:
                    print(f"No se pudo leer {f}: {e}")

    print(f"\n--- Resumen ---")
    print(f"Archivos analizados: {files_checked}")
    print(f"Errores encontrados: {errors_found}")
    if errors_found == 0:
        print("¡No se detectaron problemas de casing!")

if __name__ == "__main__":
    check_case_sensitivity(os.getcwd())