package org.iasi.common.platform;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * Checks effective process elevation on Windows or effective root identity on Unix systems.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Add read-only privilege detection without application or console dependencies.
 */
public final class AdministratorPrivileges {
    private AdministratorPrivileges() {
    }

    /**
     * Probes the current execution token without requesting elevation or changing the system.
     *
     * @param family operating-system family already identified by the caller
     * @return whether the current process has administrator or root privileges
     * @throws IOException if the platform or probe result cannot be verified
     * @throws InterruptedException if the waiting thread is interrupted
     */
    public static boolean isAdministrator(Platform.Family family) throws IOException, InterruptedException {
        String answer = execute(command(family));
        return interpret(family, answer);
    }

    private static List<String> command(Platform.Family family) throws IOException {
        return switch (family) {
            case WINDOWS -> windowsCommand();
            case LINUX, MACOS -> List.of("/usr/bin/id", "-u");
            case UNKNOWN -> throw new IOException("Unsupported privilege probe");
        };
    }

    private static List<String> windowsCommand() {
        Path powershell = Path.of(System.getenv().getOrDefault("SystemRoot", "C:\\Windows"),
                "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        String script = "[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())"
                + ".IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)";
        return List.of(powershell.toString(), "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script);
    }

    private static String execute(List<String> command) throws IOException, InterruptedException {
        Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
        try {
            process.getOutputStream().close();
            if (!process.waitFor(10, TimeUnit.SECONDS)) throw new IOException("Privilege probe timed out");
            if (process.exitValue() != 0) throw new IOException("Privilege probe failed");
            try (var output = process.getInputStream()) {
                return new String(output.readAllBytes(), StandardCharsets.UTF_8).strip();
            }
        } finally {
            process.destroyForcibly();
        }
    }

    static boolean interpret(Platform.Family family, String answer) throws IOException {
        String value = answer.strip();
        return switch (family) {
            case WINDOWS -> windowsAnswer(value);
            case LINUX, MACOS -> unixAnswer(value);
            case UNKNOWN -> throw new IOException("Unsupported privilege probe");
        };
    }

    private static boolean windowsAnswer(String answer) throws IOException {
        if (answer.equalsIgnoreCase("true")) return true;
        if (answer.equalsIgnoreCase("false")) return false;
        throw new IOException("Unrecognized Windows privilege result");
    }

    private static boolean unixAnswer(String answer) throws IOException {
        if (!answer.matches("\\d+")) throw new IOException("Unrecognized effective user identity");
        return answer.equals("0");
    }
}
