#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(rtracklayer)
library(VariantAnnotation)
library(trackViewer)
library(Rsamtools)
# trackViewer version must be no less than 1.19.11
stopifnot(packageVersion("trackViewer")>="1.19.11")

## data folder is used to save the data for ploting
datafolder <- "data"
## installed.packages
ip <- as.data.frame(installed.packages()[, c(1, 3:4)])
ip <- unique(as.character(ip$Package))
txdbs <- ip[grepl("^TxDb", ip)]
orgs <- ip[grepl("^org", ip)]

# Define UI for trackViewer
ui <- fluidPage(
   #link the JS file
   #tags$head(tags$script(src="script.js")),#not work
   # Application title
   titlePanel("trackViewer"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
         selectInput("TxDb", label="select TxDb package",
                     choices = txdbs),
         selectInput("org", label="select Org package", 
                     choices = orgs),
         
         textInput("chr", label = "chromosome", value = "chr3"),
         numericInput("start", label = "start", value = 108476000),
         numericInput("end", label = "end", value = 108485000),
         checkboxInput("trs", "include transcripts track", value = TRUE),
         
         actionButton("add", "add coverage track"),
         actionButton("lolli", "add lollipop plot track"),
         actionButton("addRemote", "add remote coverage track"),
         actionButton("lolliRemote", "add remote lollipop plot track"),
         tags$hr(),
         actionButton("refresh", label="apply change", icon = icon("refresh")),
         actionButton("load", label="load a saved session", icon = icon("upload")),
         tags$hr(),
         
         #actionButton("zoomin", "Zoom in 5X"),
         #actionButton("zoomout", "Zoom out 5X"),
         
         #tags$hr(),
         tags$h4("Set the genomic coordinates for:"),
         actionButton("preSet1", "Example 1"),
         actionButton("preSet2", "Example 2"),
         actionButton("preSet3", "Example 3"),
         actionButton("preSet4", "Example 4"),
         textInput("symbol", label="search by gene name", value = ""),
         tags$script(
                    'Shiny.addCustomMessageHandler("scrollCallback",
                      function(msg) {
                        window.scrollTo(0, 0);
                      });
                    Shiny.addCustomMessageHandler("loadCallback",
                      function(msg){
                        var id = setInterval(frame, 100);
                        function frame(){
                          if(typeof(d3.select("#importjsonfilename"))!="undefined"){
                            if(document.getElementById("importjsonfilename")!= null){
                             clearInterval(id);
                             document.getElementById("importjsonfilename").click();
                            }
                          }
                        }
                      });
                    ')
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
        browseTracksOutput("trackViewer")
      )
   )
)

