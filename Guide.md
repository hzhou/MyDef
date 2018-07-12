MyDef consists of a set of perl modules and perl scripts. 

Perl Modules:

    * mydef.def       -> MyDef.pm  
        -- Global $def, $page, $var, uses core modules, loads def files

    * parseutil.def -> MyDef/parseutil.pm
        -- def parsing routines

    * compileutil.def -> MyDef/compileutil.pm
        -- compiles, implements preprocessors and macros

    * dumpout.def     -> MyDef/dumpout.pm
        -- commits to output files, implements _STUBs and spells out indentations

    * mydef_utils.def -> MyDef/utils.pm
        -- list parsing, proper splits, expand_macro, uniq_name, symbol_name

Perl Scripts:

    * mydef_page.def -> mydef_page
        -- [.def] -> [.pl]  (or whatever output specified by the module)

    * mydef_make.def -> mydef_make
        -- -> Makefile

    * mydef_run.def -> mydef_run
        -- [.def] -> [.pl] -> {run}  (convenient script for single execution code)

Output Modules:

    * output.def 
        -- frame code that shared by most output modules

    * output_general.def -> MyDef/output_general.pm
        -- plain from output.def, no specials, just the facilities from compileutil.pm

    * output_perl.def   -> MyDef/output_perl.pm
        -- perl. It is needed to self compile, of course

Macro folders:

    * macros_parse/    -- for parseutil.def
    * macros_compile/  -- for compileutil.def
    * macros_make/     -- for mydef_make.def, small
    * macros_util/     -- certain util routines that are shared
    * macros_output/   -- lots of routines that can be shared among output_modules, e.g. scopes, variables, and functions

Bootstrap:

    * bootstrap/   -- a compiled MyDef perl code from one of the previous snapshot that can be used to compile the def base

    * bootstrap.sh -- run it on first installation or when your MyDef installation is messed up.

Others:

    * Misc -- omit first, then simply read the code.
