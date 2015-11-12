# Introduction #

The JSP and [JSF](http://en.wikipedia.org/wiki/JavaServer_Faces) Unified Expression Language is used to give access
to Java bean components within a presentation page (JSP, XHTML).
For JSF the expression language creates a bi-directional binding where
the value can be obtained when displaying a page but also modified (after a POST).
The unified expression language is described in [JSR-245](http://www.jcp.org/en/jsr/detail?id=245) (See also
[Unified EL](http://java.sun.com/products/jsp/reference/techart/unifiedEL.html)).

Example of presentation page:
```
  <b>${user.firstName}</b>
```

The Ada EL is a library that implements the expression language and provides
an Ada binding to use it.  The example below shows a code extract to
bind an Ada record `Joe` to the name `user` and evaluate the above expression.

```
   Ctx    : EL.Contexts.Default.Default_Context;
   E      : EL.Expressions.Expression;
   Result : EL.Objects.Object;
...
   E := EL.Expressions.Create_Expression ("${user.firstName}", Ctx);
...
   --  Bind the context to 'Joe' and evaluate
   Ctx.Set_Variable ("user", Joe);
   Result := E.Get_Value (Ctx);
```


# EL.Objects.Object #

Unlike Java, Ada does not provide a root data type to represent other types (the `java.lang.Object`).  This makes the adaptation of Ada EL more difficult because
the expression language heavily relies on Java mechanisms (`Object` type and introspection).

The `EL.Objects` package provides the data type `Object` that allows to manage
entities of different types.  When an expression is evaluated, the result is
returned in an `Object`.  The record holds the value itself as well as a basic
type indicator (boolean, integer, float, string, wide wide string, ...).

The `Object` is also used to provide variable values to the expression evaluator.

To create an `Object` from a basic type, several `To_Object` functions are provided.

```
   Val : EL.Objects.Object := EL.Objects.Object.To_Object ("A string");
```

To get access to the value held by `Object`, several `To_`_type_ functions are
provided:

```
  S : constant String := EL.Objects.Object.To_String (Val);
```

The `To_`_type_ function will try to convert the value to the target type.

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-objects.ads)

# EL.Beans #

The `EL.Beans` package defines two interfaces that allow to plug an Ada tagged
record to the expression evaluator. The `Readonly_Bean` interface defines a unique
`Get_Value` function that must be implemented.  This function is called by
the expression context resolver to find the value associated with a property.
Basically, the Ada object will be defined as a variable and associated with
a name (for example `user`).  The `Get_Value` function will be called with
the property name and the value must be returned as an `Object` (for example `firstName`).

For example:
```
   type Person is new EL.Beans.Readonly_Bean with private;

   --  Get the value identified by the name.
   function Get_Value (From : Person; Name : String) return EL.Objects.Object;
```

The `Bean` interface redefines the `Readonly_Bean` to define the `Set_Value` procedure.
This interface should be implemented when the expression evaluator has to modify
a value.

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-beans.ads)

# EL.Contexts #

The expression language uses a context to give access to functions, variables
and resolve access to values.  The `ELContext` interface represent such context
and it gives access to:

  * A function mapper that resolves function that the evaluator can invoke.
  * A variable mapper that find the object associated with a name.
  * A resolver that will resolve properties on objects.

The function mapper is used only when parsing an expression.

The variable mapper is used to find the variable object knowing its name.
For example it will resolve the name `user` and return an instance of the
`Readonly_Bean` interface (a `Person`).

The resolver will resolve the variable to obtain the value from the property name.

The `EL.Contexts` package defines the `ELResolver` and `ELContext` interfaces.
The `EL.Contexts.Default` package provides default implementation of these interfaces.

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-contexts.ads)

# EL.Functions #

The `EL.Functions` package defines the `Function_Mapper` interface that allows to
register functions for the expression parser.  The evaluator will invoke the
functions directly (without the need of the `Function_Mapper`).

A function can get from one to four arguments (this is pre-defined because Ada does
not support variable argument lists easily).  Each argument is recieved as
an `Object`.  The function must returns an `Object` value.

The function below returns the year part of a date.  The date is retrieved as
an `Ada.Calendar.Time` and the result will be returned as an integer.
```
function Year (Val : EL.Objects.Object) return EL.Objects.Object is
   Date : constant Ada.Calendar.Time := To_Time (Val);
begin
   return To_Object (Ada.Calendar.Formatting.Year (Date));
end Format;
```

The function will be registered as follows:

```
   Fm  : constant EL.Functions.Function_Mapper_Access
     := new EL.Functions.Default.Default_Function_Mapper;
...
   Fm.Set_Function ("year", Year'Access);
```

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-functions.ads)

## EL.Variables ##

The `EL.Variables` package defines the `VariableMapper` interface and
the `EL.Variables.Default` package provides a default implementation.
The `VariableMapper` allows to bind a name to an Ada object that implements
the `EL.Beans.Readonly_Bean` or `EL.Beans.Bean` interfaces (in Java, one would
be able to use any Java object).

```
   Joe  : constant Person_Access := Create_Person ("Joe", "Smith", 12);

   Ctx.Set_Variable ("user", Joe);
```

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-variables.ads)

## EL.Expressions ##

The `EL.Expressions` package is the main package to parse and evaluate expressions.
An expression string is parsed using the `Create_Expression` function which
returns an `Expression` record.  The expression is parsed only once and it
can be evaluated several times.  The expression context is used only to get
access to the function mapper.

```
   E : EL.Expressions.Expression := Create_Expression ("${user.firstName}", Ctx);
```

The expression is evaluated using the `Get_Value` function.  The evaluation is made
on the expression context which gives access to the variables and the resolver.
The expression context should be a per-thread object.  The expression can be
shared by several threads and evaluated at the same time.

```
  Val : EL.Objects.Object := E.Get_Value (Ctx);
```

(See http://code.google.com/p/ada-el/source/browse/trunk/src/el-expressions.ads)

# Class Diagram #

![http://ada-el.googlecode.com/svn/trunk/uml/Expression.png](http://ada-el.googlecode.com/svn/trunk/uml/Expression.png)