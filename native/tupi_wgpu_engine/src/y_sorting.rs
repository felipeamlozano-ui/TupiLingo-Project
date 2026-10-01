use crate::culling::CameraFrustum;
use crate::schema::{EpochId, StructureInstance, StructureKind, VegetationInstance};

/// Represents an abstract render item participating in isometric depth sorting.
#[derive(Debug, Clone)]
pub enum IsometricRenderItem<'a> {
    Vegetation(&'a VegetationInstance),
    Structure(&'a StructureInstance),
}

impl<'a> IsometricRenderItem<'a> {
    #[inline]
    pub fn sort_y(&self) -> f32 {
        match self {
            IsometricRenderItem::Vegetation(v) => v.pos_y,
            IsometricRenderItem::Structure(s) => {
                // In classic isometric games (AoE/Zomboid), structure base contact is bottom of footprint
                s.position.y + s.height * 0.35
            }
        }
    }
}

/// Unified Isometric Depth Sorting (Y-Sorting) Engine.
pub struct IsometricDepthSorter;

impl IsometricDepthSorter {
    /// Collects, filters by epoch, applies village clearance zones (90.0px), culls against frustum, and sorts all 2.5D objects.
    pub fn sort_render_queue_into<'a>(
        vegetation: &'a [VegetationInstance],
        structures: &'a [StructureInstance],
        frustum: &CameraFrustum,
        current_epoch: EpochId,
        queue: &mut Vec<IsometricRenderItem<'a>>,
    ) {
        queue.clear();

        // 1. Collect village / oca centers for clearance exclusion (clearanceRadius: 90.0 px)
        let clearance_radius = 90.0f32;
        let clearance_sq = clearance_radius * clearance_radius;
        let mut village_centers = Vec::with_capacity(structures.len());

        for s in structures {
            if Self::is_structure_active_in_epoch(s, current_epoch) {
                // If it is an indigenous village structure (Oca, Maloca, Campfire, etc.)
                if matches!(
                    s.structure_type,
                    StructureKind::IndigenousOca
                        | StructureKind::IndigenousCouncilMaloca
                        | StructureKind::CentralCampfire
                        | StructureKind::HistoricalMonolith
                ) {
                    village_centers.push((s.position.x, s.position.y));
                }

                // Cull and add structure itself to render queue
                if frustum.is_point_visible(s.position.x, s.position.y) {
                    queue.push(IsometricRenderItem::Structure(s));
                }
            }
        }

        // 2. Cull & collect vegetation with strict clear zone exclusion
        for v in vegetation {
            if !frustum.is_point_visible(v.pos_x, v.pos_y) {
                continue;
            }

            // Exclude vegetation that falls within clearanceRadius of any village center
            let mut suffocates_village = false;
            for &(cx, cy) in &village_centers {
                let dx = v.pos_x - cx;
                let dy = v.pos_y - cy;
                if dx * dx + dy * dy < clearance_sq {
                    suffocates_village = true;
                    break;
                }
            }

            if !suffocates_village {
                queue.push(IsometricRenderItem::Vegetation(v));
            }
        }

        // 3. Strict Depth Sorting (Y-Sorting): Lower Y (North) renders before Higher Y (South)
        // Ensures foreground trees, ocas, and landmarks overlap background entities correctly
        queue.sort_unstable_by(|a, b| {
            a.sort_y()
                .partial_cmp(&b.sort_y())
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    }

    /// Collects, filters by epoch, culls against frustum, and sorts all 2.5D world objects.
    pub fn sort_render_queue<'a>(
        vegetation: &'a [VegetationInstance],
        structures: &'a [StructureInstance],
        frustum: &CameraFrustum,
        current_epoch: EpochId,
    ) -> Vec<IsometricRenderItem<'a>> {
        let mut queue = Vec::with_capacity(vegetation.len() + structures.len());
        Self::sort_render_queue_into(vegetation, structures, frustum, current_epoch, &mut queue);
        queue
    }

    /// Determines whether a physical structure exists in the specified epoch.
    #[inline]
    pub fn is_structure_active_in_epoch(s: &StructureInstance, epoch: EpochId) -> bool {
        match epoch {
            EpochId::Pre1500 => {
                // Pré-1500: Indigenous only. No colonial feitorias or bridges.
                matches!(
                    s.structure_type,
                    StructureKind::IndigenousOca
                        | StructureKind::IndigenousCouncilMaloca
                        | StructureKind::CentralCampfire
                        | StructureKind::DryingRackMoquem
                        | StructureKind::CanoeUba
                        | StructureKind::PalisadeStockade
                        | StructureKind::HistoricalMonolith
                )
            }
            EpochId::Epoch1532 => {
                // 1532: Indigenous settlements remain, first feitorias and trading posts appear.
                !matches!(
                    s.structure_type,
                    StructureKind::ColonialMissionFort1554
                        | StructureKind::ColonialStoneBuilding1554
                        | StructureKind::ColonialWoodenBridge1554
                )
            }
            EpochId::Epoch1554 | EpochId::Epoch1555 | EpochId::Epoch1567 | EpochId::Atual => {
                // 1554+: Fortifications, missions, stone chapels, and wooden bridges across rivers!
                true
            }
        }
    }
}
