##-------------------------------------------------------------------------------
## Copyright (c) 2012 University of Illinois, NCSA.
## All rights reserved. This program and the accompanying materials
## are made available under the terms of the 
## University of Illinois/NCSA Open Source License
## which accompanies this distribution, and is available at
## http://opensource.ncsa.illinois.edu/license.html
##-------------------------------------------------------------------------------
library(XML)

##--------------------------------------------------------------------------------------------------#
## EXTERNAL FUNCTIONS
##--------------------------------------------------------------------------------------------------#

##' Sanity checks. Checks the settings file to make sure expected fields exist. It will try to use
##' default values for any missing values, or stop the exection if no defaults are possible.
##'
##' Expected fields in settings file are:
##' - pfts with at least one pft defined
##' @title Check Settings
##' @param settings settings file
##' @return will return the updated settings values with defaults set.
##' @export
##' @author Rob Kooper
check.settings <- function(settings) {
  if (!is.null(settings$nocheck)) {
    logger.info("Not doing sanity checks of pecan.xml")
    return(0)
  }
  

  ## allow PEcAn to run without database
  if (is.null(settings$database)) {
    database <- FALSE
    logger.warn("No database information specified; not using database.")
    settings$bety$write <- FALSE
  } else {    
    ## check database settings
    if (is.null(settings$database$driver)) {
        settings$database$driver <- "MySQL"
      logger.info("Using", settings$database$driver, "as database driver.")
    }
        
    # Attempt to load the driver
    if (!require(paste0("R", settings$database$driver), character.only=TRUE)) {
      logger.warn("Could not load the database driver", paste0("R", settings$database$driver))
    }
    
    # MySQL specific checks
    if (settings$database$driver == "MySQL") {
      if (!is.null(settings$database$userid)) {
        logger.info("userid in database section should be username for MySQL")
        settings$database$username <- settings$database$userid
        settings$database$userid <- NULL
      }
      if (!is.null(settings$database$user)) {
        logger.info("user in database section should be username for MySQL")
        settings$database$username <- settings$database$user
        settings$database$user <- NULL
      }
      if (!is.null(settings$database$passwd)) {
        logger.info("passwd in database section should be password for MySQL")
        settings$database$password <- settings$database$passwd
        settings$database$passwd <- NULL
      }
      if (!is.null(settings$database$name)) {
        logger.info("name in database section should be dbname for MySQL")
        settings$database$dbname <- settings$database$name
        settings$database$name <- NULL
      }
    }
    
    # PostgreSQL specific checks
    if (settings$database$driver == "PostgreSQL") {
      if (!is.null(settings$database$userid)) {
        logger.info("userid in database section should be user for PostgreSQL")
        settings$database$user <- settings$database$userid
        settings$database$userid <- NULL
      }
      if (!is.null(settings$database$username)) {
        logger.info("username in database section should be user for PostgreSQL")
        settings$database$user <- settings$database$username
        settings$database$username <- NULL
      }
      if (!is.null(settings$database$passwd)) {
        logger.info("passwd in database section should be password for PostgreSQL")
        settings$database$password <- settings$database$passwd
        settings$database$passwd <- NULL
      }
      if (!is.null(settings$database$name)) {
        logger.info("name in database section should be dbname for PostgreSQL")
        settings$database$dbname <- settings$database$name
        settings$database$name <- NULL
      }
    }

    ## The following hack handles *.illinois.* to *.uiuc.* aliases of ebi-forecast
    if(!is.null(settings$database$host)){
        forcastnames <- c("ebi-forecast.igb.uiuc.edu",
                          "ebi-forecast.igb.illinois.edu") 
        if((settings$database$host %in% forcastnames) &
           (Sys.info()['nodename'] %in% forcastnames)){
            settings$database$host <- "localhost"
        }
    } else if(is.null(settings$database$host)){
        settings$database$host <- "localhost"
    }
    ## finally we can check to see if we can connect to the database
    ## but only if 
    if(is.null(settings$database$user)) {
        settings$database$user <- "bety"
    }
    if(is.null(settings$database$password)) {
        settings$database$password <- "bety"
    }
    if(is.null(settings$database$dbname)) {
        settings$database$dbname <- "bety"
    }
    if(!db.exists(settings$database)){
        logger.severe("Invalid Database Settings : ", unlist(settings$database))
    }
    logger.info("Database settings:", unlist(settings$database))
  }
  
  # should runs be written to database
  if (is.null(settings$bety$write)) {
    logger.info("Writing all runs/configurations to database.")
    settings$bety$write <- TRUE
  } else {
    settings$bety$write <- as.logical(settings$bety$write)
    if (settings$bety$write) {
      logger.debug("Writing all runs/configurations to database.")
    } else {
      logger.warn("Will not write runs/configurations to database.")
    }
  }

  # check if we can connect to the database
  if(!is.null(settings$database)){
    require(PEcAn.DB)
    if (!db.exists(params=settings$database, write=settings$bety$write)) {
      logger.info("Could not connect to the database")
      database <- FALSE
    } else {
      logger.info("Successfully connected to database")
      database <- TRUE
    }    
    
    # TODO check userid and userpassword
    
    # check database version
    if(database){
      versions <- db.query("SELECT version FROM schema_migrations WHERE version >= '20130717162614';", params=settings$database)[['version']]
      if (length(versions) == 0) {
        logger.severe("Database is out of date, please update the database.")
      }
      if (length(versions) > 1) {
        logger.warn("Database is more recent than PEcAn expects this could result in PEcAn not working as expected.",
                    "If PEcAn fails, either revert database OR update PEcAn and edit expected database version in",
                    "utils/R/read.settings.R (Redmine #1673).")
      } else {
        logger.debug("Database is correct version", versions[1], ".")
      }
    }
  }
  
  # make sure there are pfts defined
  if (is.null(settings$pfts) || (length(settings$pfts) == 0)) {
    logger.severe("No PFTS specified.")
  }

  # check for a run settings
  if (is.null(settings[['run']])) {
    logger.severe("No Run Settings specified")
  }

  # check start/end date are specified and correct
  if (is.null(settings$run$start.date)) {
    logger.severe("No start.date specified in run section.")
  }
  if (is.null(settings$run$end.date)) {
    logger.severe("No end.date specified in run section.")
  }
  startdate <- parse_date_time(settings$run$start.date, "ymd_hms", truncated=3)
  enddate <- parse_date_time(settings$run$end.date, "ymd_hms", truncated=3)
  if (startdate >= enddate) {
    logger.severe("Start date should come before the end date.")
  }

  # check if there is either ensemble or sensitivy.analysis
  if (is.null(settings$ensemble) && is.null(settings$sensitivity.analysis)) {
    logger.warn("No ensemble or sensitivity analysis specified, no models will be executed!")
  }

  # check ensemble
  if (!is.null(settings$ensemble)) {
    if (is.null(settings$ensemble$variable)) {
      if (is.null(settings$sensitivity.analysis$variable)) {
        logger.severe("No variable specified to compute ensemble for.")
      }
      logger.info("Setting ensemble variable to the same as sensitivity analysis variable [", settings$sensitivity.analysis$variable, "]")
      settings$ensemble$variable <- settings$sensitivity.analysis$variable
    }

    if (is.null(settings$ensemble$size)) {
      logger.info("Setting ensemble size to 1.")
      settings$ensemble$size <- 1
    }

    if(is.null(settings$ensemble$start.year)) {
      if(is.null(settings$sensitivity.analysis$start.year)) {
        settings$ensemble$start.year <- year(settings$run$start.date) 
        logger.info("No start date passed to ensemble - using the run date (", settings$ensemble$start.date, ").")
      } else { 
        settings$ensemble$start.year <- settings$sensitivity.analysis$start.year 
        logger.info("No start date passed to ensemble - using the sensitivity.analysis date (", settings$ensemble$start.date, ").")
      }
    }

    if(is.null(settings$ensemble$end.year)) {
      if(is.null(settings$sensitivity.analysis$end.year)) {
        settings$ensemble$end.year <- year(settings$run$end.date) 
        logger.info("No end date passed to ensemble - using the run date (", settings$ensemble$end.date, ").")
      } else { 
        settings$ensemble$end.year <- settings$sensitivity.analysis$end.year 
        logger.info("No end date passed to ensemble - using the sensitivity.analysis date (", settings$ensemble$end.date, ").")
      }
    }

    # check start and end dates
    if (year(startdate) > settings$ensemble$start.year) {
      logger.severe("Start year of ensemble should come after the start.date of the run")
    }
    if (year(enddate) < settings$ensemble$end.year) {
      logger.severe("End year of ensemble should come before the end.date of the run")
    }
    if (settings$ensemble$start.year > settings$ensemble$end.year) {
      logger.severe("Start year of ensemble should come before the end year of the ensemble")
    }
  }

  # check sensitivity analysis
  if (!is.null(settings$sensitivity.analysis)) {
    if (is.null(settings$sensitivity.analysis$variable)) {
      if (is.null(settings$ensemble$variable)) {
        logger.severe("No variable specified to compute sensitivity.analysis for.")
      }
      logger.info("Setting sensitivity.analysis variable to the same as ensemble variable [", settings$ensemble$variable, "]")
      settings$sensitivity.analysis$variable <- settings$ensemble$variable
    }

    if(is.null(settings$sensitivity.analysis$start.year)) {
      if(is.null(settings$ensemble$start.year)) {
        settings$sensitivity.analysis$start.year <- year(settings$run$start.date) 
        logger.info("No start date passed to sensitivity.analysis - using the run date (", settings$sensitivity.analysis$start.date, ").")
      } else { 
        settings$sensitivity.analysis$start.year <- settings$ensemble$start.year 
        logger.info("No start date passed to sensitivity.analysis - using the ensemble date (", settings$sensitivity.analysis$start.date, ").")
      }
    }

    if(is.null(settings$sensitivity.analysis$end.year)) {
      if(is.null(settings$ensemble$end.year)) {
        settings$sensitivity.analysis$end.year <- year(settings$run$end.date) 
        logger.info("No end date passed to sensitivity.analysis - using the run date (", settings$sensitivity.analysis$end.date, ").")
      } else { 
        settings$sensitivity.analysis$end.year <- settings$ensemble$end.year 
        logger.info("No end date passed to sensitivity.analysis - using the ensemble date (", settings$sensitivity.analysis$end.date, ").")
      }
    }

    # check start and end dates
    if (year(startdate) > settings$sensitivity.analysis$start.year) {
      logger.severe("Start year of sensitivity.analysis should come after the start.date of the run")
    }
    if (year(enddate) < settings$sensitivity.analysis$end.year) {
      logger.severe("End year of sensitivity.analysis should come before the end.date of the run")
    }
    if (settings$sensitivity.analysis$start.year > settings$sensitivity.analysis$end.year) {
      logger.severe("Start year of sensitivity.analysis should come before the end year of the ensemble")
    }
  }

  # check meta-analysis
  if (is.null(settings$meta.analysis) || is.null(settings$meta.analysis$iter)) {
    settings$meta.analysis$iter <- 3000
    logger.info("Setting meta.analysis iterations to ", settings$meta.analysis$iter)
  }
  if (is.null(settings$meta.analysis$random.effects)) {
    settings$meta.analysis$random.effects <- FALSE
    logger.info("Setting meta.analysis random effects to ", settings$meta.analysis$random.effects)
  }
  if (is.null(settings$meta.analysis$update)) {
    settings$meta.analysis$update <- FALSE
    logger.info("Setting meta.analysis update to only update if no previous meta analysis was found")
  }
  if (settings$meta.analysis$update == 'AUTO') {
    logger.info("meta.analysis update AUTO is not implemented yet, defaulting to FALSE")
    settings$meta.analysis$update <- FALSE
  }
  if ((settings$meta.analysis$update != 'AUTO') && is.na(as.logical(settings$meta.analysis$update))) {
    logger.info("meta.analysis update can only be AUTO/TRUE/FALSE, defaulting to FALSE")
    settings$meta.analysis$update <- FALSE
  }

  # check modelid with values
  if(!is.null(settings$model)){
    if (is.null(settings$model$id)) {
      if(database){
        if(!is.null(settings$model$id)){
          if(as.numeric(settings$model$id) >= 0){
            model <- db.query(paste("SELECT * FROM models WHERE id =", settings$model$id), params=settings$database)
            if(nrow(model) == 0) {
              logger.error("There is no record of model_id = ", settings$model$id, "in database")
            }
          }
        } else if (!is.null(settings$model$name)) {
          model <- db.query(paste0("SELECT * FROM models WHERE model_name = '", settings$model$name,
                                   "' or model_type = '", toupper(settings$model$name), "'",
                                   " and model_path like '%", 
                                   ifelse(settings$run$host$name == "localhost", Sys.info()[['nodename']], 
                                          settings$run$host$name), "%' ",
                                   ifelse(is.null(settings$model$revision), "", 
                                          paste0(" and revision like '%", settings$model$revision, "%' "))), 
                            params=settings$database)
          if(nrow(model) > 1){
            logger.warn("multiple records for", settings$model$name, "returned; using the most recent")
            model <- model[which.max(ymd_hms(model$updated_at)), ]
          } else if (nrow(model) == 0) {
            logger.warn("Model", settings$model$name, "not in database")
          }
        } else if(database && is.null(settings$model$id) && is.null(settings$model$name)) {
          logger.severe("no model settings given")
        }
      }
      if (!is.null(settings$model$name)) {
        model$model_type=settings$model$name
      }
      if (!is.null(settings$model$name)) {
        model$model_path=paste0("hostname:", settings$model$binary)
      }
      if (!is.null(model$model_path)) {
        model$binary <- tail(strsplit(model$model_path, ":")[[1]], 1)        
      }
      
      if (is.null(settings$model$name)) {
        if ((is.null(model$model_type) || model$model_type == "")) {
          logger.severe("No model type specified.")
        }
        settings$model$name <- model$model_type
        logger.info("Setting model type to ", settings$model$name)
      } else if (model$model_type != settings$model$name) {
        logger.warn("Specified model type [", settings$model$name, "] does not match model_type in database [", model$model_type, "]")
      }
      
      if (is.null(settings$model$binary)) {
        if ((is.null(model$binary) || model$binary == "")) {
          logger.severe("No model binary specified.")
        }
        settings$model$binary <- tail(strsplit(model$binary, ":")[[1]], 1)
        logger.info("Setting model binary to ", settings$model$binary)
      } else if (model$binary != settings$model$binary) {
        logger.warn("Specified binary [", settings$model$binary, "] does not match model_path in database [", model$binary, "]")
      }
    }
  }
  
  # check siteid with values
  if(!is.null(settings$run$site)){
    if (is.null(settings$run$site$id)) {
      settings$run$site$id <- -1
    } else if (settings$run$site$id >= 0) {
      if (database) {
        site <- db.query(paste("SELECT * FROM sites WHERE id =", settings$run$site$id), params=settings$database);
      } else {
        site <- data.frame(id=settings$run$site$id)
        if (!is.null(settings$run$site$name)) {
          site$sitename=settings$run$site$name
        }
        if (!is.null(settings$run$site$lat)) {
          site$lat=settings$run$site$lat
        }
        if (!is.null(settings$run$site$lon)) {
          site$lon=settings$run$site$lon
        }
      }
      if((!is.null(settings$run$site$met)) && settings$run$site$met == "NULL") settings$run$site$met <- NULL
      if (is.null(settings$run$site$name)) {
        if ((is.null(site$sitename) || site$sitename == "")) {
          logger.info("No site name specified.")
          settings$run$site$name <- "NA"
        } else {
          settings$run$site$name <- site$sitename        
          logger.info("Setting site name to ", settings$run$site$name)
        }
      } else if (site$sitename != settings$run$site$name) {
        logger.warn("Specified site name [", settings$run$site$name, "] does not match sitename in database [", site$sitename, "]")
      }

      if (is.null(settings$run$site$lat)) {
        if ((is.null(site$lat) || site$lat == "")) {
          logger.severe("No lat specified for site.")
        } else {
          settings$run$site$lat <- as.numeric(site$lat)
          logger.info("Setting site lat to ", settings$run$site$lat)
        }
      } else if (as.numeric(site$lat) != as.numeric(settings$run$site$lat)) {
        logger.warn("Specified site lat [", settings$run$site$lat, "] does not match lat in database [", site$lat, "]")
      }

      if (is.null(settings$run$site$lon)) {
        if ((is.null(site$lon) || site$lon == "")) {
          logger.severe("No lon specified for site.")
        } else {
          settings$run$site$lon <- as.numeric(site$lon)
          logger.info("Setting site lon to ", settings$run$site$lon)
        }
      } else if (as.numeric(site$lon) != as.numeric(settings$run$site$lon)) {
        logger.warn("Specified site lon [", settings$run$site$lon, "] does not match lon in database [", site$lon, "]")
      }
    }
  }

  # check to make sure a host is given
  if (is.null(settings$run$host$name)) {
    logger.info("Setting localhost for execution host.")
    settings$run$host$name <- "localhost"
  }
  ## if run$host is localhost, set to "localhost
  if (any(settings$run$host %in% c(Sys.info()['nodename'], gsub("illinois", "uiuc", Sys.info()['nodename'])))){
    settings$run$host <- "localhost"
  }

  # check if we need to use qsub
  if ("qsub" %in% names(settings$run$host)) {
    if (is.null(settings$run$host$qsub)) {
      settings$run$host$qsub <- "qsub -N @NAME@ -o @STDOUT@ -e @STDERR@ -S /bin/bash"
      logger.info("qsub not specified using default value :", settings$run$host$qsub)
    }
    if (is.null(settings$run$host$qsub.jobid)) {
      settings$run$host$qsub.jobid <- "Your job ([0-9]+) .*"
      logger.info("qsub.jobid not specified using default value :", settings$run$host$qsub.jobid)
    }
    if (is.null(settings$run$host$qstat)) {
      settings$run$host$qstat <- "qstat -j @JOBID@ &> /dev/null || echo DONE"
      logger.info("qstat not specified using default value :", settings$run$host$qstat)
    }
  }

  # modellauncher to launch on multiple nodes/cores
  if ("modellauncher" %in% names(settings$run$host)) {
    if (is.null(settings$run$host$modellauncher$binary)) {
      settings$run$host$modellauncher$binary <- "modellauncher"
      logger.info("binary not specified using default value :", settings$run$host$modellauncher$binary)
    }
    if (is.null(settings$run$host$modellauncher$qsub.extra)) {
      logger.severe("qsub.extra not specified, can not launch in parallel environment.")
    }
    if (is.null(settings$run$host$modellauncher$mpirun)) {
      settings$run$host$modellauncher$mpirun <- "mpirun"
      logger.info("mpirun not specified using default value :", settings$run$host$modellauncher$mpirun)
    }
  }

  # Check folder where outputs are written before adding to dbfiles
  if(is.null(settings$run$dbfiles)) {
    settings$run$dbfiles <- normalizePath("~/.pecan/dbfiles", mustWork=FALSE)
  } else {
    settings$run$dbfiles <- normalizePath(settings$run$dbfiles, mustWork=FALSE)
  }
  dir.create(settings$run$dbfiles, showWarnings = FALSE, recursive = TRUE)

  # check/create the pecan folder
  if (is.null(settings$outdir)) {
    settings$outdir <- tempdir()
  }
  if (substr(settings$outdir, 1, 1) != '/') {
    settings$outdir <- file.path(getwd(), settings$outdir)
  }
  logger.debug("output folder =", settings$outdir)
  if (!file.exists(settings$outdir) && !dir.create(settings$outdir, recursive=TRUE)) {
    logger.severe("Could not create folder", settings$outdir)
  }

  # check/create the local run folder
  if (is.null(settings$rundir)) {
    settings$rundir <- file.path(settings$outdir, "run")
  }
  if (!file.exists(settings$rundir) && !dir.create(settings$rundir, recursive=TRUE)) {
    logger.severe("Could not create run folder", settings$rundir)
  }

  # check/create the local model out folder
  if (is.null(settings$modeloutdir)) {
    settings$modeloutdir <- file.path(settings$outdir, "out")
  }
  if (!file.exists(settings$modeloutdir) && !dir.create(settings$modeloutdir, recursive=TRUE)) {
    logger.severe("Could not create model out folder", settings$modeloutdir)
  }
  
  # make sure remote folders are specified if need be
  if (!is.null(settings$run$host$qsub) && (settings$run$host$name != "localhost")) {
    if (is.null(settings$run$host$rundir)) {
      logger.severe("Need to have specified a folder where PEcAn will write run information for job.")
    }
    if (is.null(settings$run$host$outdir)) {
      logger.severe("Need to have specified a folder where PEcAn will write output of job.")
    }
  } else if (settings$run$host$name == "localhost") {
    settings$run$host$rundir <- settings$rundir
    settings$run$host$outdir <- settings$modeloutdir
  }

  # check/create the pft folders
  for (i in 1:sum(names(unlist(settings$pfts)) == "pft.name")) {
    if (is.null(settings$pfts[i]$pft$outdir)) {
      settings$pfts[i]$pft$outdir <- file.path(settings$outdir, "pft", settings$pfts[i]$pft$name)
      logger.info("Storing pft", settings$pfts[i]$pft$name, "in", settings$pfts[i]$pft$outdir)      
    } else {
      logger.debug("Storing pft", settings$pfts[i]$pft$name, "in", settings$pfts[i]$pft$outdir)      
    }
    out.dir <- settings$pfts[i]$pft$outdir
    if (!file.exists(out.dir) && !dir.create(out.dir, recursive=TRUE)) {
      if(identical(dir(out.dir), character(0))){
        logger.warn(out.dir, "exists but is empty")
      } else {
        logger.severe("Could not create folder", out.dir)        
      }
    }
  }

  # check for workflow defaults
  if(database){
    if (settings$bety$write) {
      if ("model" %in% names(settings) && !'workflow' %in% names(settings)) {
        con <- db.open(settings$database)
        if(!is.character(con)){
          now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
          db.query(paste("INSERT INTO workflows (site_id, model_id, hostname, start_date, end_date, started_at, created_at, folder) values ('",
                         settings$run$site$id, "','", settings$model$id, "', '", settings$run$host$name, "', '",
                         settings$run$start.date, "', '", settings$run$end.date, "', '", now, "', '", now, "', '", dirname(settings$outdir), "')", sep=''), con)
          settings$workflow$id <- db.query(paste("SELECT id FROM workflows WHERE created_at='", now, "';", sep=''), con)[['id']]
          db.close(con)
        }
      }
    } else {
      settings$workflow$id <- "NA"
    }
  } else {
    settings$workflow$id <- "NA"
  }

  # all done return cleaned up settings
  invisible(settings)
}


