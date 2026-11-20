package org.iasi.common.logging;

import java.io.IOException;

/**
 * Accepts sanitized events through a backend-neutral output contract.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public interface LogSink extends AutoCloseable {

    /**
     * Consumes an already sanitized event without changing its identity, timestamp or severity.
     */
    void write(LogEvent event) throws IOException;

    /**
     * Releases only resources owned by this sink; borrowed process streams must remain open.
     */
    @Override
    void close() throws IOException;
}
