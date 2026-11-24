package org.iasi.setupdev.core;

import java.io.IOException;
import org.iasi.common.platform.AdministratorPrivileges;
import org.iasi.common.platform.Platform;
import org.iasi.common.process.SingleInstanceLock;
import org.iasi.setupdev.messages.InitializationMessages;

/**
 * Applies application diagnostics and termination policy to reusable host and process checks.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-24 | 0.1.0 | Separate startup policy from the application entry point and common mechanisms.
 */
public final class StartupChecks {
    private StartupChecks() {
    }

    public static void identifyOperatingSystem(Context ctx) {
        ctx.setOS(Platform.getOperatingSystem());
        if (ctx.getOS() == Platform.Family.UNKNOWN) InitializationMessages.error("unsupportedOperatingSystem");
    }

    public static void checkAdministrator(Platform.Family os) {
        try {
            if (!AdministratorPrivileges.isAdministrator(os)) InitializationMessages.error("administratorRequired");
        } catch (IOException | SecurityException exception) {
            InitializationMessages.error("administratorCheckFailed");
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            InitializationMessages.error("administratorCheckFailed");
        }
    }

    /**
     * Registers shutdown cleanup only after successful ownership, including initialization exits.
     *
     * @param name shared lock filename without the .lock suffix
     */
    public static void acquireInstanceLock(String name) {
        try {
            if (!SingleInstanceLock.tryAcquire(name)) InitializationMessages.error("singleInstanceBusy");
            Runtime.getRuntime().addShutdownHook(new Thread(() -> releaseInstanceLock(name), "iasi-instance-lock-release"));
        } catch (IOException | SecurityException exception) {
            InitializationMessages.error("singleInstanceUnavailable");
        }
    }

    public static void releaseInstanceLock(String name) {
        try {
            SingleInstanceLock.release(name);
        } catch (IOException | SecurityException exception) {
            InitializationMessages.reportError("singleInstanceReleaseFailed");
        }
    }
}
