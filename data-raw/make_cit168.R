# Create the CIT168 reinforcement-learning subcortical atlas for ggseg
#
# CIT168 is a probabilistic subcortical atlas built from high-resolution 7T
# HCP data, covering the structures the reinforcement-learning literature
# cares about: the striatum and pallidum, and the small midbrain and
# diencephalic nuclei (substantia nigra, red nucleus, subthalamic nucleus,
# habenula, mammillary body) that coarser atlases lump into "ventral DC".
#
# The published volume carries no anatomical context, so as with the other
# MNI152 subcortical atlases in the ggsegverse it is embedded into the
# fsaverage5 aseg with prepare_subcortical_mni152(), which registers it
# through the fixed mni152.register.dat transform, replaces the lumped aseg
# structures it subdivides, and returns a merged volume plus colour table for
# the subcortical pipeline. aseg_context() then demotes the surrounding brain
# to grey, leaving the parcels drawn on the cortical ribbon.
#
# Source: https://github.com/anniegbryant/subcortex_visualization
#   (atlas_info/MNI152NLin6Asym/CIT168_subcortex), originally
#   https://osf.io/jkzwp/
# Reference: Pauli WM, Nili AN, Tyszka JM (2018). A high-resolution
#   probabilistic in vivo atlas of human subcortical brain nuclei.
#   Scientific Data 5:180063. DOI: 10.1038/sdata.2018.63
#
# Requires: ggseg.extra, ggseg.formats, FreeSurfer 7.4.1 with fsaverage5.
#
# Run with: Rscript data-raw/make_cit168.R

library(ggseg.extra)
library(ggseg.formats)

future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

fs_home <- Sys.getenv("FREESURFER_HOME", "/Applications/freesurfer/7.4.1")
Sys.setenv(FREESURFER_HOME = fs_home)
Sys.setenv(SUBJECTS_DIR = file.path(fs_home, "subjects"))

data_raw <- here::here("data-raw")
source_dir <- file.path(data_raw, "source")
volume <- file.path(source_dir, "CIT168_subcortex.nii.gz")
stopifnot("CIT168_subcortex.nii.gz not found" = file.exists(volume))

# CIT168 numbers its left hemisphere 1-16 and its right 101-116, so the left
# ids collide with the aseg ids they are stamped into. The shift has to clear
# those from below and stay under 1000 from above: ids in 1000-2999 are where
# an aparc+aseg keeps its cortical parcels, and a pipeline that finds parcels
# there reads them as the cortex and builds the brain silhouette out of them
# instead of the cortical ribbon.
id_offset <- 300L

# Labels keep the abbreviations the source atlas uses, so a label still
# identifies a parcel in the published lookup table, and `region` falls out of
# them by the usual strip (lower case, hemisphere dropped). The spelled-out
# names go in a `name` column instead, keyed on region, for anything that
# prints a structure to a reader rather than matching on it.
region_names <- c(
  pu = "Putamen",
  ca = "Caudate",
  nac = "Nucleus accumbens",
  exa = "Extended amygdala",
  gpe = "Globus pallidus, external segment",
  gpi = "Globus pallidus, internal segment",
  "snc pbp vta" = "Substantia nigra pars compacta, parabrachial pigmented nucleus and ventral tegmental area",
  rn = "Red nucleus",
  snr = "Substantia nigra pars reticulata",
  vep = "Ventral pallidum",
  hn = "Habenular nuclei",
  hth = "Hypothalamus",
  mn = "Mammillary nucleus",
  sth = "Subthalamic nucleus"
)

# The `region` a label strips down to: what the pipeline derives, and what the
# `name` column is keyed on.
strip_to_region <- function(label) {
  tolower(gsub("_", " ", sub("_(Left|Right)$", "", label)))
}

# One colour per structure, shared by the two sides, so a structure reads as
# the same thing on both halves of the plot.
structure_colours <- function(structure) {
  structures <- sort(unique(structure))
  hues <- grDevices::hcl.colors(length(structures), palette = "Dark 3")
  hues[match(structure, structures)]
}

