
if(!length(grep("mzR",row.names(installed.packages())))){
  if(!length(grep("BiocInstaller",row.names(installed.packages())))){
    source("https://bioconductor.org/biocLite.R")
    biocLite("BiocInstaller",suppressUpdates = T)
    }

  source("https://bioconductor.org/biocLite.R")
  biocLite("mzR",ask=F)
}


# Function to Install and Load R Packages
Install_And_Load <- function(Required_Packages)
{
  Remaining_Packages <-
    Required_Packages[!(Required_Packages %in% installed.packages()[, "Package"])]


  if (length(Remaining_Packages))
  {
    install.packages(Remaining_Packages)

  }
  for (package_name in Required_Packages)
  {
    library(package_name,
            character.only = TRUE,
            quietly = TRUE)

  }
}

# Required packages to install and load
Required_Packages = c("devtools","svglite","shinyjs", "mzR","plotly","colourpicker","shiny", "MALDIquant", "MALDIquantForeign","readxl","networkD3","ape","FactoMineR","dendextend","networkD3","reshape2","plyr","igraph")


# Install and Load Packages
Install_And_Load(Required_Packages)


# The UI section of the Shiny app provides the "User Interface" and is the means of user interaction.
# "h3", "p", and "br" are HTML,the other lines setup the different panels, tabs, plots, etc of the user interface.
navbarPage(
  "IDBac",
  tabPanel(
    "Introduction",
    fluidPage(
      shinyjs::useShinyjs(),

      fluidRow(
        column(3,
               br(),
               div(img(src="IDBac_Computer_SVG_300DPI.png",style="width:75%;height:75%"))),
        column(8,
               h1("Welcome to IDBac",align="center"),
               br(),
               h4("General Information:"),

               tags$ul(
                  tags$li(
                     p("For more information about the method, as well as links to the full code, please visit ", a(href="https://chasemc.github.io/IDBac/", target="_blank", "chasemc.github.io/IDBac"))
                  ),
                  tags$li(
                     p("Bugs and suggestions may be reported on the ", a(href="https://github.com/chasemc/IDBac_app/issues",target="_blank","IDBac Issues Page on GitHub.", img(border="0", title="https://github.com/chasemc/IDBac_app/issues", src="GitHub.png", width="25" ,height="25")))
                  ),
                  tags$li(  actionButton("updateIDBac", label = "Check for Updates"))

                 ),

              br(),
              h4("How to Cite IDBac:"),

              tags$ul(
                 tags$li(
                    p("Publication:")
                 ),
                 tags$ul(
                    tags$li(
                       p(tags$i("Coupling MALDI-TOF mass spectrometry protein and specialized metabolite analyses to rapidly discriminate bacterial function"),br(),
                       "Chase M. Clark, Maria S. Costa, Laura M. Sanchez, Brian T. Murphy;
                          bioRxiv 215350; doi: https://doi.org/10.1101/215350")
                    )
                 )
               ),
              tags$ul(
                tags$li(
                  p("Software:")
                ),
                tags$ul(
                  tags$li(
                    p("For reproducibility, cite this version of IDBac with the version DOI: \"10.5281/zenodo.1145465\"")
                    ),
                  tags$li(
                    p("Past versions of IDBac can be found here:",a(href="https://doi.org/10.5281/zenodo.1145465",img(src="https://zenodo.org/badge/DOI/10.5281/zenodo.1145465.svg"),target="_blank") )
                  )
                )
              ),

              br(),

              h4("Select \"PreProcessing\" above to begin")

  )))),
  tabPanel(
    "PreProcessing",
    fluidPage(
      fluidRow(

        column(width=3,
        radioButtons("startingWith", label = h3("Begin by selecting an option below:"),
                     choices = list("Starting with raw data files" = 1,
                                    "Starting with peak list files (.txt or .csv)" = 2,
                                    "Re-analyzing data alrerady processed with IDBac" = 3),selected=0,inline=FALSE,width="100%")),
        column(width=1,
          uiOutput("arrowPNG")),
        column(width=4,

        uiOutput("startingWithUI"))



      ),
          fluidRow(  uiOutput("ui1"))
    )),

    tabPanel("Compare Two Samples (Protein)",
           uiOutput("inversepeakui")),
  tabPanel("Hierarchical Clustering (Protein)",
           uiOutput("Heirarchicalui")),
  tabPanel("PCA (Protein)",
           uiOutput("PCAui")),
  tabPanel("Metabolite Association Network (Small-Molecule)",
           uiOutput("MANui"))

)
