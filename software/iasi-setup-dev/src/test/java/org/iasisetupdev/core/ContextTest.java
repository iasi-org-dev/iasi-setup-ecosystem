package org.iasisetupdev.core;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.iasi.base.RC;
import org.iasi.base.Verbosity;
import org.junit.jupiter.api.Test;

/**
 * Una sola vida de contexto, sin campos reseteados ni simulación de varias
 * ejecuciones en esta JVM.
 */
class ContextTest {
    /**
     * Comprueba orden de bootstrap, publicación concurrente, identidad,
     * inmutabilidad y acumulación protegida.
     */
    @Test
    void singleLifecycleIsSafelyPublishedAndAccumulatesWithoutChangingFlow() throws Exception {
        assertThrows(IllegalStateException.class, Context::getInstance);
        assertThrows(NullPointerException.class, () -> Context.initialize(null));
        assertThrows(IllegalStateException.class, Context::getInstance);
        ExecutionConfiguration configuration = configuration();
        Context ctx = publishConcurrently(configuration);
        checkIdentityAndConfiguration(ctx, configuration);
        accumulateConcurrently(ctx);
        checkOrAndControlFlow(ctx);
        assertThrows(IllegalStateException.class, () -> Context.initialize(configuration()));
        assertSame(ctx, Context.getInstance());
    }

    /**
     * Ocho inicializadores compiten; cada observador obtiene exactamente la misma
     * instancia completa.
     */
    private Context publishConcurrently(ExecutionConfiguration configuration) throws Exception {
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(8);
        List<Context> observed = Collections.synchronizedList(new ArrayList<>());
        List<Exception> errors = Collections.synchronizedList(new ArrayList<>());
        for (int index = 0; index < 8; index++)
            new Thread(new Initializer(configuration, start, done, observed, errors)).start();
        start.countDown();
        assertTrue(done.await(30, TimeUnit.SECONDS));
        assertTrue(errors.isEmpty(), errors.toString());
        assertEquals(8, observed.size());
        Context ctx = Context.getInstance();
        for (Context value : observed)
            assertSame(ctx, value);
        assertEquals(0, ctx.getRC());
        return ctx;
    }

    /**
     * La configuración es un record inmutable y las referencias de identidad no
     * cambian durante la vida del contexto.
     */
    private void checkIdentityAndConfiguration(Context ctx, ExecutionConfiguration configuration) throws Exception {
        assertSame(configuration, ctx.configuration());
        assertTrue(ExecutionConfiguration.class.isRecord());
        assertNotNull(ctx.executionId());
        assertSame(ctx.executionId(), ctx.executionId());
        assertSame(ctx.startedAt(), ctx.startedAt());
        Path original = ctx.configuration().logs();
        ctx.configuration().logs().resolve("another-location");
        assertEquals(original, ctx.configuration().logs());
        assertEquals(0, Context.class.getConstructors().length);
        assertTrue(java.lang.reflect.Modifier.isSynchronized(Context.class.getMethod("setRC", int.class).getModifiers()));
        assertTrue(java.lang.reflect.Modifier.isSynchronized(Context.class.getMethod("getRC").getModifiers()));
    }

    /**
     * La concurrencia solo se introduce en QA para demostrar ausencia de pérdida de
     * actualizaciones.
     */
    private void accumulateConcurrently(Context ctx) throws Exception {
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(2);
        new Thread(new RcWriter(ctx, RC.INFO, start, done)).start();
        new Thread(new RcWriter(ctx, RC.WARNING, start, done)).start();
        start.countDown();
        assertTrue(done.await(30, TimeUnit.SECONDS));
        assertEquals(0x06, ctx.getRC());
    }

    /**
     * OK y repeticiones no borran bits; Fatal no lanza ni evita ejecutar las
     * instrucciones siguientes.
     */
    private void checkOrAndControlFlow(Context ctx) {
        ctx.setRC(RC.OK);
        ctx.setRC(RC.WARNING);
        assertEquals(6, ctx.getRC());
        ctx.setRC(RC.FATAL);
        int continued = 1;
        ctx.setRC(RC.ERROR);
        assertEquals(1, continued);
        assertEquals(0x56, ctx.getRC());
    }

    /**
     * Construye valores completos sin crear directorios, servicios o entidades de
     * dominio.
     */
    private ExecutionConfiguration configuration() {
        Path cwd = Path.of(".").toAbsolutePath().normalize();
        return new ExecutionConfiguration(cwd, cwd.resolve("definitions"), cwd.resolve("machines"), cwd.resolve("logs"), Verbosity.NORMAL, false);
    }

    private record Initializer(ExecutionConfiguration configuration, CountDownLatch start, CountDownLatch done, List<Context> observed,
            List<Exception> errors) implements Runnable {
        /**
         * La publicación repetida se rechaza; los consumidores posteriores solo ven el
         * objeto terminado.
         */
        @Override
        public void run() {
            try {
                start.await();
                initializeOnce();
                Context ctx = Context.getInstance();
                boolean complete = ctx.configuration() == configuration && ctx.executionId() != null && ctx.startedAt() != null;
                if (!complete) throw new IllegalStateException("Partial context publication");
                observed.add(ctx);
            } catch (Exception exception) {
                errors.add(exception);
            } finally {
                done.countDown();
            }
        }

        /**
         * Solo un contendiente publica; los restantes conservan la misma instancia y
         * configuración.
         */
        private void initializeOnce() {
            try {
                Context.initialize(configuration);
            } catch (IllegalStateException expectedDuplicate) {
                // El contrato rechaza sustituir el Singleton después de su primera publicación.
            }
        }
    }

    private record RcWriter(Context ctx, int bit, CountDownLatch start, CountDownLatch done) implements Runnable {
        /**
         * Repite escrituras válidas en dos hilos sin introducir atomics ni workers en
         * el producto.
         */
        @Override
        public void run() {
            try {
                start.await();
                for (int index = 0; index < 10000; index++)
                    ctx.setRC(bit);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
            } finally {
                done.countDown();
            }
        }
    }
}
