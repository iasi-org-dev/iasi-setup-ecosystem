package org.iasi.setupdev.orchestrator;

import java.io.IOException;
import java.io.InputStream;
import java.net.JarURLConnection;
import java.net.URI;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Comparator;
import org.iasi.base.RC;
import org.iasi.common.platform.Platform;
import org.iasi.setupdev.core.Context;

/**
 * Extracts and invokes the resources selected for the host platform.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-24 | 0.2.0 | Extract Windows resources and execute an intentionally invalid probe command.
 */
public final class PlatformOrchestrator {
    private static final String RESOURCE_ROOT = "/bin/";
    private static final String TEMP_ROOT = "iasi/setup";

    /**
     * Executes the first platform delegation probe and accumulates its return code.
     *
     * @param context current execution context
     */
    public void execute(Context context) {
        try {
            switch (context.getOS()) {
                case WINDOWS -> executeWindows(context);
                case LINUX -> context.setRC(RC.ERROR);
                case MACOS -> context.setRC(RC.ERROR);
                default -> context.setRC(RC.ERROR);
            }
        } catch (IOException | InterruptedException exception) {
            if (exception instanceof InterruptedException) Thread.currentThread().interrupt();
            context.setRC(RC.ERROR);
        }
    }

    private void executeWindows(Context context) throws IOException, InterruptedException {
        Path setup = extractWindowsResources();
        ProcessBuilder builder = new ProcessBuilder("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", setup.resolve("setup.ps1").toString(), "--invalid-probe")
                .directory(Path.of(".").toAbsolutePath().normalize().toFile())
                .inheritIO();
        Process process = builder.start();
        context.setRC(process.waitFor());
    }

    private Path extractWindowsResources() throws IOException {
        Path destination = Path.of(System.getProperty("java.io.tmpdir"), TEMP_ROOT);
        if (Files.exists(destination)) delete(destination);
        Files.createDirectories(destination);
        URL resource = PlatformOrchestrator.class.getResource(RESOURCE_ROOT + "windows");
        if (resource == null) throw new IOException("Windows resources are missing");
        if (resource.getProtocol().equals("file")) copyDirectory(Path.of(URI.create(resource.toString())), destination);
        else if (resource.getProtocol().equals("jar")) copyJarDirectory(resource, destination);
        else throw new IOException("Unsupported resource protocol: " + resource.getProtocol());
        return destination;
    }

    private void copyDirectory(Path source, Path destination) throws IOException {
        try (var paths = Files.walk(source)) {
            for (Path path : paths.toList()) {
                Path target = destination.resolve(source.relativize(path).toString());
                if (Files.isDirectory(path)) Files.createDirectories(target);
                else Files.copy(path, target, StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }

    private void copyJarDirectory(URL resource, Path destination) throws IOException {
        JarURLConnection connection = (JarURLConnection) resource.openConnection();
        String prefix = connection.getEntryName() + "/";
        try (var jar = connection.getJarFile()) {
            for (var entry : java.util.Collections.list(jar.entries())) {
                if (!entry.getName().startsWith(prefix) || entry.isDirectory()) continue;
                Path target = destination.resolve(entry.getName().substring(prefix.length()));
                Files.createDirectories(target.getParent());
                try (InputStream input = jar.getInputStream(entry)) { Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING); }
            }
        }
    }

    private void delete(Path path) throws IOException {
        try (var paths = Files.walk(path)) { paths.sorted(Comparator.reverseOrder()).forEach(item -> item.toFile().delete()); }
    }
}
