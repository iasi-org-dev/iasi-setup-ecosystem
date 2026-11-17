package org.iasi.setupdev;

import java.nio.file.Path;
import org.iasi.common.logging.Verbosity;

record Settings(Path cwd, Path definitions, Path machines, Path logs, Verbosity verbosity, boolean force) {
}
