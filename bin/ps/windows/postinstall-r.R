# IASI R baseline adapter. Run with Rscript --vanilla.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) stop('Usage: postinstall-r.R bootstrap|restore lockfile repository [packages...]')
mode <- args[[1L]]
lockfile <- normalizePath(args[[2L]], winslash = '/', mustWork = FALSE)
repo <- args[[3L]]
packages <- if (length(args) > 3L) args[-(1:3)] else character()
if (!identical(repo, 'https://cloud.r-project.org')) stop('Unapproved R repository')
options(repos = c(CRAN = repo))
if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv', repos = repo)
if (!requireNamespace('renv', quietly = TRUE)) stop('renv unavailable')
# Work in the catalog directory; do not initialize an arbitrary user project.
project <- dirname(lockfile)
if (!dir.exists(project)) stop('Missing configuration directory: ', project)
if (mode == 'bootstrap') {
  if (file.exists(lockfile)) stop('Baseline already exists; bootstrap refuses to overwrite: ', lockfile)
  # Isolated project library. Explicitly include transitive dependencies in lockfile.
  renv::init(project = project, bare = TRUE, restart = FALSE)
  if (length(packages)) renv::install(packages = packages, project = project, repos = repo, prompt = FALSE)
  renv::snapshot(project = project, lockfile = lockfile, type = 'all', prompt = FALSE)
  if (!file.exists(lockfile)) stop('Snapshot not created')
  cat('IASI R bootstrap PASS. REVIEW AND COMMIT renv.lock; switch mode to restore.\n')
} else if (mode == 'restore') {
  if (!file.exists(lockfile)) stop('Missing committed R baseline: ', lockfile)
  # Verification must be explicit: drift is FAIL.
  renv::restore(project = project, lockfile = lockfile, prompt = FALSE)
  status <- renv::status(project = project, lockfile = lockfile, sources = FALSE)
  if (!isTRUE(status$synchronized)) stop('IASI R baseline mismatch')
  cat('IASI R restore PASS\n')
} else stop('Unknown mode: ', mode)
