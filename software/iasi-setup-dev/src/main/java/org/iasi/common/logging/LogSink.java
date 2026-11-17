package org.iasi.common.logging;

import java.io.IOException;

/**
 * Puerto de salida implementable por consola, archivo o un futuro adaptador
 * Log4j.
 */
public interface LogSink extends AutoCloseable {
    /**
     * Consume el evento sin alterar su código, instante, severidad ni texto
     * saneado.
     */
    void write(LogEvent event) throws IOException;

    /**
     * Libera únicamente los recursos que posee el destino; propaga fallos de
     * cierre.
     */
    @Override
    void close() throws IOException;
}
