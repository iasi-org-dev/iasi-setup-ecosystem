package org.iasi.setupdev.core;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.iasi.base.RC;
import org.junit.jupiter.api.Test;

class ContextTest {
    @Test
    void singleThreadedContextPreservesOriginalTargetsAndAccumulatesRc() {
        Context ctx = Context.getInstance();
        assertSame(ctx, Context.getInstance());
        assertEquals(Path.of("."), ctx.getDefinitions());
        assertEquals(Path.of("."), ctx.getMachines());
        assertEquals(Path.of("."), ctx.getLogs());
        assertEquals(1, ctx.getVerbose());
        assertFalse(ctx.isForce());
        assertFalse(ctx.isAutostart());
        assertEquals(RC.OK, ctx.getRC());
        assertNotNull(ctx.out());
        assertNotNull(ctx.err());

        var originals = new ArrayList<>(List.of("iasi-dev-.*"));
        ctx.initializeTargets(originals);
        originals.clear();
        ctx.setResolvedTargets(List.of(Path.of("iasi-dev-api")));
        assertEquals(List.of("iasi-dev-.*"), ctx.getTargets());
        assertThrows(UnsupportedOperationException.class, () -> ctx.getTargets().clear());
        assertThrows(IllegalStateException.class, () -> ctx.initializeTargets(List.of("other")));

        ctx.setRC(RC.WARNING);
        ctx.setRC(RC.ERROR);
        assertEquals(RC.WARNING | RC.ERROR, ctx.getRC());
    }
}
