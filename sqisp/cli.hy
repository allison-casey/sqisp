(import
  click
  os
  sys
  time
  logging
  importlib.resources
  [pathlib [Path]]
  [sqisp [compile]]
  [.formatter [format]]
  [.compiler [SQFASTCompiler]]
  [.bootstrap [stdlib]]
  [.utils [mangle_cfgfunc]]
  [watchdog.observers [Observer]]
  [watchdog.events [PatternMatchingEventHandler]])

(defn create-cfg-functions
  [funcs]
  (setv
    file-paths (lfor func-name funcs
                     :setv path (Path (+ func-name ".sqf"))
                     f"class {func-name} {{file = \"stdlib\\{path}\"}}"))
  (.join "\n" ["class sqisp {"
               "\tclass stdlib {"
               #* (map (fn [x] (+ "\t\t" x)) file-paths)
               "\t};"
               "};"]))


(defn compile-stdlib
  [output-dir compiler]
  (setv funcs (dfor path (importlib.resources.contents stdlib)
                    :if (in ".sqp" path)
                    [(mangle-cfgfunc (cut path 0 -4) :qualified False) path]))
  (for [(, fn-name path) (.items funcs)]
    (setv text (compile (importlib.resources.read-text stdlib path)
                        :compiler compiler)
          out-path (Path output-dir "stdlib" (+ fn-name ".sqf")))
    (out-path.parent.mkdir :parents True :exist-ok True)
    (out-path.write-text text))
  (.write-text (Path output-dir "SqispStdlib.hpp")
               (create-cfg-functions funcs)))

(defn compile-file
  [output-path input-path compiler]
  (with [f (open input-path "r")]
    (setv text (compile (f.read) :compiler compiler)))

  (if (!= (str output-path) "-")
      (do (if-not output-path.suffix
                  (setv output-path (Path output-path (+ input-path.stem ".sqf"))))

          (output-path.parent.mkdir :parents True :exist-ok True)
          (with [fout (open output-path "w")]
            (fout.write text)))
      (print text)))

(defn compile-directory
  [output-dir input-dir compiler]
  (if output-dir.suffix
      (raise (ValueError (+ "Input and Output paths must both be directories "
                            "when compiling a directory"))))

  (for [file (.rglob input-dir "*.sqp")]
    (compile-file output-dir file compiler)))


(with-decorator
  (click.command)
  (click.argument "input" :type (click.Path :exists True))
  (click.option "-o" "--output" :type (click.Path) :help "Path to output file.")
  (click.option "-p" "--pretty" :is-flag True :help "Pretty prints the compiled sqf.")
  (click.option "-w" "--watch" :is_flag True :help "Automatically recompile modified files.")
  (click.option "-n" "--no-stdlib" :is-flag True :help "If set, won't compile the stdlib.")
  (defn main
    [input output &optional [pretty False] [watch False] [no-stdlib False]]
    (setv input-path (Path input)
          output-path (Path (or output "."))
          stdlib? (not no-stdlib)
          compiler (SQFASTCompiler :pretty pretty))

    ;; Compile Standard Library
    (if stdlib?
        (compile-stdlib (if (output-path.is-dir)
                            output-path
                            output-path.parent)
                        compiler))

    ;; Compile Directory or File
    (if (.is-dir input-path)
        (compile-directory output-path input-path compiler)
        (compile-file output-path input-path compiler))))

(defmain []
  (sys.exit (main)))
