package org.iasi.setupdev.targets;

import org.iasi.setupdev.args.validation.ArgumentException;
import java.nio.file.Path;
import java.util.List;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

/**
 * Matches original regular expressions against discovered target names without modifying the original patterns.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class TargetValidator {

    public Selection validateTargets(List<Path> availableTargets, List<String> targets) {
        List<Pattern> patterns = compilePatterns(targets);
        return selectTargets(targets, patterns, availableTargets);
    }

    private List<Pattern> compilePatterns(List<String> targets) {
        try {
            return targets.stream().map(Pattern::compile).toList();
        } catch (PatternSyntaxException exception) {
            throw new ArgumentException("invalidTargetPattern");
        }
    }

    private Selection selectTargets(List<String> targets, List<Pattern> patterns, List<Path> candidates) {
        if (patterns.isEmpty()) return new Selection(candidates, List.of());
        var selected = new LinkedHashSet<Path>();
        List<String> missing = new ArrayList<>();
        for (int index = 0; index < patterns.size(); index++) {
            List<Path> matches = findMatches(patterns.get(index), candidates);
            if (matches.isEmpty()) missing.add(targets.get(index));
            selected.addAll(matches);
        }
        return new Selection(List.copyOf(selected), missing);
    }

    private List<Path> findMatches(Pattern pattern, List<Path> candidates) {
        return candidates.stream().filter(path -> pattern.matcher(path.getFileName().toString()).matches()).toList();
    }

    /**
     * Separates immutable selected paths from original patterns that matched no target.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
     */
    public record Selection(List<Path> selected, List<String> missing) {

        public Selection {
            selected = List.copyOf(selected);
            missing = List.copyOf(missing);
        }
    }
}
