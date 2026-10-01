use crate::schema::{BoundingBox, RiverPathDef, RiverSegmentDef, WorldPoint};

/// Vertex format for GPU river mesh tessellation.
#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct RiverVertex {
    pub position: [f32; 2],
    pub color: [f32; 4],
    pub uv: [f32; 2],
}

/// Evaluates cubic Bézier curve at parametric factor t in [0.0..1.0].
#[inline]
pub fn evaluate_cubic_bezier(seg: &RiverSegmentDef, t: f32) -> WorldPoint {
    let u = 1.0 - t;
    let tt = t * t;
    let uu = u * u;
    let uuu = uu * u;
    let ttt = tt * t;

    let x = uuu * seg.start.x + 3.0 * uu * t * seg.ctrl1.x + 3.0 * u * tt * seg.ctrl2.x + ttt * seg.end.x;
    let y = uuu * seg.start.y + 3.0 * uu * t * seg.ctrl1.y + 3.0 * u * tt * seg.ctrl2.y + ttt * seg.end.y;

    WorldPoint { x, y }
}

/// Evaluates normalized tangent (dx, dy) along the cubic Bézier curve.
#[inline]
pub fn evaluate_bezier_tangent(seg: &RiverSegmentDef, t: f32) -> (f32, f32) {
    let u = 1.0 - t;
    let c0 = 3.0 * u * u;
    let c1 = 6.0 * u * t;
    let c2 = 3.0 * t * t;

    let dx = c0 * (seg.ctrl1.x - seg.start.x)
        + c1 * (seg.ctrl2.x - seg.ctrl1.x)
        + c2 * (seg.end.x - seg.ctrl2.x);
    let dy = c0 * (seg.ctrl1.y - seg.start.y)
        + c1 * (seg.ctrl2.y - seg.ctrl1.y)
        + c2 * (seg.end.y - seg.ctrl2.y);

    let len = (dx * dx + dy * dy).sqrt();
    if len < 1e-5 {
        (1.0, 0.0)
    } else {
        (dx / len, dy / len)
    }
}

/// Evaluates the normal vector (perpendicular to tangent).
#[inline]
pub fn evaluate_bezier_normal(seg: &RiverSegmentDef, t: f32) -> (f32, f32) {
    let (tx, ty) = evaluate_bezier_tangent(seg, t);
    (-ty, tx)
}

/// Interpolates river channel width at factor t with natural organic undulation.
#[inline]
pub fn evaluate_river_width(seg: &RiverSegmentDef, t: f32) -> f32 {
    let base = seg.start_width + (seg.end_width - seg.start_width) * t;
    // Subtle organic undulation along the watercourse
    let undulation = 1.0 + 0.07 * (t * std::f32::consts::PI * 4.0 + (seg.start.x * 0.01)).sin()
        + 0.03 * (t * std::f32::consts::PI * 8.0 + (seg.start.y * 0.01)).cos();
    base * undulation
}

/// Continuous carved river channel generator with transition margins:
/// 1. Outer Trench / Mud Margin (#4A3525 com opacidade e nós irregulares)
/// 2. Sand & Packed Soil Margin (Terra batida e areia de barranco)
/// 3. Wet Clay Contact Rim (Argila escura de contato)
/// 4. Water Bed Surface (#1A4B6E com curvatura orgânica e profundidade natural)
pub struct RiverTessellator;

