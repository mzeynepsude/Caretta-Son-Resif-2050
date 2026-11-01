import math

def generate_pinna_nobilis():
    seg_u = 52  # segments across the fan width
    seg_v = 40  # segments along the shell length
    
    # Scale parameters (meters)
    L = 5.2       # shell length from hinge to top crest
    W_max = 3.0   # shell width at top rim
    D_max = 0.85  # cup depth
    thickness = 0.09
    
    def generate_valve(is_top=False, tilt_deg=20.0, hinge_offset_y=0.0, filename=""):
        vertices = []
        uvs = []
        
        tilt_rad = math.radians(tilt_deg)
        cos_t = math.cos(tilt_rad)
        sin_t = math.sin(tilt_rad)
        
        def calc_valve_vertex(u_norm, v_norm, is_inner):
            # u_norm: 0.0 (left) to 1.0 (right) -> u: -1.0 to 1.0
            u = (u_norm - 0.5) * 2.0
            v = v_norm
            
            # Avoid singularity at apex v=0
            v_eff = max(v, 0.015)
            
            # Fan widening: Pinna nobilis triangular wedge flare
            width_factor = (v_eff ** 0.82) * (W_max * 0.5)
            x_local = u * width_factor
            
            # Convex rounded crest at the top rim
            rim_curve = 0.40 * (1.0 - u * u) * (v ** 1.8)
            z_local = -(v * L + rim_curve)
            
            # Cup curvature: hollow scoop in the center, tapering to side edges
            cup = 1.0 - u * u
            if cup < 0.0: cup = 0.0
            cup_profile = (cup ** 0.80) * D_max * math.sin(v_eff * math.pi * 0.88)
            
            # Radial ribs (16 distinct ribs radiating from hinge)
            rib_freq = 16.0
            rib_amplitude = 0.040 * v_eff * cup if not is_inner else 0.006 * v_eff
            rib = math.cos(u * math.pi * rib_freq) * rib_amplitude
            
            # Growth rings along length
            growth_ring = math.sin(v * 36.0) * 0.015 * cup if not is_inner else 0.0
            
            t_half = thickness * 0.5
            if not is_inner:
                # Outer surface is on the convex outside
                y_local = -(cup_profile + rib + growth_ring + t_half)
            else:
                # Inner surface is on the concave inside
                y_local = -(cup_profile + rib * 0.2 - t_half)
                
            # For top valve, flip so cup faces DOWN towards the bottom valve (concave inside)
            if is_top:
                y_local = -y_local
                
            # Tilt rotation around X axis (pointing towards -Z initially, tilting UP into +Y)
            # z_local is negative. Rotating by positive tilt tilts +Y upwards!
            y_rot = y_local * cos_t - z_local * sin_t + hinge_offset_y
            z_rot = y_local * sin_t + z_local * cos_t
            x_rot = x_local
            
            return x_rot, y_rot, z_rot

        outer_grid = []
        inner_grid = []
        
        # 1. Outer Surface Vertices
        for j in range(seg_v + 1):
            v_norm = j / float(seg_v)
            row = []
            for i in range(seg_u + 1):
                u_norm = i / float(seg_u)
                x, y, z = calc_valve_vertex(u_norm, v_norm, is_inner=False)
                idx = len(vertices) + 1
                vertices.append((x, y, z))
                uvs.append((u_norm, v_norm))
                row.append(idx)
            outer_grid.append(row)
            
        # 2. Inner Surface Vertices
        for j in range(seg_v + 1):
            v_norm = j / float(seg_v)
            row = []
            for i in range(seg_u + 1):
                u_norm = i / float(seg_u)
                x, y, z = calc_valve_vertex(u_norm, v_norm, is_inner=True)
                idx = len(vertices) + 1
                vertices.append((x, y, z))
                uvs.append((u_norm, v_norm))
                row.append(idx)
            inner_grid.append(row)

        outer_faces = []
        inner_faces = []
        rim_faces = []

        # Outer Faces (Normals pointing outside)
        for j in range(seg_v):
            for i in range(seg_u):
                p1 = outer_grid[j][i]
                p2 = outer_grid[j][i+1]
                p3 = outer_grid[j+1][i+1]
                p4 = outer_grid[j+1][i]
                if not is_top:
                    outer_faces.append((p1, p3, p2))
                    outer_faces.append((p1, p4, p3))
                else:
                    outer_faces.append((p1, p2, p3))
                    outer_faces.append((p1, p3, p4))

        # Inner Faces (Normals pointing inside towards cavity)
        for j in range(seg_v):
            for i in range(seg_u):
                p1 = inner_grid[j][i]
                p2 = inner_grid[j][i+1]
                p3 = inner_grid[j+1][i+1]
                p4 = inner_grid[j+1][i]
                if not is_top:
                    inner_faces.append((p1, p2, p3))
                    inner_faces.append((p1, p3, p4))
                else:
                    inner_faces.append((p1, p3, p2))
                    inner_faces.append((p1, p4, p3))

        # Rim Faces: Top crest (j = seg_v)
        j = seg_v
        for i in range(seg_u):
            o1 = outer_grid[j][i]
            o2 = outer_grid[j][i+1]
            i1 = inner_grid[j][i]
            i2 = inner_grid[j][i+1]
            if not is_top:
                rim_faces.append((o1, o2, i2))
                rim_faces.append((o1, i2, i1))
            else:
                rim_faces.append((o1, i2, o2))
                rim_faces.append((o1, i1, i2))

        # Rim Faces: Left edge (i = 0)
        for j in range(seg_v):
            o1 = outer_grid[j][0]
            o2 = outer_grid[j+1][0]
            i1 = inner_grid[j][0]
            i2 = inner_grid[j+1][0]
            if not is_top:
                rim_faces.append((o1, i1, i2))
                rim_faces.append((o1, i2, o2))
            else:
                rim_faces.append((o1, i2, i1))
                rim_faces.append((o1, o1, i2))

        # Rim Faces: Right edge (i = seg_u)
        for j in range(seg_v):
            o1 = outer_grid[j][seg_u]
            o2 = outer_grid[j+1][seg_u]
            i1 = inner_grid[j][seg_u]
            i2 = inner_grid[j+1][seg_u]
            if not is_top:
                rim_faces.append((o1, o2, i2))
                rim_faces.append((o1, i2, i1))
            else:
                rim_faces.append((o1, i2, o2))
                rim_faces.append((o1, i1, i2))

        # Compute face normals and accumulate smooth vertex normals
        v_normals = [[0.0, 0.0, 0.0] for _ in range(len(vertices))]
        all_triangles = outer_faces + inner_faces + rim_faces
        for f1, f2, f3 in all_triangles:
            v1 = vertices[f1 - 1]
            v2 = vertices[f2 - 1]
            v3 = vertices[f3 - 1]
            ax, ay, az = v2[0] - v1[0], v2[1] - v1[1], v2[2] - v1[2]
            bx, by, bz = v3[0] - v1[0], v3[1] - v1[1], v3[2] - v1[2]
            nx = ay * bz - az * by
            ny = az * bx - ax * bz
            nz = ax * by - ay * bx
            for f_idx in (f1, f2, f3):
                v_normals[f_idx - 1][0] += nx
                v_normals[f_idx - 1][1] += ny
                v_normals[f_idx - 1][2] += nz

        normalized_normals = []
        for nx, ny, nz in v_normals:
            length = math.sqrt(nx*nx + ny*ny + nz*nz)
            if length > 1e-6:
                normalized_normals.append((nx/length, ny/length, nz/length))
            else:
                normalized_normals.append((0.0, 1.0, 0.0))

        with open(filename, "w", encoding="utf-8") as f:
            f.write(f"# Pinna Nobilis Valve ({'Top' if is_top else 'Bottom'})\n")
            for vx, vy, vz in vertices:
                f.write(f"v {vx:.4f} {vy:.4f} {vz:.4f}\n")
            for u_val, v_val in uvs:
                f.write(f"vt {u_val:.4f} {v_val:.4f}\n")
            for nx, ny, nz in normalized_normals:
                f.write(f"vn {nx:.4f} {ny:.4f} {nz:.4f}\n")
                
            f.write("\ng ShellOuter\nusemtl ShellOuter\n")
            for f1, f2, f3 in outer_faces + rim_faces:
                f.write(f"f {f1}/{f1}/{f1} {f2}/{f2}/{f2} {f3}/{f3}/{f3}\n")
                
            f.write("\ng ShellInner\nusemtl ShellInner\n")
            for f1, f2, f3 in inner_faces:
                f.write(f"f {f1}/{f1}/{f1} {f2}/{f2}/{f2} {f3}/{f3}/{f3}\n")

    # Bottom valve: reclines back at 18 degrees above horizontal seabed
    # Top valve: opens up high at 70 degrees above horizontal seabed (opening 52 degrees)
    generate_valve(is_top=False, tilt_deg=18.0, hinge_offset_y=-0.15, filename="C:/Users/zeyne/Desktop/Cop31/assets/midye_bottom.obj")
    generate_valve(is_top=True, tilt_deg=70.0, hinge_offset_y=-0.15, filename="C:/Users/zeyne/Desktop/Cop31/assets/midye_top.obj")
    print("SUCCESS: Generated Pinna nobilis midye_bottom.obj and midye_top.obj")

if __name__ == "__main__":
    generate_pinna_nobilis()
