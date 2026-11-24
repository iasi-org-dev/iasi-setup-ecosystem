package org.iasi.common.platform;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import org.junit.jupiter.api.Test;

/**
 * Checks privilege-probe interpretation independently of the account running the test suite.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Cover elevated, non-elevated and unverifiable probe results.
 */
class AdministratorPrivilegesTest {
    @Test
    void distinguishesWindowsElevationFromAStandardToken() throws IOException {
        assertTrue(AdministratorPrivileges.interpret(Platform.Family.WINDOWS, "True\r\n"));
        assertFalse(AdministratorPrivileges.interpret(Platform.Family.WINDOWS, "False"));
    }

    @Test
    void requiresEffectiveRootIdentityOnUnix() throws IOException {
        for (Platform.Family family : new Platform.Family[]{Platform.Family.LINUX, Platform.Family.MACOS}) {
            assertTrue(AdministratorPrivileges.interpret(family, "0\n"));
            assertFalse(AdministratorPrivileges.interpret(family, "1000"));
        }
    }

    @Test
    void rejectsUnrecognizedAnswersAndUnsupportedPlatforms() {
        assertThrows(IOException.class, () -> AdministratorPrivileges.interpret(Platform.Family.WINDOWS, ""));
        assertThrows(IOException.class, () -> AdministratorPrivileges.interpret(Platform.Family.WINDOWS, "access denied"));
        assertThrows(IOException.class, () -> AdministratorPrivileges.interpret(Platform.Family.LINUX, "-1"));
        assertThrows(IOException.class, () -> AdministratorPrivileges.interpret(Platform.Family.UNKNOWN, "true"));
    }
}
