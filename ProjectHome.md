Ada EL is a library that implements an expression language
similar to JSP and JSF Unified Expression Languages (EL).

The syntax is defined by JSR 245 (http://jcp.org/en/jsr/summary?id=245).

The library abstractions are close to the `javax.el` classes.

## This project was moved to `GitHub`. ##

The new location is: https://github.com/stcarrez/ada-el/wiki

The Git repository is: https://github.com/stcarrez/ada-el.git

## NEWS ##


### Version 1.5.1   - Jul 2014 ###
  * The release is available at http://download.vacs.fr/ada-el/ada-el-1.5.1.tar.gz
  * Fix minor configuration issue with GNAT 2014

### Version 1.5     - Feb 2014 ###
  * The release is available at http://download.vacs.fr/ada-el/ada-el-1.5.0.tar.gz
  * EL parser optimization (20% to 30% speed up)
  * Support for the creation of Debian packages

### Version 1.4.2   - Feb 2013 ###
  * Fix compilation to use -gnatn instead of -gnatN
  * Fix compilation with gcc 4.7

### Version 1.4     - May 2012 ###
  * New Eval function which accepts an Object as value
  * Support for shared or static build configuration

### Version 1.3     - Fev 2012 ###
  * New helpers to evaluate the EL expressions of a list of properties

### Version 1.2     - Sep 2011 ###
  * Add support for Method expression

### Version 1.1     - May 2011 ###
  * Move the Ada EL beans framework in Ada Util

### Version 1.0     - Apr 2010 ###
  * Implement JSR 245
