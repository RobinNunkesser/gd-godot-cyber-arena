# Cyber Arena 3D (Godot 4)

> **Didaktisches Referenzprojekt für Vorlesung 17:** *3D-Räume, Raycasting & Vektor-Welten (IGA)*  
> **Hochschule Hamm-Lippstadt (HSHL)** | Prof. Dr. Robin Nunkesser

[![Test & Export](https://github.com/RobinNunkesser/gd-godot-cyber-arena/actions/workflows/export.yml/badge.svg)](https://github.com/RobinNunkesser/gd-godot-cyber-arena/actions/workflows/export.yml)

Ein schneller 3D-Top-Down / Arena-Survivor in Godot 4, der den Übergang von 2D-Kacheln zu kontinuierlichen 3D-Vektor-Welten, prozeduraler Mesh-Extrusion aus dem VGLC Doom-Vektorformat, allokationsfreien Objekt-Pools und Quaternion-Kinematik demonstriert.

---

## 🚀 Kernfeatures

1. **VGLC (*Video Game Level Corpus*) Vektor-Parser (`core/vglc_vector_parser.gd`):**
   - Parst Doom-Vektorformate (`levels/doom_e1m1_arena.vec`) mit kontinuierlichen 2D-Linedefs (`LINE x1 y1 x2 y2 floor_h ceil_h`) und Things (`THING x y z type angle`).
   - Generiert über Godots `SurfaceTool` in Echtzeit ein nahtloses 3D-ArrayMesh mit Normalen und UVs sowie statischen Physik-Kollisionskörpern (`StaticBody3D`).

2. **Allokationsfreies Object-Pooling (`core/object_pool_3d.gd`):**
   - Garantiert strikt $\mathcal{O}(0)$ Allokationen in der Render- und Physikschleife (`_physics_process`).
   - Eliminiert Garbage-Collection-Stutter und GPU-Memory-Leaks bei Projektilen und Drohnen.

3. **Gimbal-Lock-Immunität durch Quaternionen (`scripts/player_3d.gd`):**
   - Ausrichtung der Spielfigur auf den Schnittpunkt von Maus-Sichtstrahl und Bodenebene (`Plane.intersects_ray()`) über 4D-Quaternionen:
     $$\mathbf{q} = \text{Quaternion}(\vec{u}_y, \theta)$$
   - Sanfte Verfolgung der Drohnen per SLERP (*Spherical Linear Interpolation*).

4. **Hierarchische Sphere-Broadphase-Kollision (`scripts/drone_swarm.gd`):**
   - $\mathcal{O}(1)$ Distanzausschluss zwischen Hüllkugeln vor aufwändigen Meshtests:
     $$\|\vec{p}_{\text{proj}} - \vec{p}_{\text{drone}}\|^2 \le (r_{\text{proj}} + r_{\text{drone}})^2$$

---

## 🎮 Steuerung

| Taste / Eingabe | Aktion |
| :--- | :--- |
| **`[W] [A] [S] [D]` / Pfeiltasten** | 3D-Bewegung auf der Arena-Ebene |
| **Mauszeiger** | Zielen (Strahlenschnittpunkt mit 3D-Ebene) |
| **Linksklick / `[Leertaste]`** | Plasma-Geschoss abfeuern |
| **`[R]`** | Arena & Schwarm zurücksetzen |

---

## 🧪 Headless Tests ausführen

```bash
godot --headless -s test_gameplay.gd
```

