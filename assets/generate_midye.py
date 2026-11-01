import math

def generate_clam_shells():
    seg_u = 36
    seg_v = 24
    
    def generate_shell(is_top=False, open_angle_deg=55.0, filename=""):
        vertices = []
        uvs = []
        normals = []
        
        angle_rad = math.radians(open_angle_deg) if is_top else 0.0
        cos_a = math.cos(angle_rad)
        sin_a = math.sin(angle_rad)
        
        def calc_pt(u, v, is_inner):
            theta = (u - 0.5) * math.pi * 0.82
            r = v * 2.5
            x = r * math.sin(theta) * 1.35
            z = -v * 2.7
            
            # Arch depth
            arch = math.sin(v * math.pi * 0.75) * math.cos(theta * 1.1) * 0.75
            rib = math.sin(theta * 20.0) * (0.05 if not is_inner else 0.01) * v
            thickness = 0.06
            
            if not is_top:
                y = -(arch + rib + thickness) if not is_inner else -(arch + rib - thickness)
            else:
                y = (arch + rib + thickness) if not is_inner else (arch + rib - thickness)
                y_rot = y * cos_a - z * sin_a
                z_rot = y * sin_a + z * cos_a
                y = y_rot
                z = z_rot
                
            return x, y, z

        outer_grid = []
        inner_grid = []
        
        # Outer surface
        for j in range(seg_v + 1):
            v = j / seg_v
            row = []
            for i in range(seg_u + 1):
                u = i / seg_u
                x, y, z = calc_pt(u, v, is_inner=False)
                idx = len(vertices) + 1
                vertices.append((x, y, z))
                uvs.append((u, v))
                
                ny = -1.0 if not is_top else 1.0
                normals.append((0, ny, 0))
                row.append(idx)
            outer_grid.append(row)
            
        # Inner surface
        for j in range(seg_v + 1):
            v = j / seg_v
            row = []
            for i in range(seg_u + 1):
                u = i / seg_u
                x, y, z = calc_pt(u, v, is_inner=True)
                idx = len(vertices) + 1
                vertices.append((x, y, z))
                uvs.append((u, v))
                
                ny = 1.0 if not is_top else -1.0
                normals.append((0, ny, 0))
                row.append(idx)
            inner_grid.append(row)

        outer_faces = []
        inner_faces = []
        rim_faces = []
        
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
                    
        # Lip rim
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
                
        # Hinge rim
        j = 0
        for i in range(seg_u):
            o1 = outer_grid[j][i]
            o2 = outer_grid[j][i+1]
            i1 = inner_grid[j][i]
            i2 = inner_grid[j][i+1]
            if not is_top:
                rim_faces.append((o1, i2, o2))
                rim_faces.append((o1, i1, i2))
            else:
                rim_faces.append((o1, o2, i2))
                rim_faces.append((o1, i2, i1))

        with open(filename, "w") as f:
            f.write("# Clam Shell\n")
            for v in vertices:
                f.write("v %.4f %.4f %.4f\n" % v)
            for uv in uvs:
                f.write("vt %.4f %.4f\n" % uv)
            for n in normals:
                f.write("vn %.4f %.4f %.4f\n" % n)
                
            f.write("g ShellOuter\nusemtl ShellOuter\n")
            for f1, f2, f3 in outer_faces + rim_faces:
                f.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (f1,f1,f1, f2,f2,f2, f3,f3,f3))
                
            f.write("g ShellInner\nusemtl ShellInner\n")
            for f1, f2, f3 in inner_faces:
                f.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (f1,f1,f1, f2,f2,f2, f3,f3,f3))

    generate_shell(is_top=False, open_angle_deg=0.0, filename="C:/Users/zeyne/Desktop/Cop31/assets/midye_bottom.obj")
    generate_shell(is_top=True, open_angle_deg=55.0, filename="C:/Users/zeyne/Desktop/Cop31/assets/midye_top.obj")
    print("SUCCESS: Generated midye_bottom.obj and midye_top.obj")

if __name__ == "__main__":
    generate_clam_shells()

