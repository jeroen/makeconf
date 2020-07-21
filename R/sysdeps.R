#' Find System Dependencies
#'
#' Check which external libraries that an installed package links to.
#' Currently only works on debian/ubuntu.
#'
#' @export
#' @rdname sysdeps
#' @name sysdeps
#' @param pkg name of an installed packages
#' @param lib.loc path to the library of the package
dpkg_sysdeps <- function(pkg, lib.loc = NULL){
  pkgpath <- system.file(package = pkg, lib.loc = lib.loc)
  if(!nchar(pkgpath))
    stop("Package not found")
  dll <- file.path(pkgpath, sprintf('libs/%s.so', pkg))
  if(!file.exists(dll)) # No compiled code
    return(NULL)
  lddinfo <- sys::as_text(sys::exec_internal('ldd', dll)$stdout)
  text <- sys::as_text(sys::exec_internal('readelf', c('-d', dll))$stdout)
  text <- grep('^.*NEEDED.*\\[(.*)\\]$', text, value = TRUE)
  shlibs <- sub('^.*NEEDED.*\\[(.*)\\]$', '\\1', text)
  paths <- lapply(shlibs, function(x){
    name <- strsplit(x, '.', fixed = TRUE)[[1]][1]
    if(isTRUE(name %in% c("libR", "libm", "libgcc_s", "libc")))
      return(NULL) # R itself already depends on these
    line <- grep(x, lddinfo, fixed = TRUE, value = TRUE)
    strsplit(line, ' ', fixed = TRUE)[[1]][3]
  })
  out <- vapply(unlist(paths), function(path){
    info <- sys_with_stderr('dpkg', c('-S', path))
    fullpkg <- strsplit(info, ":? ")[[1]][1]
    sys_with_stderr('dpkg-query', c("--show", fullpkg))
  }, character(1), USE.NAMES = FALSE)
  vapply(unique(out), function(str){
    name <- head(strsplit(str, "[\t:]")[[1]], 1)
    version <- tail(strsplit(str, "\t", fixed = TRUE)[[1]], 1)
    sprintf("%s (%s)", name, version)
  }, character(1), USE.NAMES = FALSE)
}

sys_with_stderr <- function(cmd, args = NULL){
  out <- sys::exec_internal(cmd = cmd, args = args, error = FALSE)
  if(!identical(out$status, 0L)){
    stop(out$stderr)
  } else {
    sys::as_text(out$stdout)
  }
}