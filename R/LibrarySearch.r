


# Libraries that must be installed:
#library(dplyr)
#library(RSQLite)
#library(DBI)
#library(MALDIquant)

# output:

# A three-column tibble with columns:

#"unknownStrainIDs" "librarySpectrum" "score"


# unknown librarySpectrum        score
# 1  114A-1          114C-6 1.560207e-01
# 2  114A-2          114A-2 2.220446e-16



databaseSearch <- function(idbacPath, databasePath){

# Inputs:
  # idbacPath     == idbacDirectory$filePath
  # databasePath  == input$selectedSearchLibrary        #.sqlite database path

# Returns:
  # Returns list of top hit matches. Each list element is one unknown sample, with one best cosine similarity score + lib sample ID


# This function processes library spectra, one at a time (to save RAM)
# read SQLite, bin and filter percent presence based on user input
# return single MALDIquant object of protein peaks
libraryProcessing <-  function(singleLibSpec){

  # Return the "rds" SQL blob for the individual strain
  libProteinPeaks <-  libSpec %>%
    filter(Strain_ID == singleLibSpec) %>%
    select(rds) %>%
    collect()
  #Decompress blob
  libProteinPeaks <- memDecompress(libProteinPeaks[[1]][[1]], type="gzip")
  # Unserialize blob
  libProteinPeaks <- unserialize(libProteinPeaks, NULL)
  # Unlist rds file list
  libProteinPeaks <- unlist(libProteinPeaks, recursive = TRUE)
  # Return only protein peak MALDIquant objects
  libProteinPeaks <- libProteinPeaks[grep("ProteinPeaks", names(libProteinPeaks))]

  # Get sample IDs contained in the metadata *within* the rds MALDIquant protein peaks object
  labs <- sapply(libProteinPeaks, function(x)metaData(x)$Strain)
  # Change to facter
  labs <- factor(labs)
  # Setup for-loop
  new2 <- NULL
  newPeaks <- NULL
  # If libProteinPeaks contains more than one sample ID (it shouldn't), make sure to bin and
  # filter peaks only within the sample sample
  for (i in seq_along(levels(labs))) {
    specSubset <- (which(labs == levels(labs)[[i]]))
    if (length(specSubset) > 1) { # ie if there is > 1 protein spectrum (replicate)
      libProteinPeaks <- MALDIquant::trim(libProteinPeaks, c(3000,15000))
      # See here for info on "tolerance" value
      # https://github.com/sgibb/MALDIquant/issues/56#issuecomment-388133351
      libProteinPeaks <- MALDIquant::binPeaks(libProteinPeaks, tolerance = .002, method = "relaxed")
      new <- filterPeaks(libProteinPeaks[specSubset], minFrequency= 0/100)
      new <- mergeMassPeaks(new, method="mean")
      new2 <- c(new2, new)
    } else{ # If there is only one spectrum
      new2 <- c(new2, libProteinPeaks[specSubset])
    }

  }
  libProteinPeaks <- new2

}


# This function processes unknown spectra, one at a time (to save RAM)
# read rds protein peaks file (so we can bin against library spectrum later), bin and filter percent presence based on user input
# return single MALDIquant object of protein peaks
unknownProcessing <-  function(singleSpec){


  unknownSpectrum <- unlist(strsplit(basename(unknownProteinPeakFiles), "_ProteinPeaks.rds"))

  unknownSpectrum <- readRDS(unknownProteinPeakFiles[which(unknownSpectrum == singleSpec)])

  labs <- sapply(unknownSpectrum, function(x)metaData(x)$Strain)
  labs <- factor(labs)
  new2 <- NULL
  newPeaks <- NULL
  for (i in seq_along(levels(labs))) {
    specSubset <- (which(labs == levels(labs)[[i]]))
    if (length(specSubset) > 1) {
      unknownSpectrum <- MALDIquant::trim(unknownSpectrum, c(3000,15000))
      unknownSpectrum <- MALDIquant::binPeaks(unknownSpectrum, tolerance = .002, method = "relaxed")
      new <- filterPeaks(unknownSpectrum[specSubset],minFrequency= 0/100)
      new<-mergeMassPeaks(new,method="mean")
      new2 <- c(new2, new)
    } else{
      new2 <- c(new2, unknownSpectrum[specSubset])
    }

  }
  unknownSpectrum <- new2

}



# This is the workhorse of the searching.
# Takes a list of unknown *Sample IDs* as input

searchLibrary<- function(unk){

  # Use Cosine Similarity to determine spectra similarity (Note: 0 is close, 1 is not close)
  cosineD <- function(x) {
    as.dist(1 - x%*%t(x)/(sqrt(rowSums(x^2) %*% t(rowSums(x^2)))))
  }
  # Process single unknown sample spectrum
  unk1 <- unknownProcessing(unk)
  # Perform cosine similarity search across all library spectra
  qq <-lapply(libStrainIDs, function(lib){
    # Process single library strain
    lib1 <- libraryProcessing(lib)
    # Bin one unknown and one library spectra (strict = one peak per bin)
    a <- MALDIquant::binPeaks(c(lib1[[1]], unk1[[1]]), tolerance = 0.02, method = "strict")
    # Turn into a matrix, rows = samples, columns = binned peaks, cells = peak intensity
    b <- MALDIquant::intensityMatrix(a)
    # Get sample names of the two spectra
    rownames(b) <- sapply(a, function(x) x@metaData$Strain)
    # Replace NA values with 0
    b[is.na(b)] <- 0
    # Perform cosine similarity function
    cosineD(b)
  })
  # This collects all lib search results for one unknown spectrum and turn in a tbl
  # Colums: "spec" = library sample ID, "score" = cosine similarity score
  match <- dplyr::bind_cols(librarySpectrum=sapply(qq, function(x) labels(x)[[1]]), score= unlist(qq))
  # Return only the closest library match
  match %>% na.omit %>% filter(score == min(score))

}

# Get "Unknown" strain protein peak files
unknownProteinPeakFiles <- list.files(paste0(idbacPath, "\\Peak_Lists"),full.names = TRUE, pattern = "ProteinPeaks.rds")


# connect to user-specified database
dbcon <- DBI::dbConnect(RSQLite::SQLite(), databasePath)

# Connect dplyr to database
db <- dplyr::tbl(dbcon, "IDBacDatabase")

# Filter database by whatever metadata
# Return only rds column and strain ID
libSpec <- db %>%
  #filter(Strain_ID == "114A-2") %>%
  dplyr::select(c(Strain_ID,rds))

# Finds the number of rows in the currently-loaded databsase
lengthLibSpecs <- libSpec %>%
  dplyr::summarize(n()) %>%
  dplyr::collect() %>%
  as.numeric()



# Get unknown sample IDs based on the rds file
unknownStrainIDs <- unlist(strsplit(basename(unknownProteinPeakFiles), "_ProteinPeaks.rds"))


# Note: cannot "slice()" or select by index within SQL table, so will just
# filter by strain ID
libStrainIDs <- libSpec %>%
  select(Strain_ID) %>%
  collect() %>%
  unlist() %>%
  as.vector()

# Run the library search. Inputs: "unknownStrainIDs" ; "searchLibrary" = function
# Returns list of top hit matches. Each list element = 1 unknown sample, with 1 best cosine similarity score = lib sample ID
 allScores <- lapply(unknownStrainIDs, searchLibrary)

 allScores <- do.call(rbind, allScores)
 cbind(unknown = unknownStrainIDs, allScores)
 }