impl RiverTessellator {
    /// Appends tessellated vertices directly into an existing buffer to prevent heap allocation churn on Android.
    pub fn tessellate_channel_into(
        river: &RiverPathDef,
        steps_per_segment: usize,
        viewport_bounds: Option<&BoundingBox>,
        vertices: &mut Vec<RiverVertex>,
    ) {
        for seg in &river.segments {
            // Frustum cull segment against viewport if provided
            if let Some(bounds) = viewport_bounds {
                let seg_box = BoundingBox {
                    min_x: seg.start.x.min(seg.end.x) - seg.end_width * 2.5,
                    min_y: seg.start.y.min(seg.end.y) - seg.end_width * 2.5,
                    max_x: seg.start.x.max(seg.end.x) + seg.end_width * 2.5,
                    max_y: seg.start.y.max(seg.end.y) + seg.end_width * 2.5,
                };
                if !bounds.intersects(&seg_box) {
                    continue;
                }
            }

            for step in 0..steps_per_segment {
                let t0 = step as f32 / steps_per_segment as f32;
                let t1 = (step + 1) as f32 / steps_per_segment as f32;

                let p0 = evaluate_cubic_bezier(seg, t0);
                let p1 = evaluate_cubic_bezier(seg, t1);

                let (nx0, ny0) = evaluate_bezier_normal(seg, t0);
                let (nx1, ny1) = evaluate_bezier_normal(seg, t1);

                let w0 = evaluate_river_width(seg, t0);
                let w1 = evaluate_river_width(seg, t1);

                // Irregular margin nodes along natural earthen banks
                let irreg0 = 0.94 + 0.12 * ((step as f32 * 2.3) + seg.start.x * 0.05).sin();
                let irreg1 = 0.94 + 0.12 * (((step + 1) as f32 * 2.3) + seg.start.x * 0.05).sin();

                // Margin layer multipliers
                let outer_ratio_0 = 1.90 * irreg0; // Outer mud/sand irregular margin
                let outer_ratio_1 = 1.90 * irreg1;
                let sand_ratio = 1.45;            // Sand and packed loam
                let clay_ratio = 1.15;            // Wet clay contact rim
                let water_ratio = 1.00;           // Center river water channel

                // 1. Water channel (Centro do rio: #1A4B6E)
                Self::emit_quad(
                    vertices,
                    p0, p1,
                    (nx0, ny0), (nx1, ny1),
                    w0 * 0.5 * water_ratio, w1 * 0.5 * water_ratio,
                    [0.102, 0.294, 0.431, 0.95], // #1A4B6E deep flowing water
                    0.0, 1.0,
                );

                // 2. Wet clay contact rim
                Self::emit_strip_border(
                    vertices,
                    p0, p1,
                    (nx0, ny0), (nx1, ny1),
                    w0 * 0.5 * water_ratio, w1 * 0.5 * water_ratio,
                    w0 * 0.5 * clay_ratio, w1 * 0.5 * clay_ratio,
                    [0.22, 0.15, 0.10, 0.85],
                );

                // 3. Sand / packed earth margin
                Self::emit_strip_border(
                    vertices,
                    p0, p1,
                    (nx0, ny0), (nx1, ny1),
                    w0 * 0.5 * clay_ratio, w1 * 0.5 * clay_ratio,
                    w0 * 0.5 * sand_ratio, w1 * 0.5 * sand_ratio,
                    [0.55, 0.42, 0.28, 0.85],
                );

                // 4. Outer mud/sand margin (Borda externa: #4A3525 com opacidade e nós irregulares)
                Self::emit_strip_border(
                    vertices,
                    p0, p1,
                    (nx0, ny0), (nx1, ny1),
                    w0 * 0.5 * sand_ratio, w1 * 0.5 * sand_ratio,
                    w0 * 0.5 * outer_ratio_0, w1 * 0.5 * outer_ratio_1,
                    [0.290, 0.208, 0.145, 0.70], // #4A3525 outer mud margin
                );
            }
        }
    }

    /// Tessellates a continuous river path into multi-layered triangle strip vertices.
    pub fn tessellate_channel(
        river: &RiverPathDef,
        steps_per_segment: usize,
        viewport_bounds: Option<&BoundingBox>,
    ) -> Vec<RiverVertex> {
        let mut vertices = Vec::with_capacity(river.segments.len() * steps_per_segment * 30);
        Self::tessellate_channel_into(river, steps_per_segment, viewport_bounds, &mut vertices);
        vertices
    }

