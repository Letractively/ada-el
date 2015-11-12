# Introduction #

A method expression represents a method to be executed on an object.
The valid syntax for the method expression is a subset of the EL expression.
Method expressions are used in JSF to bind an action or an event to an object method.

For example:
```
"#{user.print}"
```

defines a method expression that allows to invoke a `print` operation on the
`user` bean.  In JSF pages, the following code will be used used to indicate that
this `print` method must be executed when the user validates some `Print` button.

```
<t:commandButton value="Print"
                 action="#{user.print}"/>
```

To be able to invoke such operation, some preparation is necessary on the bean
(the Java EL implementation can leverage the use of introspection to find the
method and execute it; this is not possible in Ada).

# Bean Declaration #

To be able to invoke a method on a bean, we have to:
  * Implement the `Method_Bean` interface on the bean,
  * Create the binding helper for the method to invoke

The `Method_Bean` interface defines the `Get_Method_Bindings` function
which has to return a list of methods that can be invoked in the bean.
(Again, Java does this through introspection).

```
with Util.Beans.Basic;
with Util.Beans.Methods;
...
type Person is new Util.Beans.Basic.Bean and Util.Beans.Methods.Method_Bean with private;
...
overriding
function Get_Method_Bindings (From : in Person)
                              return Util.Beans.Methods.Method_Binding_Array_Access;
```


# Method Binding #

The method binding is a small static and read-only descriptor that describes
the method that can be invoke on the bean.  The binding defines a method proxy
which performs some necessary conversion to the target bean type.

Let's say the method to invoke on the `Person` bean is the following:
```
function Print (P : in Person; Title : in String) return String;
```

The method binding is created by instantiating the `Func_String` package:
```
with EL.Methods.Func_String;

...
package Print_Binding is
  new Func_String.Bind (Bean   => Person,
                        Method => Print,
                        Name   => "print");
```

The package will implement a small proxy function and will provide the method
binding descriptor (`Print_Binding.Proxy`.

# Implementing the `Method_Bean` interface #

The `Get_Method_Bindings` function must be implemented.  Basically it must
return a read-only access to an array of method bindings.  The array can be
declared as follows:

```
Binding_Array : aliased constant Util.Beans.Methods.Method_Binding_Array
     := (Print_Binding.Proxy'Access);
```

Then, give access to the method binding array as follows:
```
function Get_Method_Bindings (From : in Person)
           return Util.Beans.Methods.Method_Binding_Array_Access is
begin
   return Binding_Array'Access;
end Get_Method_Bindings;
```

When a new method is added, the new method binding access must be added
to the array.

# Create the Method Expression #

The method expression is created by the `Create_Expression` function
which parses the string and returns the `Method_Expression` object.
This object can be shared by several tasks.

```
with EL.Expressions;
...
Ctx    : EL.Contexts.Context'Class := ...;
Method : EL.Expressions.Method_Expression
   := EL.Expressions.Create_Expression ("#{user.print}", Ctx);
```

To invoke the method, we have to use the `Execute` function
provided by the `Func_String` package.

```
S : String := Func_String.Execute (Method, "Title", Ctx);
```

The `Execute` function will evaluate the method expression to find
the object and the method.  If the object does not implement
the `print` method, or, if that method does not match our signature,
an `Invalid_Method` exception will be raised.  Otherwise, the
method will be executed with the bean as parameter and the string
as argument.


## Source ##

http://code.google.com/p/ada-el/source/browse/trunk/samples/method.adb

http://code.google.com/p/ada-el/source/browse/trunk/samples/bean.ads

http://code.google.com/p/ada-el/source/browse/trunk/samples/bean.adb