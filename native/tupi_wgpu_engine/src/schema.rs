use serde::{Deserialize, Serialize};

/// Temporal Epochs recognized across the Pindorama historical continuum.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EpochId {
    Pre1500,
    Epoch1532,
    Epoch1554,
    Epoch1555,
    Epoch1567,
    Atual,
}

/// 2D World Coordinate in continuous cartographic units.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct WorldPoint {
    pub x: f32,
    pub y: f32,
}

/// Axis-Aligned Bounding Box for spatial partitioning & frustum culling.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BoundingBox {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl BoundingBox {
    pub fn intersects(&self, other: &BoundingBox) -> bool {
        self.min_x <= other.max_x
            && self.max_x >= other.min_x
            && self.min_y <= other.max_y
            && self.max_y >= other.min_y
    }

    pub fn contains_point(&self, p: &WorldPoint) -> bool {
        p.x >= self.min_x && p.x <= self.max_x && p.y >= self.min_y && p.y <= self.max_y
    }
}

/// Cubic Bézier control points defining smooth river channel geometries.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiverSegmentDef {
    pub start: WorldPoint,
    pub ctrl1: WorldPoint,
    pub ctrl2: WorldPoint,
    pub end: WorldPoint,
    pub start_width: f32,
    pub end_width: f32,
}

/// River basin containing continuous cubic spline segments and carved bank parameters.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiverPathDef {
    pub id: String,
    pub name_tupi: String,
    pub name_pt: String,
    pub segments: Vec<RiverSegmentDef>,
    pub trench_depth_ratio: f32,
    pub sand_bank_margin_ratio: f32,
    pub wet_clay_margin_ratio: f32,
    pub water_color_hex: u32,
}

/// Botanical vegetation instance type.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u32)]
pub enum VegetationKind {
    CanopyGiant = 0,
    DenseMata = 1,
    PalmeiraJucara = 2,
    Araucaria = 3,
    ShrubBush = 4,
    HighlandTree = 5,
    TallGrassTuft = 6,
    WildFern = 7,
    MossyLog = 8,
    ForestStone = 9,
}

/// Compact data-oriented tree/vegetation instance for instanced GPU drawing.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[repr(C)]
pub struct VegetationInstance {
    pub pos_x: f32,
    pub pos_y: f32,
    pub scale: f32,
    pub rotation: f32,
    pub kind: u32,
    pub seed: u32,
}

/// Classification of physical architectural structures across historical epochs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u32)]
pub enum StructureKind {
    IndigenousOca = 0,
    IndigenousCouncilMaloca = 1,
    CentralCampfire = 2,
    DryingRackMoquem = 3,
    CanoeUba = 4,
    PalisadeStockade = 5,
    FeitoriaWarehouse1532 = 6,
    TradingPostDepot1532 = 7,
    ColonialMissionFort1554 = 8,
    ColonialStoneBuilding1554 = 9,
    ColonialWoodenBridge1554 = 10,
    HistoricalMonolith = 11,
}

/// Renderable physical structure in the 2.5D world scene.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructureInstance {
    pub id: String,
    pub structure_type: StructureKind,
    pub position: WorldPoint,
    pub width: f32,
    pub height: f32,
    pub rotation: f32,
    pub min_epoch: EpochId,
    pub max_epoch: Option<EpochId>,
}

/// Master World Map and Phase Definition Schema.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorldMapDefinition {
    pub map_id: String,
    pub world_width: f32,
    pub world_height: f32,
    pub active_epoch: EpochId,
    pub rivers: Vec<RiverPathDef>,
    pub structures: Vec<StructureInstance>,
    pub vegetation: Vec<VegetationInstance>,
}
