# TASK-00.01.07 validation

- Reusable API: org.iasi.common.process.SingleInstanceLock.acquire("iasi"). The name excludes the .lock suffix. An overload accepts a shared temporary directory for isolated callers/tests.
- Production lock: ${java.io.tmpdir}/iasi.lock, acquired after OS/admin checks and before initialization. FileChannel CREATE/WRITE plus exclusive tryLock; contention and I/O failures have distinct messages and RC.ERROR.
- Lock and channel remain owned until controlled cleanup or the JVM shutdown hook. Closing is idempotent. The persistent file is never truncated, deleted or renamed; its existence alone does not imply an active owner.
- Maven package: passed; 105 tests, zero failures/errors. Includes application-boundary rejection before configuration/work, and shutdown-hook release after initialization exits.
- Process/JAR checks on Windows: 5/5 passed. Concurrent same JAR and renamed JAR rejected; persistent file/content preserved; controlled release and forced owner termination allow immediate reacquisition; unusable lock path rejected without work. Existing temporary work sentinel preserved.
- JAR harness uses an alternate test-only holding entry point with unchanged production lock bytecode. Production entry point retains administrator enforcement; no bypass is shipped.
- Privilege regression: 6/6 passed. This session is not elevated, so a successful full production main execution under administrator privileges was not tested.
- Javadoc gate: passed, 14 packages and 83 named types. git diff --check for src and pom.xml: passed.
- Linux execution remains untested: installed WSL distribution javier has no Java executable available. No runtime was installed or host privileges changed.
- Existing repository-wide formatter discrepancies are outside this change; no global reformat was applied.
- Deliverable: outputs/iasi-setup-dev.jar (no version suffix).

Follow-up: Platform.getOperatingSystem() owns OS detection in common. AdministratorPrivileges.isAdministrator(os) remains the common boolean privilege probe. App consumes SingleInstanceLock.tryAcquire("iasi") as a boolean (false for contention); I/O failures remain distinct exceptions. Ownership is retained in common and released with release("iasi"). Maven package and 5/5 JAR process checks passed after refactoring.