read_cit168_lut <- function() {
  lookup <- utils::read.csv(
    file.path(source_dir, "CIT168_subcortex_lookup.csv"),
    fileEncoding = "UTF-8-BOM"
  )
  names(lookup) <- c("idx", "name")

  hemi <- ifelse(grepl("_LH$", lookup$name), "Left", "Right")
  if (!all(grepl("_(LH|RH)$", lookup$name))) {
    cli::cli_abort(
      "Every CIT168 parcel name must end in {.val _LH} or {.val _RH}."
    )
  }

  structure <- sub("_(LH|RH)$", "", lookup$name)
  unknown <- setdiff(strip_to_region(structure), names(region_names))
  if (length(unknown)) {
    cli::cli_abort("No spelled-out name for {.val {unknown}}.")
  }

  rgb <- grDevices::col2rgb(structure_colours(structure))

  data.frame(
    idx = as.integer(lookup$idx) + id_offset,
    label = paste(structure, hemi, sep = "_"),
    R = as.integer(rgb[1, ]),
    G = as.integer(rgb[2, ]),
    B = as.integer(rgb[3, ]),
    A = 0L,
    stringsAsFactors = FALSE
  )
}

# geom_brain() paints rows in order, so the last one lands on top. Sorting by
# structure with the two sides adjacent keeps a structure at the same depth as
# its contralateral twin, and the grey silhouette leads because it is the
# background the rest sits on and the only geometry present in every view.
draw_order <- function(atlas) {
  drawn <- atlas_geom(atlas)$label
  is_silhouette <- grepl("^cortex", drawn)
  by_structure <- function(x) {
    x[order(
      toupper(sub("_(Left|Right)$", "", x)),
      toupper(x),
      method = "radix"
    )]
  }
  atlas_structure_reorder(
    atlas,
    c(by_structure(drawn[is_silhouette]), by_structure(drawn[!is_silhouette]))
  )
}

cli::cli_h1("CIT168 subcortical")

# Wiped rather than reused: contours left over from an earlier slab layout are
# re-read by the pipeline and land in the atlas with no matching view.
work_dir <- file.path(data_raw, "cit168")
unlink(work_dir, recursive = TRUE)
dir.create(work_dir, showWarnings = FALSE, recursive = TRUE)

lut <- read_cit168_lut()

shifted <- file.path(work_dir, "cit168_offset.nii.gz")
vol <- RNifti::readNifti(volume)
arr <- as.array(vol)
storage.mode(arr) <- "integer"
out <- array(0L, dim = dim(arr))
hit <- arr > 0L
out[hit] <- arr[hit] + id_offset
RNifti::writeNifti(RNifti::asNifti(out, reference = vol), shifted)

merged <- prepare_subcortical_mni152(
  input_volume = shifted,
  labels = lut$idx,
  lut = lut,
  output_file = file.path(work_dir, "cit168_in_aseg.nii.gz")
)

slabs <- subcortical_slabs(
  merged$volume,
  labels = lut$idx,
  coronal = 2,
  axial = 2,
  pad = 2
)

raw <- create_subcortical_from_volume(
  input_volume = merged,
  atlas_name = "cit168",
  output_dir = work_dir,
  slabs = slabs,
  skip_existing = FALSE,
  cleanup = FALSE
)

# Post-creation, so retuning any of it is seconds rather than a rebuild. The
# parcels are grown a little to survive at plotting size; the silhouette is
# not, since dilating it closes the sulci. Simplify before smoothing, or the
# dropped vertices put the voxel staircase back.
#
# The two are smoothed at different strengths. The parcels are small, blocky
# and read as shapes, so they take a heavy pass; the silhouette is a gyrified
# ribbon whose detail *is* the anatomy, and smoothing it that hard closes the
# sulci and fills the interior back in.
cit168 <- raw |>
  aseg_context(focus = paste(lut$label, collapse = "|"), match_on = "label") |>
  atlas_view_gather() |>
  atlas_dilate(0.6, exclude = "^cortex") |>
  atlas_simplify(keep = 0.2, labels = "^cortex") |>
  atlas_simplify(keep = 0.35, exclude = "^cortex") |>
  atlas_smooth(smoothness = 0.3, labels = "^cortex") |>
  atlas_smooth(smoothness = 0.9, exclude = "^cortex") |>
  draw_order()

cit168 <- atlas_core_add(
  cit168,
  data.frame(
    region = names(region_names),
    name = unname(region_names),
    stringsAsFactors = FALSE
  ),
  by = "region"
)

cli::cli_alert_success(
  "{length(atlas_labels(cit168))} structures in \\
   {length(atlas_views(cit168))} views"
)

.cit168 <- cit168
usethis::use_data(.cit168, internal = TRUE, overwrite = TRUE, compress = "xz")
