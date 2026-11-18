package org.iasi.setupdev.args;

import java.nio.file.Path;
import java.util.List;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

/**
 * Selección de targets disponibles mediante las expresiones originales del CLI.
 */
public final class TargetValidator {
    /**
     * Compila los patrones y selecciona los targets disponibles sin modificar los
     * patrones originales ni consultar el directorio de definiciones.
     */
    public Selection validateTargets(List<Path> availableTargets, List<String> targets) {
        List<Pattern> patterns = compilePatterns(targets);
        return selectTargets(targets, patterns, availableTargets);
    }

    /**
     * Comprueba la sintaxis de todas las expresiones antes de buscar coincidencias.
     */
    private List<Pattern> compilePatterns(List<String> targets) {
        try {
            return targets.stream().map(Pattern::compile).toList();
        } catch (PatternSyntaxException exception) {
            throw new ArgumentException("invalidTargetPattern");
        }
    }

    /**
     * Selecciona nombres completos, evita duplicados y registra cada patrón sin
     * coincidencias. Sin patrones selecciona todos los candidatos.
     */
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

    /**
     * Evalúa una expresión regular sobre el nombre completo de cada candidato.
     */
    private List<Path> findMatches(Pattern pattern, List<Path> candidates) {
        return candidates.stream().filter(path -> pattern.matcher(path.getFileName().toString()).matches()).toList();
    }

    /**
     * Resultado separado de los patrones originales conservados en el contexto.
     */
    public record Selection(List<Path> selected, List<String> missing) {
        /**
         * Conserva copias inmutables de coincidencias y patrones sin coincidencias.
         */
        public Selection {
            selected = List.copyOf(selected);
            missing = List.copyOf(missing);
        }
    }
}
