function(input, output, session) {
  maindata <- reactiveVal(NULL)

  # Set the data source
  observeEvent(input$datafile, {
    file <- input$datafile$datapath
    maindata(read.csv(file, na.strings = c("NA", ".")))
  })
  observeEvent(input$sample_data_btn, {
    data <- get_sample_data()
    maindata(data)
  })

  # Show inputs once the data source exists
  observeEvent(maindata(), once = TRUE, {
    shinyjs::show("exposurevariables")
    shinyjs::show("covariates")
    shinyjs::show("covvalueorder")
    shinyjs::show("shapebyparamname")
  })

  # Update the options in different inputs based on data
  observe({
    df <- maindata()
    req(df)
    choices <- unique(df[["paramname"]])
    updateSelectizeInput(session, "exposurevariables",
                         choices = choices, selected = choices[1])
  })
  observe({
    df <- maindata()
    req(df)
    df <- df %>%
      filter(paramname %in% c(input$exposurevariables))
    choices <- unique(df[["covname"]])
    updateSelectizeInput(session, "covariates",
                         choices = choices, selected = choices)
  })
  observe({
    df <- maindata()
    req(df)
    df <- df %>%
      filter(paramname %in% c(input$exposurevariables)) %>%
      filter(covname %in% c(input$covariates))
    choices <- as.character(unique(df[["label"]]))
    updateSelectizeInput(session, "covvalueorder",
                         choices = choices, selected = choices)
  })

  formatstats  <- reactive({
    df <- maindata()
    req(df)
    validate(need(
      length(input$covariates) >= 1,
      "Please select a least one covariate or All"
    ))
    validate(need(
      length(input$covvalueorder) >= 1,
      "Please select a least one covariate/All level"
    ))
    df$covname <- factor(df$covname)
    df$label <- factor(df$label)
    df$ref <- 1
    df$exposurename <- df$paramname
    sigdigits <- input$sigdigits
    summarydata <- df %>%
      group_by(paramname, covname, label) %>%
      mutate(
        MEANEXP = mid,
        LOWCI = lower,
        UPCI =  upper,
        MEANLABEL = signif_pad(MEANEXP, sigdigits),
        LOWCILABEL = signif_pad(LOWCI, sigdigits),
        UPCILABEL = signif_pad(UPCI, sigdigits),
        LABEL = paste0(MEANLABEL, " [", LOWCILABEL, "-", UPCILABEL, "]")
      )

    summarydata$covvalue <- factor(summarydata$label)
    summarydata <- summarydata %>%
      filter(covname %in% c(input$covariates)) %>%
      filter(paramname %in% input$exposurevariables)
    summarydata <- as.data.frame(summarydata)
    summarydata
  })


  output$refarea <- renderUI({
    REF <- 1
    ymin <- REF * 0.8
    ymax <- REF * 1.25
    ymaxmax <- REF * 5
    ystep <- 0.05
    sliderInput(
      "refareain",
      "Reference Area",
      min = 0,
      max = ymaxmax,
      value = c(ymin, ymax),
      step = ystep,
      animate = FALSE
    )

  })
  observeEvent(input$colourpointrangereset, {
    shinyjs::reset("colourpointrange")
  })

  observeEvent(input$stripbackfillreset, {
    shinyjs::reset("stripbackgroundfill")
  })
  observeEvent(input$fillrefareareset, {
    shinyjs::reset("fillrefarea")
  })

  plotdataprepare  <- reactive({
    req(formatstats())
    summarydata <-  formatstats()
    summarydata [, "covname"] <-
      factor(summarydata [, "covname"], levels = c(input$covariates))
    summarydata [, "label"]   <-
      factor(summarydata[, "label"]   , levels = c(input$covvalueorder))
    summarydata <- summarydata %>%
      filter(label %in% c(input$covvalueorder))

    summarydata [, "paramname"]   <-
      factor(summarydata[, "paramname"]   , levels = c(input$exposurevariables))

    summarydata
  })

  output$plot <- renderPlot({
    summarydata <- plotdataprepare()
    req(summarydata)

    major_x_ticks <- NULL
    minor_x_ticks <- NULL
    if (input$customxticks) {
      tryCatch({
         major_x_ticks <- as.numeric(unique(unlist(strsplit(input$xaxisbreaks, ",")[[1]])))
      }, warning = function(w) {}, error = function(e) {})
      tryCatch({
        minor_x_ticks <- as.numeric(unique(unlist(strsplit(input$xaxisminorbreaks, ",")[[1]])))
      }, warning = function(w) {}, error = function(e) {})
    }

    plot <- forest_plot(
      data = summarydata,
      facet_formula = input$facetformula,
      xlabel = input$xaxistitle,
      ylabel = input$yaxistitle,
      x_facet_text_size = input$facettextx,
      y_facet_text_size = input$facettexty,
      x_label_text_size = input$xlablesize,
      y_label_text_size = input$ylablesize,
      table_text_size = input$tabletextsize,
      ref_legend_text = escape_newline(input$customlinetypetitle),
      area_legend_text = escape_newline(input$customfilltitle),
      interval_legend_text = escape_newline(input$customcolourtitle),
      legend_order = input$legendordering,
      combine_area_ref_legend = input$combineareareflegend,
      show_ref_area = input$showrefarea,
      ref_area = input$refareain,
      ref_value = 1,
      ref_area_col = input$fillrefarea,
      interval_col = input$colourpointrange,
      strip_col = input$stripbackgroundfill,
      paramname_shape = input$shapebyparamname,
      facet_switch = input$facetswitch,
      facet_scales = input$facetscales,
      facet_space = input$facetspace,
      strip_placement = input$stripplacement,
      major_x_ticks = major_x_ticks,
      minor_x_ticks = minor_x_ticks,
      x_range = if (input$userxzoom) c(input$lowerxin, input$upperxin),
      show_table_facet_strip = input$showtablefacetstrips,
      table_position = input$tableposition,
      plot_table_ratio = input$plottotableratio
    )
    plot
  }, height = function() {
    input$height
  })
}
