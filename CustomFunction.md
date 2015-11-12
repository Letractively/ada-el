# Function Mapper #

The function mapper registers functions which can be called within an expression.
The `Default_Function_Mapper` provides a default and simple implementation of
the mapper interface.

```
   Fn  : constant EL.Functions.Function_Mapper_Access
     := new EL.Functions.Default.Default_Function_Mapper;
```

The expression context must then be configured to use the function mapper:

```
   Ctx.Set_Function_Mapper (Fn);
```

# Declare the Function #

The function can have up to 4 parameters of type `EL.Objects.Object`.
The implementation can convert the parameter to the basic types such as strings,
integers and floats.

```
  function Format (Arg : EL.Objects.Object) return EL.Objects.Object;

  function Format (Arg : EL.Objects.Object) return EL.Objects.Object is
      S : constant String := To_String (Arg);
   begin
      return To_Object ("[" & S & "]");
   end Format;
```

# Register the Function #

The function must be registered in the function mapper and for this it is
associated with a name in a namespace.  The namespace is optional.
```
  Fn.Set_Function (Namespace => "",
                   Name      => "format",
                   Func      => Format'Access);
```

# Expression #

When registered, any expression can use the function:

```
   E := Create_Expression ("#{format(user.firstName)}  #{user.lastName}", Ctx);
   ...
   Result := E.Get_Value (Ctx);
```

# Source #

> [evaluate.adb](http://code.google.com/p/ada-el/source/browse/trunk/samples/evaluate.adb)