    #[inline]
    fn emit_quad(
        vertices: &mut Vec<RiverVertex>,
        p0: WorldPoint, p1: WorldPoint,
        n0: (f32, f32), n1: (f32, f32),
        half_w0: f32, half_w1: f32,
        color: [f32; 4],
        u0: f32, u1: f32,
    ) {
        let v0_left = [p0.x - n0.0 * half_w0, p0.y - n0.1 * half_w0];
        let v0_right = [p0.x + n0.0 * half_w0, p0.y + n0.1 * half_w0];
        let v1_left = [p1.x - n1.0 * half_w1, p1.y - n1.1 * half_w1];
        let v1_right = [p1.x + n1.0 * half_w1, p1.y + n1.1 * half_w1];

        // Triangle 1
        vertices.push(RiverVertex { position: v0_left, color, uv: [0.0, u0] });
        vertices.push(RiverVertex { position: v1_left, color, uv: [0.0, u1] });
        vertices.push(RiverVertex { position: v0_right, color, uv: [1.0, u0] });

        // Triangle 2
        vertices.push(RiverVertex { position: v0_right, color, uv: [1.0, u0] });
        vertices.push(RiverVertex { position: v1_left, color, uv: [0.0, u1] });
        vertices.push(RiverVertex { position: v1_right, color, uv: [1.0, u1] });
    }

    #[inline]
    fn emit_strip_border(
        vertices: &mut Vec<RiverVertex>,
        p0: WorldPoint, p1: WorldPoint,
        n0: (f32, f32), n1: (f32, f32),
        inner_w0: f32, inner_w1: f32,
        outer_w0: f32, outer_w1: f32,
        color: [f32; 4],
    ) {
        // Left bank border
        let l_in0 = [p0.x - n0.0 * inner_w0, p0.y - n0.1 * inner_w0];
        let l_out0 = [p0.x - n0.0 * outer_w0, p0.y - n0.1 * outer_w0];
        let l_in1 = [p1.x - n1.0 * inner_w1, p1.y - n1.1 * inner_w1];
        let l_out1 = [p1.x - n1.0 * outer_w1, p1.y - n1.1 * outer_w1];

        vertices.push(RiverVertex { position: l_out0, color, uv: [0.0, 0.0] });
        vertices.push(RiverVertex { position: l_out1, color, uv: [0.0, 1.0] });
        vertices.push(RiverVertex { position: l_in0, color, uv: [1.0, 0.0] });

        vertices.push(RiverVertex { position: l_in0, color, uv: [1.0, 0.0] });
        vertices.push(RiverVertex { position: l_out1, color, uv: [0.0, 1.0] });
        vertices.push(RiverVertex { position: l_in1, color, uv: [1.0, 1.0] });

        // Right bank border
        let r_in0 = [p0.x + n0.0 * inner_w0, p0.y + n0.1 * inner_w0];
        let r_out0 = [p0.x + n0.0 * outer_w0, p0.y + n0.1 * outer_w0];
        let r_in1 = [p1.x + n1.0 * inner_w1, p1.y + n1.1 * inner_w1];
        let r_out1 = [p1.x + n1.0 * outer_w1, p1.y + n1.1 * outer_w1];

        vertices.push(RiverVertex { position: r_in0, color, uv: [0.0, 0.0] });
        vertices.push(RiverVertex { position: r_in1, color, uv: [0.0, 1.0] });
        vertices.push(RiverVertex { position: r_out0, color, uv: [1.0, 0.0] });

        vertices.push(RiverVertex { position: r_out0, color, uv: [1.0, 0.0] });
        vertices.push(RiverVertex { position: r_in1, color, uv: [0.0, 1.0] });
        vertices.push(RiverVertex { position: r_out1, color, uv: [1.0, 1.0] });
    }
}
