use crate::culling::CameraFrustum;
use crate::river::RiverTessellator;
use crate::schema::{EpochId, WorldMapDefinition};
use crate::y_sorting::{IsometricDepthSorter, IsometricRenderItem};

/// Representation of GPU render batches ready for draw calls.
pub struct RenderBatchOutput {
    pub river_vertex_count: usize,
    pub sorted_item_count: usize,
    pub camera_zoom: f32,
}

/// Core graphics engine instance maintaining GPU state, map definitions, and persistent buffers.
pub struct TupiIsometricEngine {
    pub map_def: Option<WorldMapDefinition>,
    pub current_epoch: EpochId,
    pub texture_id: i64,
    pub width: u32,
    pub height: u32,
    pub river_vertices: Vec<crate::river::RiverVertex>,
}

impl TupiIsometricEngine {
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            map_def: None,
            current_epoch: EpochId::Pre1500,
            texture_id: 1001, // Canonical Flutter Texture ID for Android FFI binding
            width,
            height,
            river_vertices: Vec::with_capacity(32768), // Pre-allocated persistent vertex pool for Android zero-alloc
        }
    }

    pub fn set_map_definition(&mut self, def: WorldMapDefinition) {
        self.current_epoch = def.active_epoch;
        self.map_def = Some(def);
    }

    pub fn set_epoch(&mut self, epoch: EpochId) {
        self.current_epoch = epoch;
        if let Some(ref mut map) = self.map_def {
            map.active_epoch = epoch;
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    /// Prepares the frame by culling, tessellating rivers with margins, and depth-sorting objects.
    /// Uses persistent buffers to eliminate heap allocation churn on mobile/Android.
    pub fn prepare_frame(
        &mut self,
        camera_x: f32,
        camera_y: f32,
        zoom: f32,
    ) -> Option<RenderBatchOutput> {
        let map = self.map_def.as_ref()?;
        let frustum = CameraFrustum::new(camera_x, camera_y, zoom, self.width as f32, self.height as f32);

        // 1. River tessellation into persistent scratch buffer
        self.river_vertices.clear();
        for river in &map.rivers {
            RiverTessellator::tessellate_channel_into(river, 16, Some(&frustum.bounds), &mut self.river_vertices);
        }
        let total_river_verts = self.river_vertices.len();

        // 2. Unified Depth Sorting (Y-Sorting) for all physical 2.5D objects with 90.0px village clear zones
        let sorted_queue = IsometricDepthSorter::sort_render_queue(
            &map.vegetation,
            &map.structures,
            &frustum,
            self.current_epoch,
        );

        Some(RenderBatchOutput {
            river_vertex_count: total_river_verts,
            sorted_item_count: sorted_queue.len(),
            camera_zoom: zoom,
        })
    }
}
