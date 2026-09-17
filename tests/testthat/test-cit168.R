describe("cit168()", {
  it("is a subcortical ggseg_atlas", {
    expect_s3_class(cit168(), "ggseg_atlas")
    expect_s3_class(cit168(), "subcortical_atlas")
    expect_true(ggseg.formats::is_ggseg_atlas(cit168()))
  })

  it("has 14 structures per hemisphere", {
    core <- cit168()$core
    expect_identical(nrow(core), 28L)
    expect_identical(
      as.integer(table(core$hemi)[c("left", "right")]),
      c(14L, 14L)
    )
  })

  it("labels parcels the way the source lookup table does", {
    structures <- unique(sub("_(Left|Right)$", "", cit168()$core$label))
    expect_setequal(
      structures,
      c(
        "Pu",
        "Ca",
        "NAC",
        "EXA",
        "GPe",
        "GPi",
        "SNc_PBP_VTA",
        "RN",
        "SNr",
        "VeP",
        "HN",
        "HTH",
        "MN",
        "STH"
      )
    )
  })

  it("derives region as a plain strip of the label", {
    core <- cit168()$core
    bare <- sub("_(Left|Right)$", "", core$label)
    stripped <- tolower(gsub("_", " ", bare, fixed = TRUE))
    expect_identical(core$region, stripped)
  })

  it("carries a spelled-out name for every region", {
    core <- cit168()$core
    expect_true("name" %in% names(core))
    expect_false(anyNA(core$name))
    expect_identical(
      core$name[core$region == "snr"][1],
      "Substantia nigra pars reticulata"
    )
    expect_identical(core$name[core$region == "sth"][1], "Subthalamic nucleus")
  })

  it("gives both hemispheres of a structure the same name", {
    core <- cit168()$core
    per_region <- tapply(core$name, core$region, function(x) length(unique(x)))
    expect_true(all(per_region == 1))
  })

  it("has 2D polygon geometry in four views", {
    expect_true(ggseg.formats::is_atlas_polygon(cit168()))
    expect_length(ggseg.formats::atlas_views(cit168()), 4)
  })

  it("has a named palette covering every label", {
    pal <- ggseg.formats::atlas_palette(cit168())
    expect_type(pal, "character")
    expect_setequal(names(pal), cit168()$core$label)
  })

  it("has 3D meshes for every label", {
    meshes <- ggseg.formats::atlas_meshes(cit168())
    expect_setequal(meshes$label, cit168()$core$label)
  })

  it("gives both hemispheres of a structure the same colour", {
    pal <- ggseg.formats::atlas_palette(cit168())
    structure <- sub("_(Left|Right)$", "", names(pal))
    per_structure <- tapply(unname(pal), structure, function(x) {
      length(unique(x))
    })
    expect_true(all(per_structure == 1))
  })

  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    expect_doppelganger("cit168-2d", ggseg::brain_test_plot(cit168()))
  })
})
