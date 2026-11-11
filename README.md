# Cyber Arena 3D (Godot 4)

> **Didaktisches Referenzprojekt für Vorlesung 17:** *3D-Räume, Raycasting & Vektor-Welten (IGA)*  
> **Hochschule Hamm-Lippstadt (HSHL)** | Prof. Dr. Robin Nunkesser

[![Test & Export](https://github.com/RobinNunkesser/gd-godot-cyber-arena/actions/workflows/export.yml/badge.svg)](https://github.com/RobinNunkesser/gd-godot-cyber-arena/actions/workflows/export.yml)

Ein 3D-Ego-Shooter (*First-Person Arena Survivor*) in Godot 4, der den Übergang von 2D-Kacheln zu kontinuierlichen 3D-Vektor-Welten, prozeduraler Mesh-Extrusion aus dem VGLC Doom-Vektorformat, allokationsfreien Objekt-Pools und Ego-Kamerasteuerung (Maus-Look mit Yaw/Pitch & WASD-Strafing) demonstriert.

---

## 🚀 Kernfeatures

1. **Ego-Perspektive & First-Person-Kinematik (`scripts/player_3d.gd`):**
   - Kamera auf Augenhöhe (`Head`-Node bei 1.5 m) mit zentriertem Fadenkreuz (*Crosshair*).
   - Maus-Umschauen: Horizontale Mausbewegung rotiert den Körper (`Yaw`), vertikale Mausbewegung neigt den Kopf (`Pitch`), geclampt auf $[-85^\circ, +85^\circ]$ gegen Gimbal-Lock-Überschläge.
   - Bewegung relativ zur Blickrichtung (WASD & seitliches Strafen via `basis.x` und `-basis.z`).
   - Umschaltbar via `[V]` zwischen First-Person und 3D-Aufsicht (*Overview*).

2. **VGLC (*Video Game Level Corpus*) Vektor-Parser (`core/vglc_vector_parser.gd`):**
   - Parst Doom-Vektorformate (`levels/doom_e1m1_arena.vec`) mit kontinuierlichen 2D-Linedefs (`LINE x1 y1 x2 y2 floor_h ceil_h`) und Things (`THING x y z type angle`).
   - Generiert über Godots `SurfaceTool` in Echtzeit ein nahtloses 3D-ArrayMesh mit Normalen und UVs sowie statischen Physik-Kollisionskörpern (`StaticBody3D`).

3. **Allokationsfreies Object-Pooling (`core/object_pool_3d.gd`):**
   - Garantiert strikt $\mathcal{O}(0)$ Allokationen in der Render- und Physikschleife (`_physics_process`).
   - Eliminiert Garbage-Collection-Stutter und GPU-Memory-Leaks bei Projektilen und Drohnen.

4. **Hierarchische Sphere-Broadphase-Kollision (`scripts/drone_swarm.gd`):**
   - $\mathcal{O}(1)$ Distanzausschluss zwischen Hüllkugeln vor aufwändigen Meshtests:
     $$\|\vec{p}_{\text{proj}} - \vec{p}_{\text{drone}}\|^2 \le (r_{\text{proj}} + r_{\text{drone}})^2$$

---

## 🎮 Steuerung

| Taste / Eingabe | Aktion |
| :--- | :--- |
| **Mausbewegung** | Umschauen / Zielen (Yaw & Pitch) |
| **Linksklick / `[Leertaste]`** | Plasma-Geschoss durch Fadenkreuz abfeuern |
| **`[W] [A] [S] [D]`** | Vorwärts/Rückwärts gehen und seitlich Strafen |
| **`[V]`** | Perspektive umschalten (Ego-Perspektive / 3D-Aufsicht) |
| **`[ESC]`** | Mauszeiger freigeben / fangen |
| **`[R]`** | Arena & Schwarm zurücksetzen |

---

## 🧪 Headless Tests ausführen

```bash
godot --headless -s test_gameplay.gd
```
