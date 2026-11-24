package org.iasi.setupdev;

import org.iasi.setupdev.core.Context;
import org.iasi.setupdev.core.StartupChecks;

/**
 * Exercises the production lock boundary independently of OS/admin prerequisites in an isolated test JVM.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Isolate application lock diagnostics and shutdown cleanup for process tests.
 */
public final class InstanceLockEntryPoint {
    public static void main(String[] args) {
        StartupChecks.acquireInstanceLock("iasi");
        try {
            new App().run(args);
        } finally {
            StartupChecks.releaseInstanceLock("iasi");
        }
        System.exit(Context.getInstance().getRC());
    }
}
