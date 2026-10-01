use crate::schema::{BoundingBox, StructureInstance, VegetationInstance, WorldPoint};

/// Camera viewport state used for frustum culling and screen projection.
#[derive(Debug, Clone, Copy)]
pub struct CameraFrustum {
    pub center_x: f32,
    pub center_y: f32,
    pub zoom: f32,
    pub screen_width: f32,
    pub screen_height: f32,
    pub bounds: BoundingBox,
}

impl CameraFrustum {
    pub fn new(center_x: f32, center_y: f32, zoom: f32, screen_width: f32, screen_height: f32) -> Self {
        let half_w = (screen_width * 0.5) / zoom;
        let half_h = (screen_height * 0.5) / zoom;

        // Expanded margin for 2.5D element heights (trees, roofs)
        let margin_x = 120.0;
        let margin_y = 180.0;

        let bounds = BoundingBox {
            min_x: center_x - half_w - margin_x,
            min_y: center_y - half_h - margin_y,
            max_x: center_x + half_w + margin_x,
            max_y: center_y + half_h + margin_y,
        };

        Self {
            center_x,
            center_y,
            zoom,
            screen_width,
            screen_height,
            bounds,
        }
    }

    #[inline(always)]
    pub fn is_point_visible(&self, x: f32, y: f32) -> bool {
        x >= self.bounds.min_x && x <= self.bounds.max_x && y >= self.bounds.min_y && y <= self.bounds.max_y
    }

    #[inline(always)]
    pub fn is_box_visible(&self, aabb: &BoundingBox) -> bool {
        self.bounds.intersects(aabb)
    }

    /// Fast spatial filter for vegetation instances.
    pub fn cull_vegetation<'a>(&self, instances: &'a [VegetationInstance]) -> Vec<&'a VegetationInstance> {
        instances
            .iter()
            .filter(|v| self.is_point_visible(v.pos_x, v.pos_y))
            .collect()
    }

    /// High-performance vegetation culling with village clearance zone (clearanceRadius: 90.0 px).
    /// Filters out trees outside frustum and trees within 90.0px of any village/structure center.
    pub fn cull_vegetation_with_clearance<'a>(
        &self,
        instances: &'a [VegetationInstance],
        clearance_centers: &[[f32; 2]],
        clearance_radius: f32,
    ) -> Vec<&'a VegetationInstance> {
        let clearance_sq = clearance_radius * clearance_radius;
        let mut out = Vec::with_capacity(instances.len() / 2);

        for v in instances {
            if !self.is_point_visible(v.pos_x, v.pos_y) {
                continue;
            }

            let mut within_clear_zone = false;
            for &[cx, cy] in clearance_centers {
                let dx = v.pos_x - cx;
                let dy = v.pos_y - cy;
                if dx * dx + dy * dy < clearance_sq {
                    within_clear_zone = true;
                    break;
                }
            }

            if !within_clear_zone {
                out.push(v);
            }
        }

        out
    }

    /// Fast spatial filter for physical structures.
    pub fn cull_structures<'a>(&self, structures: &'a [StructureInstance]) -> Vec<&'a StructureInstance> {
        structures
            .iter()
            .filter(|s| {
                let box_s = BoundingBox {
                    min_x: s.position.x - s.width * 0.6,
                    min_y: s.position.y - s.height * 0.6,
                    max_x: s.position.x + s.width * 0.6,
                    max_y: s.position.y + s.height * 0.6,
                };
                self.is_box_visible(&box_s)
            })
            .collect()
    }
}
