#-------------------------------------------------------------------------------
# Copyright (c) 2012 University of Illinois, NCSA.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the 
# University of Illinois/NCSA Open Source License
# which accompanies this distribution, and is available at
# http://opensource.ncsa.illinois.edu/license.html
#-------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------#
##'
##' This function retrieves model output for further analyses
##' @name get.model.output
##' @title Retrieve model output
##'
##' @param model the ecosystem model run
##'
##' @export
##' 
##' @examples
##' \dontrun{
##' get.model.output(model)
##' get.model.output("ED2")
##' }
##'
##' @author Michael Dietze, Shawn Serbin, David LeBauer
get.model.output <- function(model, settings){
  load.modelpkg(model)
  logger.info("Same as get.results(settings)")
  get.results(settings)
  return()
}
####################################################################################################
### EOF.  End of R script file.            	
####################################################################################################
