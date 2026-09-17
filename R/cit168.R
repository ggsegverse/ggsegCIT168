#' CIT168 Reinforcement-Learning Subcortical Atlas
#'
#' Probabilistic subcortical atlas built from high-resolution 7 Tesla Human
#' Connectome Project data, with 14 structures per hemisphere. It covers the
#' striatum and pallidum alongside the small midbrain and diencephalic nuclei
#' that coarser atlases lump together as "ventral DC": substantia nigra
#' (pars compacta and pars reticulata), red nucleus, subthalamic nucleus,
#' habenula and mammillary body. Drawn in four views, two coronal and two
#' axial, with the surrounding brain in grey for anatomical context. Contains
#' 2D polygon geometry for [ggseg::geom_brain()] and 3D mesh data for
#' [ggseg3d::ggseg3d()].
#'
#' Labels keep the abbreviations the published lookup table uses (`Pu`, `SNr`,
#' `SNc_PBP_VTA`), and `region` is those stripped of the hemisphere suffix and
#' lower-cased, so both are easy to match on. The `name` column carries the
#' spelled-out structure name for printing to a reader.
#'
#' @family ggseg_atlases
#' @family subcortical_atlases
#'
#' @references Pauli WM, Nili AN, Tyszka JM (2018). A high-resolution
#'   probabilistic in vivo atlas of human subcortical brain nuclei.
#'   *Scientific Data*, 5, 180063.
#'   (\doi{10.1038/sdata.2018.63})
#'
#' @return A [ggseg.formats::ggseg_atlas] object (subcortical).
#' @export
#' @examples
#' cit168()
#' plot(cit168())
cit168 <- function() .cit168
