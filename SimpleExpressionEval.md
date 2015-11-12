## Expression Context ##

The expression context defines the context for parsing and evaluating the expression.
In short the expression context provides:
  * the definitions and access to functions,
  * the access to variables

The expression context is represented by the `EL.Contexts.Context` interface.

A default context implementation is provided and can be used as follows:


```
with EL.Contexts.Default;
   ...
   Ctx : EL.Contexts.Default.Default_Context;
```

## Creating an expression ##

The expression must be parsed using `EL.Expressions.Create_Expression` and it
is represented by an `EL.Expressions.Expression` object.

```
with EL.Expressions;
   ...

   E : EL.Expressions.Expression := EL.Expressions.Create_Expression ("#{1 + (2 - 3) * 4}", Ctx);
```

When parsing an expression, the context is used to resolve the functions
used by the expression.

## Evaluating an expression ##

Once parsed, the expression can be evaluated several times and on different
expression contexts.  The evaluation is done by invoking the `Get_Value`
method which returns an `EL.Objects.Object` object.  The `Object` record
will contain the result either as a boolean, an integer, a floating point number,
a string or something else.

```
with EL.Objects;

   ...
   Result : EL.Objects.Object := E.Get_Value (Ctx);
```

To access the value, several `To_type` functions are provided.

```
   Ada.Text_IO.Put_Line ("Result: " & EL.Objects.To_String (Result));
```

## Source ##

http://code.google.com/p/ada-el/source/browse/trunk/samples/evaluate.adb

[Ada EL The JSR 245 Unified Expression Language for Ada](http://blog.vacs.fr/index.php?post/2010/04/28/Ada-EL-The-JSR-245-Unified-Expression-Language-for-Ada)