# Define server logic required to draw tracks
server <- function(input, output, session) {
   global <- reactiveValues(refresh = FALSE, fileIndex=0, lolliIndex=0, 
                            fileinserted=c(), lolliinserted=c(),
                            obsList=list(), forceRefresh = FALSE,
                            remoteurl=NULL)
   observe({
     if(input$refresh){
       isolate(global$refresh <- TRUE)
       isolate(global$forceRefresh <- FALSE)
       session$sendCustomMessage(type="scrollCallback", 1)
       output$trackViewer <- plot
     }else{
       isolate(global$refresh <- FALSE)
       isolate(global$forceRefresh <- FALSE)
     } 
   })
   observeEvent({
     input$TxDb
     input$org
     input$chr
     input$start
     input$end
     input$trs},{
       if(global$forceRefresh){
         isolate(global$refresh <- TRUE)
       }else{
         isolate(global$refresh <- FALSE)
       }
       isolate(global$forceRefresh <- FALSE)
       })
   plot <- renderbrowseTracks({
     if(!global$refresh) return()
     # Create a Progress object
     progress <- shiny::Progress$new()
     progress$set(message="self checking", value=0)
     gr <- GRanges(input$chr, IRanges(as.numeric(input$start), as.numeric(input$end)))
     gr.NCBI <- gr.UCSC <- gr
     seqlevelsStyle(gr.UCSC) <- "UCSC"
     seqlevelsStyle(gr.NCBI) <- "NCBI"
     progress$set(message="loading library", value=0.03)
     require(input$TxDb, character.only = TRUE)
     require(input$org, character.only = TRUE)
     progress$set(message="get transcripts", value=0.05)
     trs <- tryCatch(geneModelFromTxdb(get(input$TxDb), get(input$org), gr=gr.UCSC), 
                     error = function(e){ NULL })
     progress$set(message="reading track data", value=0.15)
     tks <- list()
     step = 0.8/(global$fileIndex+global$lolliIndex)
     if(global$fileIndex>0){
       for(i in seq.int(global$fileIndex)){
         progress$set(message="reading track data", value=0.15+i*step)
         if(paste0("filecontainer", i) %in% global$fileinserted){
           if(paste0("filecontainer", i) %in% global$fileinserted){
             if(input[[paste0("format", i)]]=="bam"){
               tks[[input[[paste0("sample", i)]]]] <- 
                 tryCatch(importBam(file = file.path(datafolder, input[[paste0("file", i)]]),
                                    pairs = testPairedEndBam(file.path(datafolder, input[[paste0("file", i)]])),
                                    ranges = gr.UCSC),
                          error = function(e){ 
                            tryCatch(importBam(file = file.path(datafolder, input[[paste0("file", i)]]),
                                               pairs = testPairedEndBam(file.path(datafolder, input[[paste0("file", i)]])),
                                               ranges = gr.NCBI),
                                     error=function(e){NULL})
                            })
             }else{
               tks[[input[[paste0("sample", i)]]]] <- 
                 tryCatch(importScore(file = ifelse(grepl("\\:\\/\\/", input[[paste0("file", i)]]), 
                                                    input[[paste0("file", i)]],
                                                    file.path(datafolder, input[[paste0("file", i)]])),
                                      format = input[[paste0("format", i)]],
                                      ranges = gr.UCSC), 
                          error = function(e){ 
                            tryCatch(importScore(ifelse(grepl("\\:\\/\\/", input[[paste0("file", i)]]), 
                                                        input[[paste0("file", i)]], 
                                                        file = file.path(datafolder, input[[paste0("file", i)]])),
                                                 format = input[[paste0("format", i)]],
                                                 ranges = gr.NCBI),
                                     error=function(e){NULL})
                            })
             }
           }
         }
       }
     }
     readBED <- function(con, format){
       mutation.frequency <- import(con = con,
                                    format = format,
                                    which = gr)
       if(length(mutation.frequency)==0){
         mutation.frequency <- import(con = con,
                                      format = format,
                                      which = gr.UCSC)
       }
       if(length(mutation.frequency$itemRgb)>0) mutation.frequency$color <- mutation.frequency$itemRgb
       if(length(mutation.frequency$score)==0){
         mutation.frequency$score <- rep(1, length(mutation.frequency))
       }
       if(length(mutation.frequency$name)>0){
         names(mutation.frequency) <- make.names(mutation.frequency$name)
       }
       mutation.frequency
     }
     if(global$lolliIndex>0){
       for(i in seq.int(global$lolliIndex)){
         progress$set(message="reading track data", value=0.15+global$fileIndex*step+i*step)
         if(paste0("lollicontainer", i) %in% global$lolliinserted){
           mutation.frequency <- switch(input[[paste0("lolliformat", i)]],
                                        "VCF"={
                                          fl <- file.path(datafolder, input[[paste0("lollifile", i)]])
                                          tab <- TabixFile(fl)
                                          gen <- strsplit(input$TxDb, "\\.")[[1]]
                                          gen <- gen[length(gen)-1]
                                          vcf <- tryCatch(readVcf(fl, genome=gen, param = gr),
                                                          error = function(e){
                                                            readVcf(fl, genome=gen, param = gr.NCBI)
                                                          })
                                          mutation.frequency <- rowRanges(vcf)
                                          mcols(mutation.frequency) <- cbind(mcols(mutation.frequency), 
                                                                             VariantAnnotation::info(vcf))
                                          if(length(mutation.frequency$score)==0){
                                            mutation.frequency$score <- mutation.frequency$AF*100
                                          }
                                          mutation.frequency
                                        },
                                        "pie.stack.csv"={
                                          tab <- read.csv(file.path(datafolder, input[[paste0("lollifile", i)]]), 
                                                          stringsAsFactors = FALSE)
                                          tab.col <- SimpleList(mapply(tab$color, tab$color2, 
                                                                       FUN=function(a, b){c(a, b)}, 
                                                                       SIMPLIFY = FALSE))
                                          names(tab.col) <- tab$stack.factor
                                          mutation.frequency <- with(tab, GRanges(seqnames, IRanges(start, end), 
                                                                                  strand=strand, stack.factor=stack.factor,
                                                                                  score=score, score2=score2,
                                                                                  color=tab.col))
                                          mutation.frequency
                                        },
                                        "BED"={
                                          readBED(file.path(datafolder, input[[paste0("lollifile", i)]]), 
                                                  input[[paste0("lolliformat", i)]])
                                        },
                                        "bedGraph"={
                                          readBED(file.path(datafolder, input[[paste0("lollifile", i)]]), 
                                                  input[[paste0("lolliformat", i)]])
                                        })
           mutation.frequency <- promoters(mutation.frequency, upstream = 0, downstream = 1)
           seqlevelsStyle(mutation.frequency) <- "UCSC"
           mutation.frequency$type <- rep(input[[paste0("lollitype", i)]], length(mutation.frequency))
           thislolli <- new("track", dat=mutation.frequency, 
                            name=input[[paste0("lollisample", i)]], 
                            type="lollipopData")
           if(input[[paste0("lolliradio", i)]]!="none"){
             if(input[[paste0("lolliradio", i)]]=="default"){
               if(length(trs)>0){
                 thislolli$type <- "transcript"
                 thislolli$dat2 <- thislolli$dat
                 ## get the features granges
                 features <- unlist(GRangesList(lapply(trs, function(.e) .e$dat)))
                 lens <- sapply(trs, function(.e) length(.e$dat))
                 ## define the feature legend name
                 names(features) <- rep(names(trs), lens)
                 ## define the feature track layers
                 features$featureLayerID <- rep(seq_along(trs), lens)
                 ## define the feature colors
                 features$fill <- rep(seq_along(trs), lens)
                 ## define the feature heights
                 features$height <- ifelse(features$feature=="CDS", 0.02, 0.01)
                 thislolli$dat <- features
               }
             }else{
               thislolli$type <- "transcript"
               thislolli$dat2 <- thislolli$dat
               features <- import(file.path(datafolder, input[[paste0("lollitxfile", i)]]),
                                  format = input[[paste0("lollitxformat", i)]],
                                  which = gr)
               if(length(features$feature)<1){
                 features$feature <- "CDS"
               }
               if(length(features$featureLayerID)==0){
                 features$featureLayerID <- as.numeric(levels(features$gene))
               }
               if(length(features$transcript)>0){
                 names(features) <- make.names(features$transcript)
               }
               thislolli$dat <- features
             }
           }
           tks[[input[[paste0("lollisample", i)]]]] <- thislolli
         }
       }
     }
     trackList <- list()
     if(input$trs && length(trs)>0 && length(tks)==0){
       trackList <- trackList(trs)
     }
     if((length(trs)==0 || !input$trs) && length(tks)>=0){
       trackList <- trackList(tks)
     }
     if((length(trs)>0 && input$trs) && length(tks)>0){
       trackList <- trackList(trs, tks, heightDist = c(1, length(tks)))
     }
     
     progress$set(message="Plot data", value=0.95)
     on.exit(progress$close())
     
     if(length(trackList)>0){
       optSty <- optimizeStyle(trackList, theme="col")
       trackList <- optSty$tracks
       viewerStyle <- optSty$style
       browseTracks(trackList, gr=gr.UCSC)
     }
   })
   output$trackViewer <- plot
   
   observeEvent(input$add, {
     isolate(global$fileIndex <- global$fileIndex+1)
     currentIndex <- global$fileIndex
     isolate(global$refresh <- FALSE)
     id = paste0("filecontainer", currentIndex)
     insertUI(selector = "#add",
              where = "beforeBegin",
              ui = tags$div(tagList(
                    tags$h4("Add data track from file"),
                    selectInput(paste0("file", currentIndex), label="select file",
                                choices = dir(datafolder, "bed|bedgraph|bw|bigwig|bam", ignore.case = TRUE), multiple = FALSE),
                    selectInput(paste0("format", currentIndex), label="file format", choices = c("bedGraph"="bedGraph", "BED"="BED", "bigWig"="BigWig", "BAM"="bam")),
                    textInput(paste0("sample", currentIndex), label = "sample name", value = ""),
                    actionButton(inputId = paste0("remove", currentIndex), label="remove above track", icon = icon("remove")),
                    tags$hr()
                    ),
                    id = id)
              )
     isolate(global$fileinserted <- c(id, global$fileinserted))
     if(is.null(global$obsList[[paste0(id,"remove")]])){
       isolate(global$obsList[[paste0(id,"remove")]] <- observeEvent(input[[paste0("remove", currentIndex)]],
                                                     {
                                                       isolate(global$refresh <- FALSE)
                                                       removeUI(selector = paste0("#", id))
                                                       isolate(global$fileinserted <- 
                                                                 global$fileinserted[-which(global$fileinserted==id)])
                                                       })
                )
     }
     if(is.null(global$obsList[[paste0(id,"fileinput")]])){
       isolate(global$obsList[[paste0(id,"fileinput")]] <- 
                 observeEvent(input[[paste0("file", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("file", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", filename))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "bigwig"="BigWig", "bw"="BigWig", "bam"="bam", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("format", currentIndex),
                                                    selected =fileext )
                                }
                                filename <- sub(paste0(".", fileext, "$"), "", filename)
                                updateTextInput(session, inputId = paste0("sample", currentIndex),
                                                value = filename)
                              })
       )
     }
   })
   observeEvent(input$lolli, {
     isolate(global$lolliIndex <- global$lolliIndex+1)
     currentIndex <- global$lolliIndex
     isolate(global$refresh <- FALSE)
     id = paste0("lollicontainer", currentIndex)
     insertUI(selector = "#add",
              where = "beforeBegin",
              ui = tags$div(tagList(
                tags$h4("Add lollipop plot track from file"),
                selectInput(paste0("lollifile", currentIndex), label="select file",
                            choices = dir(datafolder, "bed|bedgraph|vcf|csv", ignore.case = TRUE), multiple = FALSE),
                selectInput(paste0("lolliformat", currentIndex), label="file format", choices = c("bedGraph"="bedGraph", "BED"="BED", "VCF"="VCF", "pieStack"="pie.stack.csv")),
                textInput(paste0("lollisample", currentIndex), label = "sample name", value = ""),
                selectInput(paste0("lollitype", currentIndex), label = "lollipop plot type", choices = c("circle", "pin", "pie", "dandelion", "pie.stack")),
                radioButtons(paste0("lolliradio", currentIndex), label = "gene model",
                             choices = c("none"="none",
                                         "use TxDb package"="default",
                                         "load from the following file"="file")),
                selectInput(paste0("lollitxfile", currentIndex), label="select transcript file",
                            choices = dir(datafolder, "bed|bedgraph|gff|gtf", ignore.case = TRUE), multiple = FALSE),
                selectInput(paste0("lollitxformat", currentIndex), label="transcript file format", choices = c("GTF", "GFF", "bedGraph", "BED")),
                actionButton(inputId = paste0("removelolli", currentIndex), label="remove above track", icon = icon("remove")),
                tags$hr()
              ), id=id
              ))
     isolate(global$lolliinserted <- c(id, global$lolliinserted))
     if(is.null(global$obsList[[paste0(id,"remove")]])){
       isolate(global$obsList[[paste0(id,"remove")]] <- observeEvent(input[[paste0("removelolli", currentIndex)]],
                                                    {
                                                      isolate(global$refresh <- FALSE)
                                                      removeUI(selector = paste0("#", id))
                                                      isolate(global$lolliinserted <- 
                                                                global$lolliinserted[-which(global$lolliinserted==id)])
                                                    })
       )
     }
     if(is.null(global$obsList[[paste0(id,"lolliinput")]])){
       isolate(global$obsList[[paste0(id,"lolliinput")]] <- 
                 observeEvent(input[[paste0("lollifile", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("lollifile", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", filename))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "vcf"="VCF", "csv"="pie.stack.csv", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("lolliformat", currentIndex),
                                                    selected =fileext )
                                }
                                filename <- sub(paste0(".", fileext, "$"), "", filename)
                                updateTextInput(session, inputId = paste0("lollisample", currentIndex),
                                                value = filename)
                                if(fileext=="pie.stack.csv"){
                                  updateSelectInput(session, inputId = paste0("lollitype", currentIndex),
                                                    selected ="pie.stack" )
                                }
                              })
       )
     }
     if(is.null(global$obsList[[paste0(id,"lollitxinput")]])){
       isolate(global$obsList[[paste0(id,"lollitxinput")]] <- 
                 observeEvent(input[[paste0("lollitxfile", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("lollitxfile", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", filename))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "gff"="GFF", "gtf"="GTF", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("lollitxformat", currentIndex),
                                                    selected =fileext )
                                }
                              })
       )
     }
   })
   
   
   observeEvent(input$addRemote, {
     isolate(global$fileIndex <- global$fileIndex+1)
     currentIndex <- global$fileIndex
     isolate(global$refresh <- FALSE)
     id = paste0("filecontainer", currentIndex)
     insertUI(selector = "#add",
              where = "beforeBegin",
              ui = tags$div(tagList(
                tags$h4("Add data track from file"),
                textInput(paste0("file", currentIndex), label="URL", value = ""),
                selectInput(paste0("format", currentIndex), label="file format", choices = c("bedGraph"="bedGraph", "BED"="BED", "bigWig"="BigWig", "BAM"="bam")),
                textInput(paste0("sample", currentIndex), label = "sample name", value = ""),
                actionButton(inputId = paste0("remove", currentIndex), label="remove above track", icon = icon("remove")),
                tags$hr()
              ),
              id = id)
     )
     isolate(global$fileinserted <- c(id, global$fileinserted))
     if(is.null(global$obsList[[paste0(id,"remove")]])){
       isolate(global$obsList[[paste0(id,"remove")]] <- observeEvent(input[[paste0("remove", currentIndex)]],
                                                                     {
                                                                       isolate(global$refresh <- FALSE)
                                                                       removeUI(selector = paste0("#", id))
                                                                       isolate(global$fileinserted <- 
                                                                                 global$fileinserted[-which(global$fileinserted==id)])
                                                                     })
       )
     }
     if(is.null(global$obsList[[paste0(id,"fileinput")]])){
       isolate(global$obsList[[paste0(id,"fileinput")]] <- 
                 observeEvent(input[[paste0("file", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("file", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", basename(filename)))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "bigwig"="BigWig", "bw"="BigWig", "bam"="bam", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("format", currentIndex),
                                                    selected =fileext )
                                }
                                filename <- sub(paste0(".", fileext, "$"), "", basename(filename))
                                updateTextInput(session, inputId = paste0("sample", currentIndex),
                                                value = filename)
                              })
       )
     }
   })
   observeEvent(input$lolliRemote, {
     isolate(global$lolliIndex <- global$lolliIndex+1)
     currentIndex <- global$lolliIndex
     isolate(global$refresh <- FALSE)
     id = paste0("lollicontainer", currentIndex)
     insertUI(selector = "#add",
              where = "beforeBegin",
              ui = tags$div(tagList(
                tags$h4("Add lollipop plot track from file"),
                textInput(paste0("lollifile", currentIndex), label="URL", value = ""),
                selectInput(paste0("lolliformat", currentIndex), label="file format", choices = c("bedGraph"="bedGraph", "BED"="BED", "VCF"="VCF", "pieStack"="pie.stack.csv")),
                textInput(paste0("lollisample", currentIndex), label = "sample name", value = ""),
                selectInput(paste0("lollitype", currentIndex), label = "lollipop plot type", choices = c("circle", "pin", "pie", "dandelion", "pie.stack")),
                radioButtons(paste0("lolliradio", currentIndex), label = "gene model",
                             choices = c("none"="none",
                                         "use TxDb package"="default",
                                         "load from the following file"="file")),
                selectInput(paste0("lollitxfile", currentIndex), label="select transcript file",
                            choices = dir(datafolder, "bed|bedgraph|gff|gtf", ignore.case = TRUE), multiple = FALSE),
                selectInput(paste0("lollitxformat", currentIndex), label="transcript file format", choices = c("GTF", "GFF", "bedGraph", "BED")),
                actionButton(inputId = paste0("removelolli", currentIndex), label="remove above track", icon = icon("remove")),
                tags$hr()
              ), id=id
              ))
     isolate(global$lolliinserted <- c(id, global$lolliinserted))
     if(is.null(global$obsList[[paste0(id,"remove")]])){
       isolate(global$obsList[[paste0(id,"remove")]] <- observeEvent(input[[paste0("removelolli", currentIndex)]],
                                                                     {
                                                                       isolate(global$refresh <- FALSE)
                                                                       removeUI(selector = paste0("#", id))
                                                                       isolate(global$lolliinserted <- 
                                                                                 global$lolliinserted[-which(global$lolliinserted==id)])
                                                                     })
       )
     }
     if(is.null(global$obsList[[paste0(id,"lolliinput")]])){
       isolate(global$obsList[[paste0(id,"lolliinput")]] <- 
                 observeEvent(input[[paste0("lollifile", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("lollifile", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", basename(filename)))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "vcf"="VCF", "csv"="pie.stack.csv", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("lolliformat", currentIndex),
                                                    selected =fileext )
                                }
                                filename <- sub(paste0(".", fileext, "$"), "", basename(filename))
                                updateTextInput(session, inputId = paste0("lollisample", currentIndex),
                                                value = filename)
                                if(fileext=="pie.stack.csv"){
                                  updateSelectInput(session, inputId = paste0("lollitype", currentIndex),
                                                    selected ="pie.stack" )
                                }
                              })
       )
     }
     if(is.null(global$obsList[[paste0(id,"lollitxinput")]])){
       isolate(global$obsList[[paste0(id,"lollitxinput")]] <- 
                 observeEvent(input[[paste0("lollitxfile", currentIndex)]],
                              {
                                isolate(global$refresh <- FALSE)
                                filename <- input[[paste0("lollitxfile", currentIndex)]]
                                filename <- sub(".gz$", "", filename, ignore.case = TRUE)
                                fileext <- tolower(sub("^.*\\.(.*?)$", "\\1", filename))
                                fileext <- switch(fileext, "bed"="BED", "bg"="bedGraph", "bedgraph"="bedGraph",
                                                  "gff"="GFF", "gtf"="GTF", "unknown")
                                if(fileext!="unknown"){
                                  updateSelectInput(session, inputId = paste0("lollitxformat", currentIndex),
                                                    selected =fileext )
                                }
                              })
       )
     }
   })
   
   
   observeEvent(input$load, {
     output$trackViewer <- 
       renderbrowseTracks({
         A=new("track", dat=GRanges(1, IRanges(c(1, 3), c(2, 4)), score=c(1, 10)), 
               type="data", format="BED")
         browseTracks(trackList(A), gr=GRanges(1, IRanges(1, 10000)))
       })
       session$sendCustomMessage(type="loadCallback", 1)
   })
   
   observeEvent(input$zoomin, {
     #isolate(global$forceRefresh <- TRUE)
     wid <- floor(abs(input$end - input$start)/5)
     if(wid>1){
       start <- min(c(input$start, input$end)) + 2*wid
       end <- max(c(input$start, input$end)) - 2*wid
       updateNumericInput(session, inputId = "start", value = start)
       updateNumericInput(session, inputId = "end", value = end)
     }
   })
   
   observeEvent(input$zoomout, {
     #isolate(global$forceRefresh <- TRUE)
     wid <- abs(input$end - input$start)
     start <- min(c(input$start, input$end)) - 2*wid
     end <- max(c(input$start, input$end)) + 2*wid
     updateNumericInput(session, inputId = "start", value = start)
     updateNumericInput(session, inputId = "end", value = end)
   })
   
   observeEvent(input$preSet1, {
     updateSelectInput(session, inputId = "TxDb", selected = "TxDb.Mmusculus.UCSC.mm8.knownGene")
     updateSelectInput(session, inputId = "org", selected = "org.Mm.eg.db")
     updateTextInput(session, inputId = "chr", value = "chr3")
     updateNumericInput(session, inputId = "start", value = 108476000)
     updateNumericInput(session, inputId = "end", value = 108485000)
   })
   observeEvent(input$preSet2, {
     updateSelectInput(session, inputId = "TxDb", selected = "TxDb.Hsapiens.UCSC.hg19.knownGene")
     updateSelectInput(session, inputId = "org", selected = "org.Hs.eg.db")
     updateTextInput(session, inputId = "chr", value = "22")
     updateNumericInput(session, inputId = "start", value = 50968014)
     updateNumericInput(session, inputId = "end", value = 50970514)
   })
   observeEvent(input$preSet3, {
     updateSelectInput(session, inputId = "TxDb", selected = "TxDb.Hsapiens.UCSC.hg38.knownGene")
     updateSelectInput(session, inputId = "org", selected = "org.Hs.eg.db")
     updateTextInput(session, inputId = "chr", value = "chr17")
     updateNumericInput(session, inputId = "start", value = 7669000)
     updateNumericInput(session, inputId = "end", value = 7677000)
   })
   observeEvent(input$preSet4, {
     updateSelectInput(session, inputId = "TxDb", selected = "TxDb.Hsapiens.UCSC.hg19.knownGene")
     updateSelectInput(session, inputId = "org", selected = "org.Hs.eg.db")
     updateTextInput(session, inputId = "chr", value = "22")
     updateNumericInput(session, inputId = "start", value = 50968014)
     updateNumericInput(session, inputId = "end", value = 50970514)
   })
   observeEvent(input$symbol, {
     isolate(global$refresh <- FALSE)
     if(input$symbol!=""){
       progress <- shiny::Progress$new()
       progress$set(message=paste("searching", input$symbol), value=0)
       require(input$TxDb, character.only = TRUE)
       require(input$org, character.only = TRUE)
       prefix <- sub(".db", "", input$org)
       eid <- tryCatch(mget(input$symbol, envir=get(paste0(prefix, "ALIAS2EG")), ifnotfound = NA),
                       error=function(e){
                         message(e)
                         return(NA)
                       })
       eid <- eid[[1]]
       progress$set(message=paste("get gene id", eid), value=50)
       if(!is.na(eid)){
         location <- tryCatch(select(get(input$TxDb), keys=eid, 
                                     columns=c("EXONCHROM", "EXONSTART", "EXONEND"), 
                                     keytype = "GENEID"), 
                              error=function(e){
                                message(e)
                                return(data.frame())
                              })
         progress$set(message="get gene location", value=90)
         if(nrow(location)>0){
           seqnames <- as.character(location$EXONCHROM)[1]
           rg <- range(c(location$EXONSTART, location$EXONEND))
           progress$set(message="set genomic loation", value=0.95)
           updateTextInput(session, inputId = "chr", value = seqnames)
           updateNumericInput(session, inputId = "start", value = rg[1])
           updateNumericInput(session, inputId = "end", value = rg[2])
         }
       }
       session$sendCustomMessage(type="scrollCallback", 1)
       on.exit(progress$close())
     }
   })
}

# Run the application 
shinyApp(ui = ui, server = server)

