#' Obtain time to and from sunrise/sunset for a dataframe containing POSIXct times
#'
#' Creates and adds columns for time to, and time from sunrise/sunset based on a column of POSIXct dates/times
#' dataframe must contain latitude, longitude, and a date/time variable
#'
#' @param data a selected table from .motus data, eg. "alltags", or a data.frame of detection data 
#' including at a minimum variables for date/time, latitude, and longitude
#' @param lat variable with latitude values, defaults to recvDeployLat
#' @param lon variable with longitude values, defaults to recvDeployLon
#' @param ts variable with time in UTC as numeric or POSIXct, defaults to ts
#' @param units units to display time difference, defaults to "hours", options include "secs", "mins", "hours", "days", "weeks"
#'
#' @export
#'
#' @author Zoe Crysler \email{zcrysler@@gmail.com}
#'
#' @return the original dataframe provided, with the following additional columns:
#' \itemize{
#' \item sunrise: sunrise time for the date and location provided by ts and recvDeployLat/recvDeployLon per row
#' \item sunset: sunset time for the date and location provided by ts and recvDeployLat/recvDeployLon per row
#' \item ts_to_set: time to next sunset after "ts", units default to "hours"
#' \item ts_since_set: time to previous sunset since "ts", units default to "hours"
#' \item ts_to_rise: time to next sunrise after "ts", units default to "hours"
#' \item ts_since_rise: time to previous sunrise since "ts", units default to "hours"
#' }
#'
#' @examples
#' You can use either a selected tbl from .motus eg. "alltags", or a data.frame, instructions to convert a .motus file to all formats are below.
#' sql.motus <- tagme(176, new = TRUE, update = TRUE) # download and access data from project 176 in sql format
#' tbl.alltags <- tbl(sql.motus, "alltags") # convert sql file "sql.motus" to a tbl called "tbl.alltags"
#' df.alltags <- tbl.alltags %>% collect %>% as.data.frame() ## convert the tbl "tbl.alltags" to a data.frame called "df.alltags"
#' 
#' get sunrise and sunset information with units in minutes using tbl file tbl.alltags
#' sunrise <- timeToSunriset(tbl.alltags, units = "mins")
#' 
#' get sunrise and sunset information with units in hours using gps lat/lon using data.frame df.alltags
#' sunrise <- timeToSunriset(df.alltags, lat = "gpsLat", lon = "gpsLon")

timeToSunriset <- function(data, lat = "recvDeployLat", lon = "recvDeployLon", ts = "ts", units = "hours"){
  data <- data %>% collect %>% as.data.frame
  data$ts <- as_datetime(data$ts, tz = "UTC")
  cols <- c(lat, lon, ts) ## Select columns that can't contain NA values
  loc_na <- data[!complete.cases(data[cols]),] ## new dataframe with NA values in lat, lon, or ts
  loc <- data[complete.cases(data[cols]),] ## new dataframe with no NA values in lat, lon, or ts
  loc$sunrise <- maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)),loc$ts, POSIXct.out=T, direction='sunrise')$time
  loc$sunset <- maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)),loc$ts, POSIXct.out=T, direction='sunset')$time
  ## to get time difference, must take into account whether you are going to/from sunrise/sunset from the
  ## previous or next day, this depends on when the detection was in relation to sunrise/sunset times for that day.
  loc$ts_to_set <- ifelse(loc$ts < loc$sunset, difftime(loc$sunset, loc$ts, units = units),
                          difftime(maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)), (loc$ts + 86400), POSIXct.out=T, direction='sunset')$time, loc$ts, units = units))
  loc$ts_since_set <- ifelse(loc$ts > loc$sunset, difftime(loc$ts, loc$sunset, units = units),
                             difftime(loc$ts, maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)), (loc$ts - 86400), POSIXct.out=T, direction='sunset')$time, units = units))
  loc$ts_to_rise <- ifelse(loc$ts < loc$sunrise, difftime(loc$sunrise, loc$ts, units = units),
                           difftime(maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)), (loc$ts + 86400), POSIXct.out=T, direction='sunrise')$time, loc$ts, units = units))
  loc$ts_since_rise <- ifelse(loc$ts > loc$sunrise, difftime(loc$ts, loc$sunrise, units = units),
                              difftime(loc$ts, maptools::sunriset(as.matrix(dplyr::select(loc,lon,lat)), (loc$ts - 86400), POSIXct.out=T, direction='sunrise')$time, units = units))
  data <- merge(loc, loc_na, all = TRUE)
  return(data)
}