##' Loads PEcAn settings file
##' 
##' This will try and find the PEcAn settings file in the following order:
##' \enumerate{
##' \item {--settings <file>}{passed as command line argument using --settings}
##' \item {inputfile}{passed as argument to function}
##' \item {PECAN_SETTINGS}{environment variable PECAN_SETTINGS pointing to a specific file}
##' \item {./pecan.xml}{pecan.xml in the current folder}
##' }
##' Once the function finds a valid file, it will not look further. 
##' Thus, if \code{inputfile} is supplied, \code{PECAN_SETTINGS} will be ignored. 
##' Even if a \code{file} argument is passed, it will be ignored if a file is passed through
##' a higher priority method.  
##' @param inputfile the PEcAn settings file to be used.
##' @param outputfile the name of file to which the settings will be
##'        written inside the outputdir.
##' @return list of all settings as loaded from the XML file(s)
##' @export
##' @import XML
##' @author Shawn Serbin
##' @author Rob Kooper
##' @examples
##' \dontrun{
##' ## bash shell:
##' R --vanilla -- --settings path/to/mypecan.xml < workflow.R 
##' 
##' ## R:
##' 
##' settings <- read.settings()
##' settings <- read.settings(file="willowcreek.xml")
##' test.settings.file <- system.file("tests/test.xml", package = "PEcAn.all")
##' settings <- read.settings(test.settings.file)
##' }
read.settings <- function(inputfile = NULL, outputfile = "pecan.xml"){
  if (is.null(outputfile)) {
    outputfile <- "pecan.xml"
  }
  if(inputfile == ""){
    logger.warn("settings files specified as empty string; \n\t\tthis may be caused by an incorrect argument to system.file.")
  }
  loc <- which(commandArgs() == "--settings")
  if (length(loc) != 0) {
    # 1 filename is passed as argument to R
    for(idx in loc) {
      if (!is.null(commandArgs()[idx+1]) && file.exists(commandArgs()[idx+1])) {
        logger.info("Loading --settings=", commandArgs()[idx+1])
        xml <- xmlParse(commandArgs()[idx+1])
        break
      }
    }
    if (!is.null(inputfile)){
      logger.info("input file ", inputfile, "not used, ", loc, "as environment variable")
    } 

  } else if(!is.null(inputfile) && file.exists(inputfile)) {
    # 2 filename passed into function
    logger.info("Loading inpufile=", inputfile)
    xml <- xmlParse(inputfile)

  } else if (file.exists(Sys.getenv("PECAN_SETTINGS"))) {
    # 3 load from PECAN_SETTINGS
    logger.info("Loading PECAN_SETTINGS=", Sys.getenv("PECAN_SETTINGS"))
    xml <- xmlParse(Sys.getenv("PECAN_SETTINGS"))

  } else if (file.exists("pecan.xml")) {
    # 4 load ./pecan.xml
    logger.info("Loading ./pecan.xml")
    xml <- xmlParse("pecan.xml")

  } else {
    # file not found
    stop("Could not find a pecan.xml file")
  }

  ## convert the xml to a list for ease and return
  settings <- check.settings(xmlToList(xml))
  
  ## save the checked/fixed pecan.xml
  pecanfile <- file.path(settings$outdir, outputfile)
  if (file.exists(pecanfile)) {
    logger.warn(paste("File already exists [", pecanfile, "] file will be overwritten"))
  }
  saveXML(listToXml(settings, "pecan"), file=pecanfile)

  ## setup Rlib from settings
  if(!is.null(settings$Rlib)){
    .libPaths(settings$Rlib)
  }

  ## Return settings file as a list
  invisible(settings)
}
##=================================================================================================#

####################################################################################################
### EOF.  End of R script file.  						
####################################################################################################
